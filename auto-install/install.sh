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
    $SUDO -v || exit_with_error "Sudo privileges are required. Please ensure you can run sudo commands."
fi

# Find the rows and columns. Will default to 80x24 if it can not be detected.
screen_size=$(stty size 2>/dev/null || echo 24 80)
rows=$(echo $screen_size | awk '{print $1}')
columns=$(echo $screen_size | awk '{print $2}')

r=$(( rows / 2 ))
c=$(( columns / 2 ))
r=$(( r < 20 ? 20 : r ))
c=$(( c < 70 ? 70 : c ))

# --- Initial Prerequisite Installation ---
INSTALL_REQUIRED_PACKAGES_APT=()
if ! command -v whiptail &> /dev/null; then INSTALL_REQUIRED_PACKAGES_APT+=("newt"); fi
if ! command -v git &> /dev/null; then INSTALL_REQUIRED_PACKAGES_APT+=("git"); fi
if ! command -v jq &> /dev/null; then INSTALL_REQUIRED_PACKAGES_APT+=("jq"); fi
if ! command -v curl &> /dev/null; then INSTALL_REQUIRED_PACKAGES_APT+=("curl"); fi

INSTALL_UV_VIA_CURL=false
if ! command -v uv &> /dev/null; then INSTALL_UV_VIA_CURL=true; fi

