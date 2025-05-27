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

# Function for graceful exit
exit_with_error() {
    whiptail --title "Error" --msgbox "$1" ${r:-20} ${c:-70}
    exit 1
}

# Must be root to install, or have sudo
if [[ $EUID -eq 0 ]]; then
    echo "You are root."
    SUDO=""
    SUDOE=""
else
    echo "SUDO will be used for the install."
    if ! command -v sudo &> /dev/null; then
        echo "sudo command not found. Please install sudo or run as root."
        exit 1
    fi
    SUDO="sudo"
    SUDOE="sudo -E"
    # Test sudo
    $SUDO -v || exit_with_error "Sudo privileges are required. Please ensure you can run sudo commands."
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

# --- Initial Prerequisite Installation ---
INSTALL_REQUIRED_PACKAGES_APT=()
# newt provides whiptail on Debian-based systems like Raspberry Pi OS
if ! command -v whiptail &> /dev/null; then INSTALL_REQUIRED_PACKAGES_APT+=("newt"); fi
if ! command -v git &> /dev/null; then INSTALL_REQUIRED_PACKAGES_APT+=("git"); fi
if ! command -v jq &> /dev/null; then INSTALL_REQUIRED_PACKAGES_APT+=("jq"); fi
if ! command -v curl &> /dev/null; then INSTALL_REQUIRED_PACKAGES_APT+=("curl"); fi

INSTALL_UV_VIA_CURL=false
if ! command -v uv &> /dev/null; then INSTALL_UV_VIA_CURL=true; fi

