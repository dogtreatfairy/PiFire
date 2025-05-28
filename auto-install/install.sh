#!/usr/bin/env bash

# Automatic Installation Script
# Many thanks to the PiVPN project (pivpn.io) for much of the inspiration for this script
# Run from https://raw.githubusercontent.com/dogtreatfairy/pifire/pifire-app/auto-install/install.sh
#
# Install with this command (from your Pi):
#
# curl https://raw.githubusercontent.com/dogtreatfairy/pifire/pifire-app/auto-install/install.sh | bash
#
# NOTE: Pre-Requisites to run Raspi-Config first.  See README.md.

# Must be root to install
if [[ $EUID -eq 0 ]];then
    echo "You are root."
else
    echo "SUDO will be used for the install."
    # Check if it is actually installed
    # If it isn't, exit because the install cannot complete
    if [[ $(dpkg-query -s sudo) ]];then
        export SUDO="sudo"
        export SUDOE="sudo -E"
    else
        echo "Please install sudo."
        exit 1
    fi
fi

# Find the rows and columns. Will default to 80x24 if it can not be detected.
screen_size=$(stty size 2>/dev/null || echo 24 80)
rows=$(echo $screen_size | awk '{print $1}')
columns=$(echo $screen_size | awk '{print $2}')

# Divide by two so the dialogs take up half of the screen.
r=$(( rows / 2 ))
c=$(( columns / 2 ))
# If the screen is small, modify defaults
r=$(( r < 20 ? 20 : r ))
c=$(( c < 70 ? 70 : c ))

# Display the welcome dialog
whiptail --msgbox --backtitle "Welcome" --title "PiFire Automated Installer" "This installer will transform your Single Board Computer into a connected Smoker Controller.  NOTE: This installer is intended to be run on a fresh install of Raspberry Pi OS Lite 32-Bit Bullseye or later." ${r} ${c}

# Ask the user to select a GitHub user
USER_CHOICE=$(whiptail --title "Choose a GitHub User" --menu "Select the GitHub user to clone from:" 20 78 3 \
    "1" "nebhead" \
    "2" "dogtreatfairy" \
    "3" "other" \
    3>&1 1>&2 2>&3)

# Check if the user canceled the selection
if [ $? -ne 0 ]; then
    echo "User selection canceled."
    exit 1
fi

# Determine the GitHub user based on the choice
case "$USER_CHOICE" in
    "1")
        GITHUB_USER="nebhead"
        ;;
    "2")
        GITHUB_USER="dogtreatfairy"
        ;;
    "3")
        GITHUB_USER=$(whiptail --inputbox "Enter the GitHub username to clone from:" 8 78 --title "Custom GitHub User" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ] || [ -z "$GITHUB_USER" ]; then
            echo "No username provided or input canceled."
            exit 1
        fi
        ;;
    *)
        echo "Invalid selection."
        exit 1
        ;;
esac