if [ ${#INSTALL_REQUIRED_PACKAGES_APT[@]} -gt 0 ] || $INSTALL_UV_VIA_CURL; then
    MSG_APT="" && if [ ${#INSTALL_REQUIRED_PACKAGES_APT[@]} -gt 0 ]; then MSG_APT="APT packages: ${INSTALL_REQUIRED_PACKAGES_APT[*]}"; fi
    MSG_UV="" && if $INSTALL_UV_VIA_CURL; then MSG_UV="Python packager 'uv'."; fi
    whiptail --title "Initial Setup" --msgbox "The following essential tools are missing or will be ensured: $MSG_APT $MSG_UV" ${r} ${c}

    if [ ${#INSTALL_REQUIRED_PACKAGES_APT[@]} -gt 0 ]; then
        $SUDO apt update || exit_with_error "Failed to apt update."
        $SUDO apt install -y "${INSTALL_REQUIRED_PACKAGES_APT[@]}" || exit_with_error "Failed to install: ${INSTALL_REQUIRED_PACKAGES_APT[*]}."
    fi
    if $INSTALL_UV_VIA_CURL; then
        echo "Installing UV..."
        if ! (curl -LsSf https://astral.sh/uv/install.sh | $SUDOE env UV_INSTALL_DIR="/usr/local/bin" sh); then
             exit_with_error "Failed to install UV."
        fi
        if ! command -v uv &> /dev/null; then exit_with_error "UV command not found after install. Check PATH."; fi
    fi
fi
# --- End of Initial Prerequisite Installation ---

whiptail --msgbox --backtitle "Welcome" --title "PiFire Automated Installer" "This installer will transform your SBC into a Smoker Controller. Intended for fresh Raspberry Pi OS Lite 32-Bit Bullseye or later." ${r} ${c}

# Ask the user to select a GitHub user
USER_LIST_MENU=()
USER_LIST_MENU+=("1." "dogtreatfairy") # As per user request
USER_LIST_MENU+=("2." "nebhead")     # As per user request
USER_LIST_MENU+=("3." "Other - Enter username")

USER_CHOICE_TAG=$(whiptail --title "Choose a GitHub User" --menu "Select the GitHub user to clone 'pifire' repository from:" ${r} ${c} 3 "${USER_LIST_MENU[@]}" --notags 3>&1 1>&2 2>&3)
USER_CHOICE_EXIT_STATUS=$?

if [ $USER_CHOICE_EXIT_STATUS -ne 0 ]; then exit_with_error "User selection cancelled. Exiting."; fi

if [ "$USER_CHOICE_TAG" = "1." ]; then
    GITHUB_USER="dogtreatfairy"
elif [ "$USER_CHOICE_TAG" = "2." ]; then
    GITHUB_USER="nebhead"
elif [ "$USER_CHOICE_TAG" = "3." ]; then
    GITHUB_USER=$(whiptail --inputbox "Enter the GitHub username to clone 'pifire' from:" 8 78 --title "Custom GitHub User" 3>&1 1>&2 2>&3)
    GITHUB_USER_EXIT_STATUS=$?
    if [ $GITHUB_USER_EXIT_STATUS -ne 0 ] || [ -z "$GITHUB_USER" ]; then
        exit_with_error "No custom GitHub username entered or selection cancelled. Exiting."
    fi
else
    exit_with_error "Invalid user selection '$USER_CHOICE_TAG'. Exiting."
fi

whiptail --infobox "DEBUG: GitHub User set to: '$GITHUB_USER'" 8 78

# List all branches on the server for the selected user's 'pifire' repository
whiptail --infobox "Fetching branches from 'https://github.com/$GITHUB_USER/pifire.git'..." 8 78
BRANCHES_OUTPUT=$(git ls-remote --heads "https://github.com/$GITHUB_USER/pifire.git" 2>&1)
GIT_LS_REMOTE_STATUS=$?

if [ $GIT_LS_REMOTE_STATUS -ne 0 ]; then
    exit_with_error "Error fetching branches for user '$GITHUB_USER' (repository 'pifire').\nDetails:\n$BRANCHES_OUTPUT\n\nPlease check username, repository existence (ensure it's named 'pifire'), and internet connection."
fi

# Process branches
BRANCHES_STR=$(echo "$BRANCHES_OUTPUT" | awk -F'/' '{print $NF}' | sort | grep -vE '^\s*$')

if [ -z "$BRANCHES_STR" ]; then
    whiptail --msgbox "DEBUG: No branches found for user '$GITHUB_USER' in repository 'pifire' after processing 'git ls-remote' output. \nRaw output was:\n$BRANCHES_OUTPUT" ${r} ${c}
    exit_with_error "No branches found to select. Cannot proceed."
fi
whiptail --title "Debug: Branches Found" --msgbox "Branches retrieved for '$GITHUB_USER/pifire':\n$BRANCHES_STR" $(($r + 2)) $(($c + 5))


# Prepare menu for branch selection
BRANCH_LIST_FOR_MENU=()
declare -A BRANCH_TAG_TO_NAME_MAP # Associative array for mapping "N." tag to branch name
declare -a ORDERED_BRANCH_NAMES   # Array to hold branch names

mapfile -t ORDERED_BRANCH_NAMES < <(echo "$BRANCHES_STR")

if [ ${#ORDERED_BRANCH_NAMES[@]} -eq 0 ]; then
    exit_with_error "No branches available for selection after parsing for '$GITHUB_USER/pifire'."
fi

MENU_ITEM_NUMBER=1
for BRANCH_NAME in "${ORDERED_BRANCH_NAMES[@]}"; do
    if [ -n "$BRANCH_NAME" ]; then # Ensure branch name is not empty
        BRANCH_LIST_FOR_MENU+=("$MENU_ITEM_NUMBER." "$BRANCH_NAME") # Tag is "N.", Item is branch name
        BRANCH_TAG_TO_NAME_MAP["$MENU_ITEM_NUMBER."]="$BRANCH_NAME"
        MENU_ITEM_NUMBER=$((MENU_ITEM_NUMBER + 1))
    fi
done

if [ ${#BRANCH_LIST_FOR_MENU[@]} -eq 0 ]; then
    exit_with_error "Failed to prepare any branches for the selection menu. Branch list is empty."
fi

# Debug: Display what will be in the branch menu
MENU_ITEMS_DEBUG_STR="Items prepared for branch menu:\n"
for ((i=0; i<${#BRANCH_LIST_FOR_MENU[@]}; i+=2)); do
    TAG="${BRANCH_LIST_FOR_MENU[i]}"
    ITEM="${BRANCH_LIST_FOR_MENU[i+1]}"
    MAPPED_NAME="${BRANCH_TAG_TO_NAME_MAP[$TAG]}"
    MENU_ITEMS_DEBUG_STR+="Tag: '$TAG', Item: '$ITEM', MappedTo: '$MAPPED_NAME'\n"
done
whiptail --title "Debug: Branch Menu Construction" --msgbox "$MENU_ITEMS_DEBUG_STR" $(($r + 5)) $(($c + 15))


CHOICE_TAG=$(whiptail --title "Choose a Branch" --menu "Select branch from '$GITHUB_USER/pifire' to install:" ${r} ${c} $((${#BRANCH_LIST_FOR_MENU[@]}/2)) "${BRANCH_LIST_FOR_MENU[@]}" --notags 3>&1 1>&2 2>&3)
BRANCH_CHOICE_EXIT_STATUS=$?

if [ $BRANCH_CHOICE_EXIT_STATUS -ne 0 ]; then
    exit_with_error "Branch selection cancelled. Exiting."
fi

SELECTED_BRANCH="${BRANCH_TAG_TO_NAME_MAP[$CHOICE_TAG]}"

if [ -z "$SELECTED_BRANCH" ]; then
    exit_with_error "Could not determine selected branch for choice tag '$CHOICE_TAG'. Exiting."
fi

whiptail --infobox "DEBUG: Selected branch: '$SELECTED_BRANCH'" 8 78

# --- (The rest of your script, starting from Git clone) ---
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
    if whiptail --yesno "Existing PiFire installation found at $PIFIRE_INSTALL_DIR. Remove and re-clone?" ${r} ${c}; then
        echo "Removing existing PiFire directory: $PIFIRE_INSTALL_DIR"
        $SUDO rm -rf "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to remove existing PiFire directory."
    else
        exit_with_error "Cannot proceed with existing directory. Exiting."
    fi
fi

echo "Cloning branch: '$SELECTED_BRANCH' from user: '$GITHUB_USER' (repo 'pifire') into $PIFIRE_INSTALL_DIR"
if ! $SUDO git clone --depth 1 --branch "$SELECTED_BRANCH" "https://github.com/$GITHUB_USER/pifire.git" "$PIFIRE_INSTALL_DIR"; then
    exit_with_error "ERROR: Failed to clone branch '$SELECTED_BRANCH' from '$GITHUB_USER/pifire'.\nPlease double-check username, branch name, and repository permissions/existence.\n\nInstaller will now exit."
fi

cd "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to change directory to $PIFIRE_INSTALL_DIR after clone."
PACKAGE_JSON_PATH="$PIFIRE_INSTALL_DIR/auto-install/package.json"

clear
echo "*************************************************************************"
echo "** Setting /tmp to RAM based storage in /etc/fstab              **"
echo "*************************************************************************"
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp  tmpfs defaults,noatime 0 0" | $SUDO tee -a /etc/fstab > /dev/null
    echo "/tmp added to /etc/fstab. Reboot required for this to take effect."
else
    echo "/tmp already configured in /etc/fstab."
fi

clear
echo "*************************************************************************"
echo "** Running Apt Update... (This could take several minutes)        **"
echo "*************************************************************************"
$SUDO apt update || exit_with_error "apt update failed."

clear
echo "*************************************************************************"
echo "** Running Apt Upgrade... (This could take several minutes)       **"
echo "*************************************************************************"
$SUDO apt upgrade -y || exit_with_error "apt upgrade failed."

clear
echo "*************************************************************************"
echo "** Installing Dependencies... (This could take several minutes)       **"
echo "*************************************************************************"
if [ ! -f "$PACKAGE_JSON_PATH" ]; then exit_with_error "package.json not found: $PACKAGE_JSON_PATH."; fi

APT_PACKAGES=$(jq -r '.apt[] | select(type=="string" and length > 0) | @sh' "$PACKAGE_JSON_PATH" | xargs)
if [ -n "$APT_PACKAGES" ]; then
    echo "Installing APT packages: $APT_PACKAGES"
    # shellcheck disable=SC2086
    $SUDO apt install -y $APT_PACKAGES || exit_with_error "Failed to install APT packages."
else
    echo "No APT packages in package.json."
fi

NPM_APP_DIR="$PIFIRE_INSTALL_DIR/pifire.app"
if [ ! -d "$NPM_APP_DIR" ]; then exit_with_error "pifire.app dir not found: $NPM_APP_DIR"; fi
cd "$NPM_APP_DIR" || exit_with_error "Could not cd to $NPM_APP_DIR."
echo "Running npm install in $(pwd)..."; $SUDO npm install || exit_with_error "npm install failed."
echo "Running npm run build in $(pwd)..."; $SUDO npm run build || exit_with_error "npm run build failed."

cd "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to cd to $PIFIRE_INSTALL_DIR for VENV setup."

clear
echo "*************************************************************************"
echo "** Setting up Python VENV and Installing Modules...               **"
echo "*************************************************************************"
EFFECTIVE_USER=${SUDO_USER:-$USER}
if ! getent group pifire > /dev/null; then $SUDO groupadd pifire || exit_with_error "Failed to add group 'pifire'."; fi
$SUDO usermod -a -G pifire "$EFFECTIVE_USER" || exit_with_error "Failed to add $EFFECTIVE_USER to pifire group."
$SUDO usermod -a -G pifire root

echo "Setting up VENV in $(pwd)"
$SUDO uv venv --system-site-packages .venv || exit_with_error "Failed to create .venv."
if [ ! -d ".venv" ]; then exit_with_error "Python .venv dir not found after creation attempt."; fi
$SUDO chmod -R a+rX .venv

PIP_PACKAGES_FROM_JSON=$(jq -r '.pip[] | select(type=="string" and length > 0) | @sh' "$PACKAGE_JSON_PATH" | xargs)
if [ -n "$PIP_PACKAGES_FROM_JSON" ]; then
    echo "Installing pip packages from package.json into venv: $PIP_PACKAGES_FROM_JSON"
    # shellcheck disable=SC2086
    if ! $SUDO uv pip install $PIP_PACKAGES_FROM_JSON; then exit_with_error "Failed to install pip packages from package.json into venv."; fi
else
    echo "No pip packages in package.json for venv."
fi

PYTHON_FOR_VERSION_CHECK="python3"
if [[ $(uname -a) == *"raspberrypi"* ]]; then
    if ! command -v python3 &> /dev/null && command -v python &> /dev/null; then PYTHON_FOR_VERSION_CHECK="python"; fi
fi
if ! command -v $PYTHON_FOR_VERSION_CHECK &> /dev/null; then exit_with_error "$PYTHON_FOR_VERSION_CHECK not found."; fi

if ! $PYTHON_FOR_VERSION_CHECK -c "import sys; assert sys.version_info[:2] >= (3,11)" > /dev/null 2>&1; then
    echo "$PYTHON_FOR_VERSION_CHECK < 3.11; installing eventlet==0.30.2 into venv"
    if ! $SUDO uv pip install "eventlet==0.30.2"; then exit_with_error "Failed to install eventlet==0.30.2."; fi
else
    echo "$PYTHON_FOR_VERSION_CHECK >= 3.11; installing latest eventlet into venv"
    if ! $SUDO uv pip install eventlet; then exit_with_error "Failed to install eventlet."; fi
fi

REQUIREMENTS_TXT_PATH="$PIFIRE_INSTALL_DIR/auto-install/requirements.txt"
if [ -f "$REQUIREMENTS_TXT_PATH" ]; then
    echo "Installing pip packages from $REQUIREMENTS_TXT_PATH into venv..."
    if ! $SUDO uv pip install -r "$REQUIREMENTS_TXT_PATH"; then exit_with_error "Failed to install from requirements.txt."; fi
else
    echo "Warning: $REQUIREMENTS_TXT_PATH not found."
fi

echo "Setting ownership and permissions for $PIFIRE_INSTALL_DIR"
$SUDO chown -R "$EFFECTIVE_USER:pifire" "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed chown on $PIFIRE_INSTALL_DIR."
$SUDO find "$PIFIRE_INSTALL_DIR" -type d -exec chmod 775 {} \;
$SUDO find "$PIFIRE_INSTALL_DIR" -type f -exec chmod 664 {} \;
$SUDO chmod u+x "$PIFIRE_INSTALL_DIR/.venv/bin/activate" # Ensure activate script is executable if needed manually

BLUEPY_HELPERS=$($SUDO find "$PIFIRE_INSTALL_DIR/.venv/lib/" -path "*/bluepy/bluepy-helper" 2>/dev/null)
if [ -z "$BLUEPY_HELPERS" ]; then
    echo "Warning: No bluepy-helper found in .venv."
else
    for helper in $BLUEPY_HELPERS; do
        echo "Setting capabilities for $helper"; $SUDO setcap "cap_net_raw,cap_net_admin+eip" "$helper" && getcap "$helper"
    done
fi

VENV_PYTHON="$PIFIRE_INSTALL_DIR/.venv/bin/python"; UPDATER_PY="$PIFIRE_INSTALL_DIR/updater.py"
if [ -f "$VENV_PYTHON" ] && [ -f "$UPDATER_PY" ]; then
    echo "Getting PIP List into JSON file..."
    $SUDO "$VENV_PYTHON" "$UPDATER_PY" -p
else
    echo "Warning: $VENV_PYTHON or $UPDATER_PY not found; skipping PIP list generation."
fi

# --- (nginx and supervisor setup as before) ---
NGINX_CONFIG_SOURCE_DIR="$PIFIRE_INSTALL_DIR/auto-install/nginx"
SUPERVISOR_CONFIG_SOURCE_DIR="$PIFIRE_INSTALL_DIR/auto-install/supervisor"

### Setup nginx
clear; echo "Configuring nginx..."
if [ ! -d "$NGINX_CONFIG_SOURCE_DIR" ]; then exit_with_error "Nginx src dir not found: $NGINX_CONFIG_SOURCE_DIR"; fi
cd "$NGINX_CONFIG_SOURCE_DIR" || exit_with_error "Failed to cd to $NGINX_CONFIG_SOURCE_DIR."
if [ -f "/etc/nginx/sites-enabled/default" ] || [ -L "/etc/nginx/sites-enabled/default" ]; then $SUDO rm -f /etc/nginx/sites-enabled/default; fi
$SUDO cp pifire.nginx /etc/nginx/sites-available/pifire || exit_with_error "Failed copy nginx conf."
if [ ! -L "/etc/nginx/sites-enabled/pifire" ]; then $SUDO ln -sf /etc/nginx/sites-available/pifire /etc/nginx/sites-enabled/pifire || exit_with_error "Failed nginx symlink."; fi
$SUDO cp server_error.html /usr/share/nginx/html || exit_with_error "Failed copy server_error.html."
echo "Restarting nginx..."; $SUDO nginx -t && $SUDO service nginx restart || exit_with_error "Nginx config test/restart failed."

### Setup Supervisor
clear; echo "Configuring Supervisord..."
if [ ! -d "$SUPERVISOR_CONFIG_SOURCE_DIR" ]; then exit_with_error "Supervisor src dir not found: $SUPERVISOR_CONFIG_SOURCE_DIR"; fi
cd "$SUPERVISOR_CONFIG_SOURCE_DIR" || exit_with_error "Failed to cd to $SUPERVISOR_CONFIG_SOURCE_DIR."

for conf_file in control.conf webapp.conf pifireapp.conf; do
    if [ -f "$conf_file" ]; then
        TEMP_CONF_FILE=$(mktemp); cp "$conf_file" "$TEMP_CONF_FILE"
        sed -i '/^user=/d' "$TEMP_CONF_FILE"; echo "user=$EFFECTIVE_USER" >> "$TEMP_CONF_FILE"
        $SUDO cp "$TEMP_CONF_FILE" "/etc/supervisor/conf.d/$conf_file" || exit_with_error "Failed copy $conf_file."
        rm "$TEMP_CONF_FILE"
    else echo "Warning: Supervisor conf $conf_file not found in src."; fi
done

SVISOR_CHOICE=$(whiptail --title "Enable Supervisor WebUI?" --radiolist "Enable WebUI for Supervisor?" ${r} ${c} 3 "ENABLE_SVISOR" "Enable" ON "DISABLE_SVISOR" "Disable" OFF "CANCEL" "Skip" OFF 3>&1 1>&2 2>&3)
if [ $? -eq 0 ]; then
    if [[ $SVISOR_CHOICE = "ENABLE_SVISOR" ]];then
        if ! grep -q "\[inet_http_server\]" /etc/supervisor/supervisord.conf; then
            echo -e "\n[inet_http_server]\nport = 0.0.0.0:9001" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
            SVISOR_USER=$(whiptail --inputbox "Supervisor WebUI Username [user]:" 8 78 "user" --title "Supervisor User" 3>&1 1>&2 2>&3)
            if [ $? -ne 0 ] || [ -z "$SVISOR_USER" ]; then SVISOR_USER="user"; fi
            SVISOR_PASS=$(whiptail --passwordbox "Supervisor WebUI Password for '$SVISOR_USER':" 8 78 --title "Supervisor Pass" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ] && [ -n "$SVISOR_PASS" ]; then
                echo "username = $SVISOR_USER" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
                echo "password = $SVISOR_PASS" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
                whiptail --msgbox "Supervisor WebUI enabled on port 9001." ${r} ${c}
            else whiptail --msgbox "Supervisor WebUI password not set. Aborted." ${r} ${c}; fi
        else whiptail --msgbox "Supervisor WebUI already configured." ${r} ${c}; fi
    fi
fi

echo "Reloading supervisor..."; $SUDO supervisorctl reread; $SUDO supervisorctl update
if ! $SUDO service supervisor status >/dev/null 2>&1; then $SUDO service supervisor start || exit_with_error "Failed to start supervisor.";
else $SUDO service supervisor restart || exit_with_error "Failed to restart supervisor."; fi

if whiptail --yesno --backtitle "Install Complete" --title "Reboot Recommended" "Installation complete. Reboot recommended for all changes to take effect.\nReboot now?" $(($r+2)) $c; then
    clear; echo "Rebooting..."; $SUDO reboot
else
    clear; echo "Installation complete. Please reboot manually later."
fi
exit 0