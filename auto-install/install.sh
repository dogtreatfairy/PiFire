#!/usr/bin/env bash

# PiFire Automatic Installation Script
# Target: Raspberry Pi OS Lite (Bullseye or later)

# --- Configuration & Globals ---
PIFIRE_REPO_NAME="pifire" # Standard repository name
PIFIRE_INSTALL_DIR="/usr/local/bin/pifire"
PACKAGE_JSON_PATH_REL="auto-install/package.json" # Relative to PIFIRE_INSTALL_DIR

# --- Utility Functions ---
# Function for graceful exit with a whiptail message
exit_with_error() {
    # $1: Error message
    # $2: Optional title (defaults to "Error")
    local msg="$1"
    local title="${2:-Error}"
    whiptail --title "$title" --msgbox "$msg" ${r:-20} ${c:-70}
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Initial Setup ---
# Determine screen size for whiptail dialogs
screen_size=$(stty size 2>/dev/null || echo 24 80)
rows=$(echo "$screen_size" | awk '{print $1}')
columns=$(echo "$screen_size" | awk '{print $2}')
r=$(( rows / 2 )); c=$(( columns / 2 ))
r=$(( r < 20 ? 20 : r )); c=$(( c < 70 ? 70 : c )) # Min dialog size

# Root/Sudo check
if [[ $EUID -eq 0 ]]; then
    SUDO=""
    SUDOE=""
    EFFECTIVE_USER_NAME="root"
else
    if ! command_exists sudo; then
        echo "ERROR: sudo command not found. Please install sudo or run this script as root."
        exit 1
    fi
    SUDO="sudo"
    SUDOE="sudo -E"
    if ! $SUDO -v; then # Validate sudo timestamp or prompt for password
        exit_with_error "Sudo privileges are required and could not be obtained. Please ensure you can run sudo commands."
    fi
    EFFECTIVE_USER_NAME="${SUDO_USER:-$(whoami)}"
fi
echo "Running as or with privileges of: $EFFECTIVE_USER_NAME"

# --- Install Essential Prerequisites for Script Operation ---
ESSENTIAL_PACKAGES_APT=("newt" "git" "curl" "jq") # newt for whiptail
PACKAGES_TO_INSTALL_APT=()
for pkg in "${ESSENTIAL_PACKAGES_APT[@]}"; do
    if ! command_exists "$pkg"; then
        # Special case for newt providing whiptail
        if [[ "$pkg" == "newt" ]] && command_exists whiptail; then
            continue
        fi
        PACKAGES_TO_INSTALL_APT+=("$pkg")
    fi
done

INSTALL_UV_VIA_CURL=false
if ! command_exists uv; then
    INSTALL_UV_VIA_CURL=true
fi

if [ ${#PACKAGES_TO_INSTALL_APT[@]} -gt 0 ] || $INSTALL_UV_VIA_CURL; then
    MSG_APT=""
    if [ ${#PACKAGES_TO_INSTALL_APT[@]} -gt 0 ]; then
        MSG_APT="Essential APT packages: ${PACKAGES_TO_INSTALL_APT[*]}"
    fi
    MSG_UV=""
    if $INSTALL_UV_VIA_CURL; then
        MSG_UV="Python packager 'uv'."
    fi

    whiptail --title "Prerequisite Installation" --msgbox "The following tools are required for the installer to proceed and will be installed now:\n\n$MSG_APT\n$MSG_UV" ${r} ${c}

    if [ ${#PACKAGES_TO_INSTALL_APT[@]} -gt 0 ]; then
        echo "Updating package lists..."
        $SUDO apt-get update || exit_with_error "Failed to update APT package lists. Check internet connection and sources."
        echo "Installing: ${PACKAGES_TO_INSTALL_APT[*]}..."
        $SUDO apt-get install -y "${PACKAGES_TO_INSTALL_APT[@]}" || exit_with_error "Failed to install essential APT packages: ${PACKAGES_TO_INSTALL_APT[*]}.\nPlease try installing them manually and re-run the script."
    fi

    if $INSTALL_UV_VIA_CURL; then
        echo "Installing uv (Python package manager)..."
        # Use $SUDOE to pass environment if needed, though UV_INSTALL_DIR is explicit
        if ! (curl -LsSf https://astral.sh/uv/install.sh | $SUDOE env UV_INSTALL_DIR="/usr/local/bin" sh); then
             exit_with_error "Failed to download and install 'uv'. Check internet connection or install manually."
        fi
        if ! command_exists uv; then
            exit_with_error "'uv' command still not found after attempted installation. Check PATH or installation logs."
        fi
        echo "'uv' installed successfully to /usr/local/bin."
    fi
    whiptail --title "Prerequisites Installed" --infobox "Essential tools have been installed." 8 78
fi

# --- Welcome Message ---
whiptail --title "PiFire Automated Installer" --msgbox "Welcome! This script will guide you through installing PiFire on your Single Board Computer.\n\nIt is intended for a fresh Raspberry Pi OS Lite (32-bit, Bullseye or later) installation." ${r} ${c}

# --- GitHub User Selection ---
GITHUB_USER=""
USER_MENU_ITEMS=(
    "1" "dogtreatfairy (Recommended)"
    "2" "nebhead"
    "3" "Other - Specify a GitHub username"
)
USER_CHOICE_TAG=$(whiptail --title "Select GitHub User" --menu "Choose the GitHub user whose '$PIFIRE_REPO_NAME' repository you want to use:" ${r} ${c} 3 "${USER_MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
EXIT_STATUS=$?

if [ $EXIT_STATUS -ne 0 ]; then exit_with_error "GitHub User selection cancelled. Exiting."; fi

case "$USER_CHOICE_TAG" in
    "1") GITHUB_USER="dogtreatfairy" ;;
    "2") GITHUB_USER="nebhead" ;;
    "3")
        INPUT_USER=$(whiptail --title "Custom GitHub User" --inputbox "Enter the GitHub username for the '$PIFIRE_REPO_NAME' repository:" 8 78 3>&1 1>&2 2>&3)
        EXIT_STATUS=$?
        if [ $EXIT_STATUS -ne 0 ]; then exit_with_error "Custom GitHub User input cancelled. Exiting."; fi
        if [ -z "$INPUT_USER" ]; then exit_with_error "No GitHub username entered. Exiting."; fi
        GITHUB_USER="$INPUT_USER"
        ;;
    *) exit_with_error "Invalid selection for GitHub User. Exiting." ;;
esac
whiptail --title "User Confirmed" --infobox "Will use GitHub user: $GITHUB_USER" 8 78

# --- Fetch and Select Branch ---
SELECTED_BRANCH=""
REPO_URL="https://github.com/$GITHUB_USER/$PIFIRE_REPO_NAME.git"

whiptail --title "Fetching Branches" --infobox "Attempting to fetch branches from:\n$REPO_URL" 10 ${c}
# The 2>&1 redirects stderr to stdout so we capture error messages from git
BRANCHES_OUTPUT=$(git ls-remote --heads "$REPO_URL" 2>&1)
GIT_LS_REMOTE_STATUS=$?

if [ $GIT_LS_REMOTE_STATUS -ne 0 ]; then
    exit_with_error "Failed to fetch branches from '$REPO_URL'.\n\nError details:\n$BRANCHES_OUTPUT\n\nPlease check the username ('$GITHUB_USER'), repository name ('$PIFIRE_REPO_NAME'), repository visibility, and your internet connection."
fi

# Parse branch names from the output. Handles refs/heads/branch_name format.
# Sorts them and removes any empty lines.
mapfile -t PARSED_BRANCH_NAMES < <(echo "$BRANCHES_OUTPUT" | awk -F'/' '{print $NF}' | sort -u | grep -vE '^\s*$')

if [ ${#PARSED_BRANCH_NAMES[@]} -eq 0 ]; then
    exit_with_error "No branches found for repository '$REPO_URL' after parsing.\n\nRaw 'git ls-remote' output was:\n$BRANCHES_OUTPUT\n\nThis could mean the repository is empty, has no branches, or there was an issue parsing."
fi

BRANCH_MENU_ITEMS=()
declare -A TAG_TO_BRANCH_NAME_MAP # Associative array to map menu tag to actual branch name

for i in "${!PARSED_BRANCH_NAMES[@]}"; do
    BRANCH_NAME="${PARSED_BRANCH_NAMES[i]}"
    MENU_TAG=$((i + 1)) # Human-readable 1-based index for menu
    BRANCH_MENU_ITEMS+=("$MENU_TAG" "$BRANCH_NAME")
    TAG_TO_BRANCH_NAME_MAP["$MENU_TAG"]="$BRANCH_NAME"
done

if [ ${#BRANCH_MENU_ITEMS[@]} -eq 0 ]; then # Should be caught by PARSED_BRANCH_NAMES check, but good to be sure
    exit_with_error "Failed to construct branch selection menu. No branch items were prepared."
fi

BRANCH_CHOICE_TAG=$(whiptail --title "Select Branch" --menu "Select the branch to install from '$GITHUB_USER/$PIFIRE_REPO_NAME':" ${r} ${c} ${#PARSED_BRANCH_NAMES[@]} "${BRANCH_MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
EXIT_STATUS=$?

if [ $EXIT_STATUS -ne 0 ]; then exit_with_error "Branch selection cancelled. Exiting."; fi

SELECTED_BRANCH="${TAG_TO_BRANCH_NAME_MAP[$BRANCH_CHOICE_TAG]}"

if [ -z "$SELECTED_BRANCH" ]; then
    exit_with_error "Could not determine selected branch from tag '$BRANCH_CHOICE_TAG'. This is an unexpected error."
fi
whiptail --title "Branch Confirmed" --infobox "Will install branch: $SELECTED_BRANCH" 8 78

# --- Clone Repository ---
clear
echo "*************************************************************************"
echo "** Cloning '$PIFIRE_REPO_NAME' from GitHub..."
echo "** User: $GITHUB_USER"
echo "** Branch: $SELECTED_BRANCH"
echo "** URL: $REPO_URL"
echo "** Target Directory: $PIFIRE_INSTALL_DIR"
echo "*************************************************************************"

if [ ! -d "$(dirname "$PIFIRE_INSTALL_DIR")" ]; then
    $SUDO mkdir -p "$(dirname "$PIFIRE_INSTALL_DIR")" || exit_with_error "Failed to create parent directory for $PIFIRE_INSTALL_DIR."
fi

if [ -d "$PIFIRE_INSTALL_DIR" ]; then
    if whiptail --title "Existing Installation" --yesno "An existing PiFire installation was found at:\n$PIFIRE_INSTALL_DIR\n\nDo you want to remove it and proceed with a fresh clone?" ${r} ${c}; then
        echo "Removing existing directory: $PIFIRE_INSTALL_DIR"
        $SUDO rm -rf "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to remove existing directory '$PIFIRE_INSTALL_DIR'. Check permissions or remove manually."
    else
        exit_with_error "Installation aborted by user due to existing directory."
    fi
fi

echo "Cloning..."
# Use $SUDO for the clone if PIFIRE_INSTALL_DIR is in a privileged location like /usr/local/bin
if ! $SUDO git clone --depth 1 --branch "$SELECTED_BRANCH" "$REPO_URL" "$PIFIRE_INSTALL_DIR"; then
    exit_with_error "Failed to clone repository.\nBranch: '$SELECTED_BRANCH'\nURL: '$REPO_URL'\nPlease check logs for details."
fi
echo "Repository cloned successfully to $PIFIRE_INSTALL_DIR."

# --- Post-Clone Setup ---
# Now that the repo is cloned, we can access files like package.json from it.
FULL_PACKAGE_JSON_PATH="$PIFIRE_INSTALL_DIR/$PACKAGE_JSON_PATH_REL"
if [ ! -f "$FULL_PACKAGE_JSON_PATH" ]; then
    exit_with_error "Cloned repository, but package.json not found at expected location: $FULL_PACKAGE_JSON_PATH"
fi

clear
echo "*************************************************************************"
echo "** Setting /tmp to RAM based storage in /etc/fstab"
echo "*************************************************************************"
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    # Check if the line already exists to prevent duplicates
    if $SUDO sed -i'.bak' '/tmpfs \/tmp/d' /etc/fstab; then # remove existing /tmp entries if any
         echo "Removed existing /tmp mount from /etc/fstab to avoid conflict."
    fi
    echo "tmpfs /tmp  tmpfs defaults,noatime,nosuid,nodev,size=512m 0 0" | $SUDO tee -a /etc/fstab > /dev/null
    echo "/tmp configured in /etc/fstab for RAM disk. A reboot or 'sudo mount -a' is required for this to take effect."
else
    echo "/tmp already appears to be configured in /etc/fstab."
fi

clear
echo "*************************************************************************"
echo "** Running Apt Update (again, to ensure fresh lists before main install)"
echo "*************************************************************************"
$SUDO apt-get update || echo "Warning: apt-get update failed. Continuing, but package installation might be affected."

clear
echo "*************************************************************************"
echo "** Running Apt System Upgrade (Recommended)"
echo "*************************************************************************"
if whiptail --title "System Upgrade" --yesno "It's recommended to upgrade all system packages before proceeding.\nThis can take some time.\n\nDo you want to run 'sudo apt-get upgrade -y' now?" ${r} ${c}; then
    echo "Performing system upgrade (apt-get upgrade -y)..."
    $SUDO apt-get upgrade -y || echo "Warning: apt-get upgrade had issues. Check logs. Continuing installation."
else
    echo "Skipping full system upgrade."
fi

clear
echo "*************************************************************************"
echo "** Installing Application APT Dependencies from package.json"
echo "*************************************************************************"
# jq -r '.apt[]? | select(.!=null and .!="") | @sh' handles missing .apt key or empty strings
APT_PACKAGES_CMD=$(jq -r '.apt[]? | select(.!=null and .!="") | @sh' "$FULL_PACKAGE_JSON_PATH" | xargs echo)

if [ -n "$APT_PACKAGES_CMD" ]; then
    echo "Found APT packages in package.json: $APT_PACKAGES_CMD"
    # shellcheck disable=SC2086 # We want word splitting here after xargs
    $SUDO apt-get install -y $APT_PACKAGES_CMD || exit_with_error "Failed to install one or more APT packages listed in package.json: $APT_PACKAGES_CMD"
    echo "Application APT dependencies installed."
else
    echo "No application-specific APT packages found in '$FULL_PACKAGE_JSON_PATH' or '.apt' key is missing/empty."
fi

# --- Node.js Application Build (pifire.app) ---
NPM_APP_DIR="$PIFIRE_INSTALL_DIR/pifire.app"
if [ -d "$NPM_APP_DIR" ]; then
    if [ -f "$NPM_APP_DIR/package.json" ]; then
        clear
        echo "*************************************************************************"
        echo "** Building Node.js application (pifire.app)"
        echo "*************************************************************************"
        cd "$NPM_APP_DIR" || exit_with_error "Could not change directory to $NPM_APP_DIR"
        echo "Running 'npm install' in $(pwd)... (This may take a while)"
        # Use $SUDO if npm needs to write to global locations or if files are root-owned
        # If npm is managed by nvm for the user, sudo might not be desired or could cause issues.
        # Assuming for now that system-wide node/npm or sudo is appropriate for this install script context.
        if $SUDO npm install; then
            echo "npm install completed."
            echo "Running 'npm run build' in $(pwd)..."
            if $SUDO npm run build; then
                echo "npm run build completed."
            else
                exit_with_error "'npm run build' failed in $NPM_APP_DIR. Check logs."
            fi
        else
            exit_with_error "'npm install' failed in $NPM_APP_DIR. Check logs. Ensure Node.js and npm are installed and accessible."
        fi
        cd "$PIFIRE_INSTALL_DIR" # Return to base install directory
    else
        echo "Warning: $NPM_APP_DIR/package.json not found. Skipping npm install/build for pifire.app."
    fi
else
    echo "Info: Node.js application directory '$NPM_APP_DIR' not found. Skipping npm steps."
fi


# --- Python Virtual Environment and Dependencies ---
clear
echo "*************************************************************************"
echo "** Setting up Python Virtual Environment & Installing Modules"
echo "*************************************************************************"
cd "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to cd to $PIFIRE_INSTALL_DIR for VENV setup."

echo "Creating/Recreating Python virtual environment (.venv) using 'uv'..."
# $SUDO uv venv --system-site-packages .venv || exit_with_error "Failed to create Python virtual environment using 'uv'."
# Giving ownership to EFFECTIVE_USER_NAME before creating venv to avoid sudo for uv venv
$SUDO chown -R "$EFFECTIVE_USER_NAME:$EFFECTIVE_USER_NAME" "$PIFIRE_INSTALL_DIR"
echo "Running uv venv as $EFFECTIVE_USER_NAME"
# Run uv as the effective user to avoid permission issues inside venv later
$SUDO -u "$EFFECTIVE_USER_NAME" uv venv --python python3 --system-site-packages .venv
if [ ! -d ".venv/bin" ]; then
    exit_with_error "Python virtual environment '.venv/bin' not found after 'uv venv' command. Creation failed."
fi
echo "Virtual environment created."

# Activate venv for subsequent pip installs if needed, or use .venv/bin/pip
VENV_PYTHON="$PIFIRE_INSTALL_DIR/.venv/bin/python"
VENV_PIP="$PIFIRE_INSTALL_DIR/.venv/bin/pip" # uv can also be used with `uv pip install`
VENV_UV_PIP="$SUDO -u \"$EFFECTIVE_USER_NAME\" $PIFIRE_INSTALL_DIR/.venv/bin/uv pip"


# Install pip packages from package.json (if any)
PIP_PACKAGES_JSON_CMD=$(jq -r '.pip[]? | select(.!=null and .!="") | @sh' "$FULL_PACKAGE_JSON_PATH" | xargs echo)
if [ -n "$PIP_PACKAGES_JSON_CMD" ]; then
    echo "Installing pip packages from package.json via uv: $PIP_PACKAGES_JSON_CMD"
    # shellcheck disable=SC2086
    if ! eval "$VENV_UV_PIP install $PIP_PACKAGES_JSON_CMD"; then
         exit_with_error "Failed to install pip packages from package.json using uv."
    fi
else
    echo "No pip packages specified in package.json under '.pip' key."
fi

# Install eventlet based on Python version
PYTHON_VER_CHECK_CMD="$VENV_PYTHON -c \"import sys; sys.exit(0 if sys.version_info[:2] >= (3,11) else 1)\""
if eval "$PYTHON_VER_CHECK_CMD"; then # Python 3.11+
    echo "Python version is 3.11 or greater. Installing latest eventlet via uv."
    if ! eval "$VENV_UV_PIP install eventlet"; then exit_with_error "Failed to install latest eventlet using uv."; fi
else # Python < 3.11
    echo "Python version is less than 3.11. Installing eventlet==0.30.2 via uv."
    if ! eval "$VENV_UV_PIP install 'eventlet==0.30.2'"; then exit_with_error "Failed to install eventlet==0.30.2 using uv."; fi
fi

# Install packages from requirements.txt
REQUIREMENTS_TXT_PATH="$PIFIRE_INSTALL_DIR/auto-install/requirements.txt"
if [ -f "$REQUIREMENTS_TXT_PATH" ]; then
    echo "Installing Python packages from $REQUIREMENTS_TXT_PATH via uv..."
    if ! eval "$VENV_UV_PIP install -r \"$REQUIREMENTS_TXT_PATH\""; then
        exit_with_error "Failed to install Python packages from '$REQUIREMENTS_TXT_PATH' using uv."
    fi
else
    echo "Warning: 'auto-install/requirements.txt' not found. Skipping."
fi

# --- Permissions, Group, and Bluepy ---
echo "Setting up 'pifire' group and permissions..."
if ! getent group pifire > /dev/null; then
    $SUDO groupadd pifire || echo "Warning: Failed to add group 'pifire'. It might already exist."
fi
$SUDO usermod -a -G pifire "$EFFECTIVE_USER_NAME" || echo "Warning: Failed to add user '$EFFECTIVE_USER_NAME' to 'pifire' group."
# $SUDO usermod -a -G pifire root # Adding root to pifire group is unusual, consider if necessary

# Final ownership and permissions for the install directory
$SUDO chown -R "$EFFECTIVE_USER_NAME:pifire" "$PIFIRE_INSTALL_DIR"
$SUDO chmod -R g+w "$PIFIRE_INSTALL_DIR" # Group write access
$SUDO find "$PIFIRE_INSTALL_DIR" -type d -exec chmod g+s {} \; # Setgid bit for directories

# bluepy-helper capabilities
# Find bluepy-helper within the created venv
# Need to run find as root if .venv is root-owned initially, or ensure EFFECTIVE_USER_NAME has read access
BLUEPY_HELPERS=$($SUDO find "$PIFIRE_INSTALL_DIR/.venv/lib/" -name "bluepy-helper" -type f 2>/dev/null)
if [ -n "$BLUEPY_HELPERS" ]; then
    for helper_path in $BLUEPY_HELPERS; do
        echo "Setting capabilities for $helper_path"
        $SUDO setcap 'cap_net_raw,cap_net_admin+eip' "$helper_path"
        $SUDO getcap "$helper_path" # Verify
    done
else
    echo "Warning: bluepy-helper not found in the virtual environment. Bluetooth features might not work."
fi

# updater.py -p
UPDATER_PY_PATH="$PIFIRE_INSTALL_DIR/updater.py"
if [ -f "$UPDATER_PY_PATH" ]; then
    echo "Running updater.py -p to generate PIP list..."
    # Run as the effective user within the venv
    if ! $SUDO -u "$EFFECTIVE_USER_NAME" "$VENV_PYTHON" "$UPDATER_PY_PATH" -p; then
        echo "Warning: 'updater.py -p' command failed."
    fi
else
    echo "Warning: '$UPDATER_PY_PATH' not found. Skipping PIP list generation."
fi

# --- Nginx Setup ---
NGINX_CONFIG_DIR="$PIFIRE_INSTALL_DIR/auto-install/nginx"
if [ -d "$NGINX_CONFIG_DIR" ]; then
    clear
    echo "*************************************************************************"
    echo "** Configuring nginx..."
    echo "*************************************************************************"
    cd "$NGINX_CONFIG_DIR" || exit_with_error "Failed to cd to $NGINX_CONFIG_DIR"

    if [ -f "/etc/nginx/sites-enabled/default" ] || [ -L "/etc/nginx/sites-enabled/default" ]; then
        $SUDO rm -f /etc/nginx/sites-enabled/default
        echo "Removed default nginx site configuration."
    fi

    $SUDO cp pifire.nginx /etc/nginx/sites-available/pifire || exit_with_error "Failed to copy pifire nginx config."
    if [ ! -L "/etc/nginx/sites-enabled/pifire" ]; then # Check if symlink exists
         $SUDO ln -sf /etc/nginx/sites-available/pifire /etc/nginx/sites-enabled/pifire || exit_with_error "Failed to create symlink for pifire nginx site."
    fi
    $SUDO cp server_error.html /usr/share/nginx/html/ || exit_with_error "Failed to copy server_error.html."

    echo "Testing nginx configuration..."
    if $SUDO nginx -t; then
        echo "Nginx configuration test successful. Restarting nginx..."
        $SUDO systemctl restart nginx || exit_with_error "Failed to restart nginx service."
    else
        exit_with_error "Nginx configuration test failed. Please check 'sudo nginx -t' output and resolve issues."
    fi
else
    echo "Warning: Nginx configuration directory '$NGINX_CONFIG_DIR' not found. Skipping nginx setup."
fi

# --- Supervisor Setup ---
SUPERVISOR_CONFIG_DIR="$PIFIRE_INSTALL_DIR/auto-install/supervisor"
if [ -d "$SUPERVISOR_CONFIG_DIR" ]; then
    clear
    echo "*************************************************************************"
    echo "** Configuring Supervisord..."
    echo "*************************************************************************"
    cd "$SUPERVISOR_CONFIG_DIR" || exit_with_error "Failed to cd to $SUPERVISOR_CONFIG_DIR"

    for conf_template in control.conf webapp.conf pifireapp.conf; do
        if [ -f "$conf_template" ]; then
            # Create a temporary file for sed modifications
            TEMP_CONF=$(mktemp)
            cp "$conf_template" "$TEMP_CONF"
            # Replace placeholder or ensure user line is correct
            # Remove existing user line if any, then add the correct one
            sed -i '/^user=/d' "$TEMP_CONF" # Delete existing user lines
            echo "user=$EFFECTIVE_USER_NAME" >> "$TEMP_CONF" # Add the correct user

            # Also replace path placeholders if any, e.g. /usr/local/bin/pifire
            # Assuming PIFIRE_INSTALL_DIR needs to be escaped for sed if it contains slashes
            ESCAPED_INSTALL_DIR=$(echo "$PIFIRE_INSTALL_DIR" | sed 's/\//\\\//g')
            sed -i "s/%%PIFIRE_INSTALL_DIR%%/$ESCAPED_INSTALL_DIR/g" "$TEMP_CONF"
            sed -i "s/%%VENV_PYTHON%%/$(echo $VENV_PYTHON | sed 's/\//\\\//g')/g" "$TEMP_CONF"


            $SUDO cp "$TEMP_CONF" "/etc/supervisor/conf.d/$(basename "$conf_template")" || exit_with_error "Failed to copy $conf_template to /etc/supervisor/conf.d/"
            rm "$TEMP_CONF"
            echo "Copied and configured $(basename "$conf_template") for supervisor."
        else
            echo "Warning: Supervisor config template '$conf_template' not found."
        fi
    done

    # Supervisor WebUI (Optional)
    if whiptail --title "Supervisor WebUI" --yesno "Do you want to enable the Supervisor WebUI?\n(Access on port 9001, requires username/password setup)" ${r} ${c}; then
        if ! grep -q "\[inet_http_server\]" /etc/supervisor/supervisord.conf; then
            SVISOR_USER=$(whiptail --inputbox "Choose a username for Supervisor WebUI [default: pifireuser]" 8 78 "pifireuser" --title "Supervisor WebUI Username" 3>&1 1>&2 2>&3)
            EXIT_STATUS=$?
            if [ $EXIT_STATUS -eq 0 ] && [ -n "$SVISOR_USER" ]; then
                SVISOR_PASS=$(whiptail --passwordbox "Enter password for Supervisor WebUI user '$SVISOR_USER':" 8 78 --title "Supervisor WebUI Password" 3>&1 1>&2 2>&3)
                EXIT_STATUS=$?
                if [ $EXIT_STATUS -eq 0 ] && [ -n "$SVISOR_PASS" ]; then
                    echo ""  | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
                    echo "[inet_http_server]" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
                    echo "port = 0.0.0.0:9001" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
                    echo "username = $SVISOR_USER" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
                    echo "password = $SVISOR_PASS" | $SUDO tee -a /etc/supervisor/supervisord.conf > /dev/null
                    whiptail --title "Supervisor WebUI" --msgbox "Supervisor WebUI enabled on port 9001.\nUsername: $SVISOR_USER" ${r} ${c}
                else
                    whiptail --title "Supervisor WebUI" --msgbox "Password not provided. Supervisor WebUI setup aborted." ${r} ${c}
                fi
            else
                 whiptail --title "Supervisor WebUI" --msgbox "Username not provided or cancelled. Supervisor WebUI setup aborted." ${r} ${c}
            fi
        else
            whiptail --title "Supervisor WebUI" --msgbox "Supervisor WebUI [inet_http_server] section already exists in supervisord.conf. Skipping manual setup." ${r} ${c}
        fi
    else
        echo "Supervisor WebUI setup skipped by user."
    fi

    echo "Reloading supervisor configuration..."
    $SUDO supervisorctl reread || echo "Warning: 'supervisorctl reread' failed. Supervisor might not be running or no changes detected."
    $SUDO supervisorctl update || echo "Warning: 'supervisorctl update' failed. Ensure supervisor service is active."
    if ! $SUDO systemctl is-active --quiet supervisor; then
        echo "Supervisor service is not active. Attempting to start..."
        $SUDO systemctl start supervisor || exit_with_error "Failed to start supervisor service."
        $SUDO systemctl enable supervisor || echo "Warning: Failed to enable supervisor service to start on boot."
    else
        echo "Supervisor service is active. Restarting to apply changes..."
        $SUDO systemctl restart supervisor || exit_with_error "Failed to restart supervisor service."
    fi
else
    echo "Warning: Supervisor configuration directory '$SUPERVISOR_CONFIG_DIR' not found. Skipping supervisor setup."
fi

# --- Final Instructions & Reboot ---
clear
if whiptail --title "Installation Complete" --yesno "PiFire installation is complete!\n\nSome changes (like /tmp on RAM and service startups) may require or benefit from a system reboot.\n\nIt is recommended to reboot now.\n\nAfter reboot, you should be able to access PiFire via its IP address in a web browser. The first launch might involve a setup wizard.\n\nDo you want to reboot the system now?" $(($r + 5)) $(($c + 10)); then
    echo "Rebooting system..."
    $SUDO reboot
else
    echo "Installation complete. Please reboot your system manually when convenient."
    echo "Access PiFire at http://<your_pi_ip_address>"
fi

exit 0