if [ ${#INSTALL_REQUIRED_PACKAGES_APT[@]} -gt 0 ] || $INSTALL_UV_VIA_CURL; then
    MSG_PACKAGES_APT_STR=""
    if [ ${#INSTALL_REQUIRED_PACKAGES_APT[@]} -gt 0 ]; then
        MSG_PACKAGES_APT_STR="APT packages: ${INSTALL_REQUIRED_PACKAGES_APT[*]}"
    fi
    MSG_PACKAGES_UV_STR=""
    if $INSTALL_UV_VIA_CURL; then
        MSG_PACKAGES_UV_STR="Python packager 'uv' (via direct download)."
    fi

    whiptail --title "Initial Setup" --msgbox "The following essential tools are missing or will be ensured: $MSG_PACKAGES_APT_STR $MSG_PACKAGES_UV_STR" ${r} ${c}

    # Install APT packages if any
    if [ ${#INSTALL_REQUIRED_PACKAGES_APT[@]} -gt 0 ]; then
        $SUDO apt update || exit_with_error "Failed to apt update. Please check your internet connection and package sources."
        $SUDO apt install -y "${INSTALL_REQUIRED_PACKAGES_APT[@]}" || exit_with_error "Failed to install essential APT packages: ${INSTALL_REQUIRED_PACKAGES_APT[*]}.\nPlease install them manually and re-run the script."
        # Verify installation of APT packages (basic check)
        for pkg_name in "${INSTALL_REQUIRED_PACKAGES_APT[@]}"; do
            # This is a simplistic check; dpkg -s is more reliable if package name is known
            # For commands like whiptail (from newt), git, jq, curl:
            CMD_TO_CHECK="$pkg_name"
            if [ "$pkg_name" = "newt" ]; then CMD_TO_CHECK="whiptail"; fi
            if ! command -v $CMD_TO_CHECK &> /dev/null; then exit_with_error "Failed to install/find $CMD_TO_CHECK after attempting installation. Exiting."; fi
        done
    fi

    # Install UV if needed
    if $INSTALL_UV_VIA_CURL; then
        echo "Installing UV (Python package manager)..."
        if curl -LsSf https://astral.sh/uv/install.sh | $SUDOE env UV_INSTALL_DIR="/usr/local/bin" sh; then
            echo "UV installed successfully."
        else
            exit_with_error "Failed to install UV. Exiting."
        fi
        if ! command -v uv &> /dev/null; then
            exit_with_error "UV installation seemed to succeed, but 'uv' command not found. Check PATH or try sourcing your profile. Exiting."
        fi
    fi
fi
# --- End of Initial Prerequisite Installation ---

# Display the welcome dialog
whiptail --msgbox --backtitle "Welcome" --title "PiFire Automated Installer" "This installer will transform your Single Board Computer into a connected Smoker Controller.  NOTE: This installer is intended to be run on a fresh install of Raspberry Pi OS Lite 32-Bit Bullseye or later." ${r} ${c}

# Ask the user to select a GitHub user
USER_LIST_MENU=()
USER_LIST_MENU+=("1." "nebhead")
USER_LIST_MENU+=("2." "dogtreatfairy")
USER_LIST_MENU+=("3." "Other - Enter username")

USER_CHOICE=$(whiptail --title "Choose a GitHub User" --menu "Select the GitHub user to clone from:" ${r} ${c} $((${#USER_LIST_MENU[@]}/2)) "${USER_LIST_MENU[@]}" --notags 3>&1 1>&2 2>&3)
USER_CHOICE_EXIT_STATUS=$?

if [ $USER_CHOICE_EXIT_STATUS -ne 0 ]; then
    exit_with_error "User selection cancelled. Exiting."
fi

if [ "$USER_CHOICE" = "1." ]; then
    GITHUB_USER="nebhead"
elif [ "$USER_CHOICE" = "2." ]; then
    GITHUB_USER="dogtreatfairy"
elif [ "$USER_CHOICE" = "3." ]; then
    GITHUB_USER=$(whiptail --inputbox "Enter the GitHub username to clone from:" 8 78 --title "Custom GitHub User" 3>&1 1>&2 2>&3)
    GITHUB_USER_EXIT_STATUS=$?
    if [ $GITHUB_USER_EXIT_STATUS -ne 0 ] || [ -z "$GITHUB_USER" ]; then
        exit_with_error "No custom GitHub username entered or selection cancelled. Exiting."
    fi
else
    exit_with_error "Invalid user selection '$USER_CHOICE'. Exiting."
fi

whiptail --infobox "Selected GitHub User: $GITHUB_USER" 8 78

# List all branches on the server
whiptail --infobox "Fetching branches from GitHub for user '$GITHUB_USER'..." 8 78
BRANCHES_OUTPUT=$(git ls-remote --heads "https://github.com/$GITHUB_USER/pifire.git" 2>&1)
GIT_LS_REMOTE_STATUS=$?

if [ $GIT_LS_REMOTE_STATUS -ne 0 ]; then
    exit_with_error "Error fetching branches for user '$GITHUB_USER'.\nRepository: pifire\nDetails:\n$BRANCHES_OUTPUT\n\nPlease check username, repository existence, and internet connection."
fi

BRANCHES=$(echo "$BRANCHES_OUTPUT" | awk -F'/' '{print $NF}' | sort | grep -vE '^\s*$') # Remove empty/whitespace lines

BRANCH_LIST_FOR_MENU=()
# Using an associative array to map menu item tag (like "1.", "2.") to actual branch name
declare -A BRANCH_TAG_TO_NAME_MAP

# Option 1 is main
BRANCH_LIST_FOR_MENU+=("1." "main (nh-dev-id)")
BRANCH_TAG_TO_NAME_MAP["1."]="main"
MENU_ITEM_NUMBER=2 # Next item number

# Add other branches from the remote
if [ -n "$BRANCHES" ]; then
    echo "$BRANCHES" | while IFS= read -r BRANCH; do
        if [ "$BRANCH" != "main" ]; then # Avoid duplicating 'main' if it's listed by ls-remote
            BRANCH_LIST_FOR_MENU+=("$MENU_ITEM_NUMBER." "$BRANCH")
            BRANCH_TAG_TO_NAME_MAP["$MENU_ITEM_NUMBER."]="$BRANCH"
            MENU_ITEM_NUMBER=$((MENU_ITEM_NUMBER + 1))
        fi
    done
else
    whiptail --infobox "No additional branches found for '$GITHUB_USER/pifire' beyond default 'main'." ${r} ${c}
fi

if [ ${#BRANCH_LIST_FOR_MENU[@]} -eq 0 ]; then
    exit_with_error "Error: Could not prepare branch list. 'main' branch option seems missing."
fi

CHOICE_TAG=$(whiptail --title "Choose a Branch" --menu "Select the branch to install:" ${r} ${c} $((${#BRANCH_LIST_FOR_MENU[@]}/2)) "${BRANCH_LIST_FOR_MENU[@]}" --notags 3>&1 1>&2 2>&3)
BRANCH_CHOICE_EXIT_STATUS=$?

if [ $BRANCH_CHOICE_EXIT_STATUS -ne 0 ]; then
    exit_with_error "Branch selection cancelled. Exiting."
fi

SELECTED_BRANCH="${BRANCH_TAG_TO_NAME_MAP[$CHOICE_TAG]}"

if [ -z "$SELECTED_BRANCH" ]; then
    exit_with_error "Could not determine selected branch for choice tag '$CHOICE_TAG'. Exiting."
fi

clear
echo "*************************************************************************"
echo "** **"
echo "** Cloning PiFire from GitHub...                            **"
echo "** **"
echo "*************************************************************************"

PIFIRE_INSTALL_DIR="/usr/local/bin/pifire"

if [ ! -d "/usr/local/bin" ]; then
    $SUDO mkdir -p "/usr/local/bin" || exit_with_error "Failed to create /usr/local/bin directory."
fi
cd "/usr/local/bin" || exit_with_error "Failed to change directory to /usr/local/bin."

if [ -d "$PIFIRE_INSTALL_DIR" ]; then
    if whiptail --yesno "Existing PiFire installation found at $PIFIRE_INSTALL_DIR. Remove and re-clone?" ${r} ${c}; then # Yes
        echo "Removing existing PiFire directory: $PIFIRE_INSTALL_DIR"
        $SUDO rm -rf "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to remove existing PiFire directory."
    else # No
        exit_with_error "Cannot proceed with existing directory. Exiting."
    fi
fi

echo "Cloning branch: '$SELECTED_BRANCH' from user: '$GITHUB_USER' into $PIFIRE_INSTALL_DIR"
if ! $SUDO git clone --depth 1 --branch "$SELECTED_BRANCH" "https://github.com/$GITHUB_USER/pifire.git" "$PIFIRE_INSTALL_DIR"; then
    exit_with_error "ERROR: Failed to clone branch '$SELECTED_BRANCH' from user '$GITHUB_USER'.\nPlease double-check the username, branch name, and repository permissions.\nRepository or branch may not exist.\n\nInstaller will now exit."
fi

# Starting actual steps for installation
cd "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to change directory to $PIFIRE_INSTALL_DIR after clone."
PACKAGE_JSON_PATH="$PIFIRE_INSTALL_DIR/auto-install/package.json" # Define early as it's used multiple times

clear
echo "*************************************************************************"
echo "** **"
echo "** Setting /tmp to RAM based storage in /etc/fstab              **"
echo "** **"
echo "*************************************************************************"
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp  tmpfs defaults,noatime 0 0" | $SUDO tee -a /etc/fstab > /dev/null
    echo "/tmp added to /etc/fstab. A reboot will be required later for this to take full effect (or 'sudo mount -a')."
else
    echo "/tmp already configured in /etc/fstab."
fi

clear
echo "*************************************************************************"
echo "** **"
echo "** Running Apt Update... (This could take several minutes)        **"
echo "** **"
echo "*************************************************************************"
$SUDO apt update || exit_with_error "apt update failed."

clear
echo "*************************************************************************"
echo "** **"
echo "** Running Apt Upgrade... (This could take several minutes)       **"
echo "** **"
echo "*************************************************************************"
$SUDO apt upgrade -y || exit_with_error "apt upgrade failed."

clear
echo "*************************************************************************"
echo "** **"
echo "** Installing Dependencies... (This could take several minutes)       **"
echo "** **"
echo "*************************************************************************"
if [ ! -f "$PACKAGE_JSON_PATH" ]; then
    exit_with_error "package.json not found at $PACKAGE_JSON_PATH."
fi

APT_PACKAGES=$(jq -r '.apt[] | select(type=="string" and length > 0) | @sh' "$PACKAGE_JSON_PATH" | xargs) # Get as shell-escaped words
if [ -n "$APT_PACKAGES" ]; then
    echo "Installing APT packages from package.json: $APT_PACKAGES"
    # shellcheck disable=SC2086
    $SUDO apt install -y $APT_PACKAGES || exit_with_error "Failed to install APT packages from package.json."
else
    echo "No APT packages listed in package.json."
fi

# npm install section
NPM_APP_DIR="$PIFIRE_INSTALL_DIR/pifire.app"
if [ ! -d "$NPM_APP_DIR" ]; then exit_with_error "pifire.app directory not found: $NPM_APP_DIR"; fi
cd "$NPM_APP_DIR" || exit_with_error "Could not cd to $NPM_APP_DIR directory."
echo "Running npm install in $(pwd)..."
$SUDO npm install || exit_with_error "npm install failed."
echo "Running npm run build in $(pwd)..."
$SUDO npm run build || exit_with_error "npm run build failed."


# Setup Python VENV & Install Python dependencies
cd "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to cd to $PIFIRE_INSTALL_DIR for VENV setup."

clear
echo "*************************************************************************"
echo "** **"
echo "** Setting up Python VENV and Installing Modules...               **"
echo "** (This could take several minutes)                   **"
echo "** **"
echo "*************************************************************************"
echo ""
echo " - Setting Up PiFire Group"
EFFECTIVE_USER=${SUDO_USER:-$USER}
if ! getent group pifire > /dev/null; then
    $SUDO groupadd pifire || exit_with_error "Failed to add group 'pifire'."
fi
$SUDO usermod -a -G pifire "$EFFECTIVE_USER" || exit_with_error "Failed to add user $EFFECTIVE_USER to pifire group."
$SUDO usermod -a -G pifire root

echo " - Setting up VENV in $(pwd)"
$SUDO uv venv --system-site-packages .venv
if [ ! -d ".venv" ]; then
    exit_with_error "Failed to create Python virtual environment .venv in $(pwd)."
fi
$SUDO chmod -R a+rX .venv # Ensure readable/executable by subsequent sudo uv commands

# Install pip packages from package.json into the venv
PIP_PACKAGES_FROM_JSON=$(jq -r '.pip[] | select(type=="string" and length > 0) | @sh' "$PACKAGE_JSON_PATH" | xargs)
if [ -n "$PIP_PACKAGES_FROM_JSON" ]; then
    echo " - Installing pip packages from package.json into venv: $PIP_PACKAGES_FROM_JSON"
    # shellcheck disable=SC2086
    if ! $SUDO uv pip install $PIP_PACKAGES_FROM_JSON; then
        exit_with_error "Failed to install pip packages from package.json into venv."
    fi
else
    echo " - No pip packages found in package.json to install in venv."
fi

echo " - Installing specific module dependencies into venv... "
PYTHON_FOR_VERSION_CHECK="python3" # Default to python3
if [[ $(uname -a) == *"raspberrypi"* ]]; then # On Raspberry Pi, 'python' might be older
    if command -v python3 &> /dev/null; then PYTHON_FOR_VERSION_CHECK="python3";
    elif command -v python &> /dev/null; then PYTHON_FOR_VERSION_CHECK="python";
    else exit_with_error "Could not find a Python interpreter (python3 or python) for version check."; fi
else # Other systems, python3 is standard
    if ! command -v python3 &> /dev/null; then exit_with_error "python3 interpreter not found for version check."; fi
fi

if ! $PYTHON_FOR_VERSION_CHECK -c "import sys; assert sys.version_info[:2] >= (3,11)" > /dev/null 2>&1; then
    echo "System python ($PYTHON_FOR_VERSION_CHECK) version is lower than 3.11, installing eventlet==0.30.2 into venv"
    if ! $SUDO uv pip install "eventlet==0.30.2"; then exit_with_error "Failed to install eventlet==0.30.2."; fi
else
    echo "System python ($PYTHON_FOR_VERSION_CHECK) version is 3.11 or greater, installing latest eventlet into venv"
    if ! $SUDO uv pip install eventlet; then exit_with_error "Failed to install eventlet."; fi
fi

REQUIREMENTS_TXT_PATH="$PIFIRE_INSTALL_DIR/auto-install/requirements.txt"
if [ -f "$REQUIREMENTS_TXT_PATH" ]; then
    echo " - Installing pip packages from $REQUIREMENTS_TXT_PATH into venv..."
    if ! $SUDO uv pip install -r "$REQUIREMENTS_TXT_PATH"; then
        exit_with_error "Failed to install packages from requirements.txt."
    fi
else
    echo " - Warning: $REQUIREMENTS_TXT_PATH not found, skipping."
fi

echo " - Setting ownership and permissions for $PIFIRE_INSTALL_DIR"
$SUDO chown -R "$EFFECTIVE_USER:pifire" "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to chown $PIFIRE_INSTALL_DIR."
# u=rwx, g=rwx, o=rx for directories. u=rw, g=rw, o=r for files.
$SUDO find "$PIFIRE_INSTALL_DIR" -type d -exec chmod 775 {} \;
$SUDO find "$PIFIRE_INSTALL_DIR" -type f -exec chmod 664 {} \;
# The original script's chmod -R 777 /usr/local/bin was very problematic.
# This now targets only the $PIFIRE_INSTALL_DIR with more appropriate permissions.

BLUEPY_HELPERS=$($SUDO find "$PIFIRE_INSTALL_DIR/.venv/lib/" -path "*/bluepy/bluepy-helper" 2>/dev/null)
if [ -z "$BLUEPY_HELPERS" ]; then
    echo "Warning: No bluepy-helper found in .venv. Bluetooth functionality might be affected."
else
    for helper in $BLUEPY_HELPERS; do
        echo "Setting capabilities for $helper"
        $SUDO setcap "cap_net_raw,cap_net_admin+eip" "$helper" && getcap "$helper"
    done
    echo "All found bluepy-helper executables have been configured."
fi

echo " - Getting PIP List into JSON file using venv python"
VENV_PYTHON="$PIFIRE_INSTALL_DIR/.venv/bin/python"
UPDATER_PY="$PIFIRE_INSTALL_DIR/updater.py"
if [ -f "$VENV_PYTHON" ] && [ -f "$UPDATER_PY" ]; then
    $SUDO "$VENV_PYTHON" "$UPDATER_PY" -p
else
    echo "Warning: Could not find venv python ($VENV_PYTHON) or updater.py ($UPDATER_PY) to generate PIP list."
fi

### Setup nginx to proxy to gunicorn
clear
echo "*************************************************************************"
echo "** **"
echo "** Configuring nginx...                               **"
echo "** **"
echo "*************************************************************************"
NGINX_CONFIG_SOURCE_DIR="$PIFIRE_INSTALL_DIR/auto-install/nginx"
if [ ! -d "$NGINX_CONFIG_SOURCE_DIR" ]; then exit_with_error "Nginx config source directory not found: $NGINX_CONFIG_SOURCE_DIR"; fi
cd "$NGINX_CONFIG_SOURCE_DIR" || exit_with_error "Failed to cd to $NGINX_CONFIG_SOURCE_DIR."

if [ -f "/etc/nginx/sites-enabled/default" ] || [ -L "/etc/nginx/sites-enabled/default" ]; then
    $SUDO rm -f /etc/nginx/sites-enabled/default
fi

$SUDO cp pifire.nginx /etc/nginx/sites-available/pifire || exit_with_error "Failed to copy nginx config."
if [ ! -L "/etc/nginx/sites-enabled/pifire" ]; then
    $SUDO ln -sf /etc/nginx/sites-available/pifire /etc/nginx/sites-enabled/pifire || exit_with_error "Failed to create nginx symlink."
fi
$SUDO cp server_error.html /usr/share/nginx/html || exit_with_error "Failed to copy server_error.html."

echo "Restarting nginx..."
$SUDO nginx -t && $SUDO service nginx restart || exit_with_error "Nginx configuration test failed or failed to restart nginx. Check 'sudo nginx -t' and logs."

### Setup Supervisor to Start Apps on Boot / Restart on Failures
clear
echo "*************************************************************************"
echo "** **"
echo "** Configuring Supervisord...                            **"
echo "** **"
echo "*************************************************************************"
SUPERVISOR_CONFIG_SOURCE_DIR="$PIFIRE_INSTALL_DIR/auto-install/supervisor"
if [ ! -d "$SUPERVISOR_CONFIG_SOURCE_DIR" ]; then exit_with_error "Supervisor config source directory not found: $SUPERVISOR_CONFIG_SOURCE_DIR"; fi
cd "$SUPERVISOR_CONFIG_SOURCE_DIR" || exit_with_error "Failed to cd to $SUPERVISOR_CONFIG_SOURCE_DIR."

for conf_file in control.conf webapp.conf pifireapp.conf; do
    if [ -f "$conf_file" ]; then
        TEMP_CONF_FILE=$(mktemp)
        # Copy original content
        cp "$conf_file" "$TEMP_CONF_FILE"
        # Remove existing user line if present to avoid duplicates
        sed -i '/^user=/d' "$TEMP_CONF_FILE"
        # Add new user line
        echo "user=$EFFECTIVE_USER" >> "$TEMP_CONF_FILE"
        # Copy modified file using sudo
        $SUDO cp "$TEMP_CONF_FILE" "/etc/supervisor/conf.d/$conf_file" || exit_with_error "Failed to copy $conf_file to supervisor."
        rm "$TEMP_CONF_FILE"
    else
        echo "Warning: Supervisor config file $conf_file not found in source."
    fi
done

SVISOR_CHOICE=$(whiptail --title "Enable Supervisor WebUI?" --radiolist "This allows checking supervised process status via a web browser and restarting them from this interface. (Recommended)" ${r} ${c} 3 "ENABLE_SVISOR" "Enable the WebUI" ON "DISABLE_SVISOR" "Disable the WebUI" OFF "CANCEL" "Skip Supervisor WebUI Setup" OFF 3>&1 1>&2 2>&3)
SVISOR_CHOICE_EXIT_STATUS=$?

if [ $SVISOR_CHOICE_EXIT_STATUS -eq 0 ]; then
    if [[ $SVISOR_CHOICE = "ENABLE_SVISOR" ]];then
        if ! grep -q "\[inet_http_server\]" /etc/supervisor/supervisord.conf; then
            echo "" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
            echo "[inet_http_server]" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
            echo "port = 0.0.0.0:9001" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
            SVISOR_USER=$(whiptail --inputbox "Choose a username for Supervisor WebUI [default: user]" 8 78 "user" --title "Supervisor WebUI Username" 3>&1 1>&2 2>&3)
            SVISOR_USER_STATUS=$?
            if [ $SVISOR_USER_STATUS -ne 0 ] || [ -z "$SVISOR_USER" ]; then SVISOR_USER="user"; fi

            SVISOR_PASS=$(whiptail --passwordbox "Enter password for Supervisor WebUI user '$SVISOR_USER'" 8 78 --title "Supervisor WebUI Password" 3>&1 1>&2 2>&3)
            SVISOR_PASS_STATUS=$?
            if [ $SVISOR_PASS_STATUS -ne 0 ] || [ -z "$SVISOR_PASS" ]; then
                whiptail --msgbox "No password entered for Supervisor WebUI. WebUI setup aborted." ${r} ${c}
            else
                echo "username = $SVISOR_USER" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
                echo "password = $SVISOR_PASS" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
                whiptail --msgbox --backtitle "Supervisor WebUI Setup" --title "Setup Completed" "You should now be able to access the Supervisor WebUI at http://<your_pi_ip>:9001 with the chosen username and password (after supervisor service reloads/restarts)." ${r} ${c}
            fi
        else
            whiptail --msgbox "Supervisor WebUI [inet_http_server] section already exists in supervisord.conf. Skipping." ${r} ${c}
        fi
    elif [[ $SVISOR_CHOICE = "DISABLE_SVISOR" ]];then
        echo "Supervisor WebUI will remain disabled."
    fi
else
    echo "Supervisor WebUI setup skipped by user."
fi

echo "Reloading supervisor configuration..."
$SUDO supervisorctl reread || echo "Warning: Supervisor reread failed, possibly not running yet or no changes."
$SUDO supervisorctl update || echo "Warning: Supervisor update failed, possibly not running yet or no changes to apply."

if ! $SUDO service supervisor status >/dev/null 2>&1; then
    echo "Starting supervisor service..."
    $SUDO service supervisor start || exit_with_error "Failed to start supervisor service."
else
    echo "Restarting supervisor service to apply all changes..."
    $SUDO service supervisor restart || exit_with_error "Failed to restart supervisor service."
fi

if whiptail --yesno --backtitle "Install Complete / Reboot Required" --title "Installation Completed - Reboot Recommended" "Congratulations, the installation is complete. Some changes (like /tmp on RAM) require a reboot to take full effect. It's recommended to reboot now. Your application should be ready after reboot. On first boot, the wizard may guide you through remaining setup steps. Access your application via the IP address (or http://[hostname].local) of this device.\n\nDo you want to reboot now?" $(($r + 5)) $(($c + 10)); then
    clear
    echo "Rebooting now..."
    $SUDO reboot
else
    clear
    echo "Installation complete. Please reboot manually later for all changes to take effect."
    echo "You can try accessing your application at http://<your_pi_ip_address> (or equivalent hostname)."
fi

exit 0