# Fetch branches from the selected user's PiFire repository
BRANCHES=$(git ls-remote --heads https://github.com/$GITHUB_USER/pifire.git 2>&1)
if echo "$BRANCHES" | grep -q "fatal:"; then
    echo "Error fetching branches: $BRANCHES"
    exit 1
fi
if [ -z "$BRANCHES" ]; then
    echo "No branches found or repository does not exist."
    exit 1
fi

# Extract branch names into an array, ensuring only valid refs/heads/ entries
mapfile -t BRANCH_ARRAY < <(echo "$BRANCHES" | grep "refs/heads/" | awk -F'/' '{print $NF}' | sort -u)

# Check if there are any branches
if [ ${#BRANCH_ARRAY[@]} -eq 0 ]; then
    echo "No branches found in the repository."
    exit 1
fi

# Debugging: Show fetched branches
echo "Fetched branches: ${BRANCH_ARRAY[@]}"

# Construct menu items for whiptail
MENU_ITEMS=()
for i in "${!BRANCH_ARRAY[@]}"; do
    MENU_ITEMS+=("$((i+1))" "${BRANCH_ARRAY[i]}")
done

# Display the menu and capture the user's choice
CHOICE=$(whiptail --title "Choose a Branch" --menu "Select the branch to install:" 20 78 10 "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)

# Check if the user canceled or if whiptail failed
if [ $? -ne 0 ]; then
    echo "Branch selection canceled or failed."
    exit 1
fi

# Validate CHOICE and set the selected branch
if [ -z "$CHOICE" ] || ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#BRANCH_ARRAY[@]} ]; then
    echo "Invalid branch selection: $CHOICE"
    exit 1
fi

SELECTED_BRANCH="${BRANCH_ARRAY[$((CHOICE-1))]}"

# Ensure a branch was selected
if [ -z "$SELECTED_BRANCH" ]; then
    echo "No branch selected."
    exit 1
fi

# Debugging: Confirm selection
echo "Selected branch: $SELECTED_BRANCH"

clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Cloning PiFire from GitHub...                                  **"
echo "**                                                                     **"
echo "*************************************************************************"
cd /usr/local/bin

# Clone the selected branch
echo "Cloning branch: $SELECTED_BRANCH from user: $GITHUB_USER"
$SUDO git clone --depth 1 --branch "$SELECTED_BRANCH" https://github.com/$GITHUB_USER/pifire.git

# Starting actual steps for installation
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Setting /tmp to RAM based storage in /etc/fstab                **"
echo "**                                                                     **"
echo "*************************************************************************"
echo "tmpfs /tmp  tmpfs defaults,noatime 0 0" | sudo tee -a /etc/fstab > /dev/null
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Running Apt Update... (This could take several minutes)        **"
echo "**                                                                     **"
echo "*************************************************************************"
$SUDO apt update
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Running Apt Upgrade... (This could take several minutes)       **"
echo "**                                                                     **"
echo "*************************************************************************"
$SUDO apt upgrade -y

# Install APT dependencies
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Installing Dependencies... (This could take several minutes)   **"
echo "**                                                                     **"
echo "*************************************************************************"
# Read apt packages from package.json and install them
APT_PACKAGES=$(jq -r '.apt[]' /usr/local/bin/pifire/auto-install/package.json)
$SUDO apt install -y $APT_PACKAGES

cd /usr/local/bin/pifire/pifire.app
$SUDO npm install --unsafe-perm

# Read pip packages from package.json and install them
PIP_PACKAGES=$(jq -r '.pip[]' /usr/local/bin/pifire/auto-install/package.json)
uv pip install $PIP_PACKAGES

# Setup Python VENV & Install Python dependencies
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Setting up Python VENV and Installing Modules...               **"
echo "**            (This could take several minutes)                        **"
echo "**                                                                     **"
echo "*************************************************************************"
echo ""
echo " - Setting Up PiFire Group"
cd /usr/local/bin
$SUDO groupadd pifire 
$SUDO usermod -a -G pifire $USER 
$SUDO usermod -a -G pifire root 
# Change ownership to group=pifire for all files/directories in pifire 
$SUDO chown -R $USER:pifire pifire 
# Change ability for pifire group to read/write/execute 
$SUDO chmod -R 777 /usr/local/bin

echo " - Installing UV"
curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh

echo " - Setting up VENV"
# Setup VENV
cd /usr/local/bin/pifire
uv venv --system-site-packages

# Determine the appropriate Python command based on the OS
if [[ $(uname -a) == *"raspberrypi"* ]]; then
    PYTHON_CMD="python"
else
    PYTHON_CMD="python3"
fi

echo " - Installing module dependencies... "
# Install module dependencies 
if ! $PYTHON_CMD -c "import sys; assert sys.version_info[:2] >= (3,11)" > /dev/null; then
    echo "System is running a python version lower than 3.11, installing eventlet==0.30.2";
    uv $PYTHON_CMD -m pip install "eventlet==0.30.2"
else
    echo "System is running a python version 3.11 or greater, installing latest eventlet"
    uv $PYTHON_CMD -m pip install eventlet
fi

# Install pip packages from package.json
PIP_PACKAGES=$(jq -r '.pip[]' /usr/local/bin/pifire/auto-install/package.json)
uv $PYTHON_CMD -m pip install $PIP_PACKAGES

# Install pip packages from requirements.txt
uv $PYTHON_CMD -m pip install -r /usr/local/bin/pifire/auto-install/requirements.txt

# Find all bluepy-helper executables in various possible locations
BLUEPY_HELPERS=$(find /usr/local/bin/pifire/.venv/lib/ -path "*/bluepy/bluepy-helper" 2>/dev/null)

if [ -z "$BLUEPY_HELPERS" ]; then
    echo "No bluepy-helper found in the standard Python library locations"
    exit 1
fi

# Apply capabilities to each found bluepy-helper
for helper in $BLUEPY_HELPERS; do
    echo "Setting capabilities for $helper"
    $SUDO setcap "cap_net_raw,cap_net_admin+eip" "$helper"
    
    # Verify the capabilities were set
    getcap "$helper"
done

echo "All bluepy-helper executables have been configured"

# Get PIP List into JSON file
echo " - Getting PIP List into JSON file"
.venv/bin/python updater.py -p

### Setup nginx to proxy to gunicorn
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Configuring nginx...                                           **"
echo "**                                                                     **"
echo "*************************************************************************"
# Move into install directory
cd /usr/local/bin/pifire/auto-install/nginx

# Delete default configuration
$SUDO rm /etc/nginx/sites-enabled/default

# Copy configuration file to nginx
$SUDO cp pifire.nginx /etc/nginx/sites-available/pifire

# Create link in sites-enabled
$SUDO ln -s /etc/nginx/sites-available/pifire /etc/nginx/sites-enabled

# Copy server_error.html to /usr/share/nginx/html
$SUDO cp server_error.html /usr/share/nginx/html

# Restart nginx
$SUDO service nginx restart

### Setup Supervisor to Start Apps on Boot / Restart on Failures
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Configuring Supervisord...                                     **"
echo "**                                                                     **"
echo "*************************************************************************"

# Copy configuration files (control.conf, webapp.conf) to supervisor config directory
cd /usr/local/bin/pifire/auto-install/supervisor
# Add the current username to the configuration files 
echo "user=" $USER | tee -a control.conf > /dev/null
echo "user=" $USER | tee -a webapp.conf > /dev/null
echo "user=" $USER | tee -a pifireapp.conf > /dev/null

$SUDO cp *.conf /etc/supervisor/conf.d/

SVISOR=$(whiptail --title "Would you like to enable the supervisor WebUI?" --radiolist "This allows you to check the status of the supervised processes via a web browser, and also allows those processes to be restarted directly from this interface. (Recommended)" 20 78 2 "ENABLE_SVISOR" "Enable the WebUI" ON "DISABLE_SVISOR" "Disable the WebUI" OFF 3>&1 1>&2 2>&3)

if [[ $SVISOR = "ENABLE_SVISOR" ]];then
   echo " " | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   echo "[inet_http_server]" | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   echo "port = 9001" | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   USERNAME=$(whiptail --inputbox "Choose a username [default: user]" 8 78 user --title "Choose Username" 3>&1 1>&2 2>&3)
   echo "username = " $USERNAME | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   PASSWORD=$(whiptail --passwordbox "Enter your password" 8 78 --title "Choose Password" 3>&1 1>&2 2>&3)
   echo "password = " $PASSWORD | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   whiptail --msgbox --backtitle "Supervisor WebUI Setup" --title "Setup Completed" "You now should be able to access the Supervisor WebUI at http://your.ip.address.here:9001 with the username and password you have chosen." ${r} ${c}
else
   echo "No WebUI Setup."
fi

# If supervisor isn't already running, startup Supervisor
$SUDO service supervisor start

# Rebooting
whiptail --msgbox --backtitle "Install Complete / Reboot Required" --title "Installation Completed - Rebooting" "Congratulations, the installation is complete.  At this time, we will perform a reboot and your application should be ready.  On first boot, the wizard will guide you through the remaining setup steps.  You should be able to access your application by opening a browser on your PC or other device and using the IP address (or http://[hostname].local) for this device.  Enjoy!" ${r} ${c}
clear
$SUDO reboot
