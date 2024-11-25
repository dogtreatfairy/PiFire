# Many thanks to the PiVPN project (pivpn.io) for much of the inspiration for this script
# Run from https://raw.githubusercontent.com/dogtreatfairy/pifire/master/auto-install/install.sh
#
# Install with this command (from your Pi):
#
# curl https://raw.githubusercontent.com/dogtreatfairy/pifire/master/auto-install/install.sh | bash
#
# NOTE: Pre-Requisites to run Raspi-Config first.  See README.md.

# Must be root to install
if [[ $EUID -eq 0 ]]; then
    echo "You are root."
else
    echo "SUDO will be used for the install."
    # Check if it is actually installed
    # If it isn't, exit because the install cannot complete
    if [[ $(dpkg-query -s sudo) ]]; then
        export SUDO="sudo"
        export SUDOE="sudo -E"
    else
        echo "Please install sudo."
        exit 1
    fi
fi

# Check if running in WSL
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    echo "Running in WSL"
    IS_WSL=true
else
    IS_WSL=false
fi

# Check if dialog is installed, if not, install it
if ! command -v dialog &> /dev/null; then
    echo "Dialog is not installed. Installing dialog..."
    $SUDO apt-get update
    $SUDO apt-get install -y dialog
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
dialog --msgbox --backtitle "Welcome" --title "PiFire Automated Installer" "This installer will transform your Single Board Computer into a connected Smoker Controller. NOTE: This installer is intended to be run on a fresh install of Raspberry Pi OS Lite 32-Bit Bullseye or later." ${r} ${c}
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
echo "*************************************************************************"
$SUDO apt-get update

# Install APT dependencies
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Installing Dependencies... (This could take several minutes)   **"
echo "**                                                                     **"
echo "*************************************************************************"
$SUDO apt install python3-dev python3-pip python3-venv python3-rpi.gpio python3-scipy nginx git supervisor ttf-mscorefonts-installer redis-server gfortran libatlas-base-dev libopenblas-dev liblapack-dev libopenjp2-7 -y

# Grab project files
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Cloning PiFire from GitHub...                                  **"
echo "**                                                                     **"
echo "*************************************************************************"
cd /usr/local/bin

echo "Cloning development branch..."
# Replace the below command to fetch stable-dev-new-interface branch
$SUDO git clone --depth 1 --branch stable-dev-new-interface https://github.com/dogtreatfairy/pifire

# Setup Python VENV & Install Python dependencies
clear
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
$SUDO chmod -R 775 pifire/

echo " - Setting up VENV"
# Setup VENV
python -m venv --system-site-packages pifire
cd /usr/local/bin/pifire
source bin/activate 

echo " - Installing module dependencies... "
# Install module dependencies
python -m pip install -r requirements.txt

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

$SUDO cp *.conf /etc/supervisor/conf.d/

dialog --title "Supervisor WebUI Setup" --radiolist "Would you like to enable the supervisor WebUI? This allows you to check the status of the supervised processes via a web browser, and also allows those processes to be restarted directly from this interface. (Recommended)" 20 78 2 1 "Enable the WebUI" on 2 "Disable the WebUI" off 2> /tmp/svisor_choice

SVISOR=$(cat /tmp/svisor_choice)

if [[ $SVISOR = 1 ]]; then
   echo " " | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   echo "[inet_http_server]" | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   echo "port = 9001" | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   dialog --inputbox "Choose a username [default: user]" 8 78 user --title "Choose Username" 2> /tmp/username
   USERNAME=$(cat /tmp/username)
   echo "username = " $USERNAME | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   dialog --passwordbox "Enter your password" 8 78 --title "Choose Password" 2> /tmp/password
   PASSWORD=$(cat /tmp/password)
   echo "password = " $PASSWORD | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null
   dialog --msgbox "You now should be able to access the Supervisor WebUI at http://your.ip.address.here:9001 with the username and password you have chosen." 10 50 --title "Setup Completed"
else
   echo "No WebUI Setup."
fi

# Clean up temporary files
rm -f /tmp/svisor_choice /tmp/username /tmp/password

# If supervisor isn't already running, startup Supervisor
$SUDO service supervisor start

# Additional steps for WSL
if [ "$IS_WSL" = true ]; then
    echo "Running in WSL, skipping service setup."
else
    # Setup and start services
    $SUDO systemctl enable nginx
    $SUDO systemctl start nginx
    $SUDO systemctl enable supervisor
    $SUDO systemctl start supervisor
fi

# Rebooting
dialog --msgbox --backtitle "Install Complete / Reboot Required" --title "Installation Completed - Rebooting" "Congratulations, the installation is complete.  At this time, we will perform a reboot and your application should be ready.  On first boot, the wizard will guide you through the remaining setup steps.  You should be able to access your application by opening a browser on your PC or other device and using the IP address (or http://[hostname].local) for this device.  Enjoy!" ${r} ${c}
clear
$SUDO reboot