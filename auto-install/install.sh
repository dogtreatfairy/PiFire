#!/usr/bin/env bash

# PiFire Automatic Installation Script
# Target: Raspberry Pi OS Lite (Bullseye or later)

# --- Configuration & Globals ---
PIFIRE_REPO_NAME="pifire"
PIFIRE_INSTALL_DIR="/usr/local/bin/pifire"
PACKAGE_JSON_PATH_REL="auto-install/package.json" # Relative to PIFIRE_INSTALL_DIR

# --- Utility Functions ---
exit_with_error() {
    local msg="$1"; local title="${2:-Error}"
    whiptail --title "$title" --msgbox "$msg" ${r:-20} ${c:-70}
    exit 1
}
command_exists() { command -v "$1" >/dev/null 2>&1; }

# --- Initial Setup ---
screen_size=$(stty size 2>/dev/null || echo 24 80)
rows=$(echo "$screen_size" | awk '{print $1}'); columns=$(echo "$screen_size" | awk '{print $2}')
r=$(( rows / 2 )); c=$(( columns / 2 ))
r=$(( r < 20 ? 20 : r )); c=$(( c < 70 ? 70 : c )) # Min dialog size

# --- Determine Effective User for file ownership and user-context commands ---
SUDO_CMD_PREFIX="" # Will be "sudo" if not root
EFFECTIVE_USER_NAME=""

if [[ $EUID -eq 0 ]]; then # Script is run as root
    SUDO_CMD_PREFIX=""
    if [ -n "$SUDO_USER" ] && id "$SUDO_USER" &>/dev/null; then
        EFFECTIVE_USER_NAME="$SUDO_USER"
        echo "Script running as root, SUDO_USER='$SUDO_USER' is set and valid. Will use for PiFire ownership."
    else
        EFFECTIVE_USER_NAME="root" # Default to root if no better user context from sudo
        echo "Script running as root. PiFire file ownership will default to root if no other user is specified or found."
        # Attempt to find a primary non-root user if running as plain root.
        CANDIDATE_USER=$(awk -F: '($3 >= 1000 && $3 < 60000) && $7!~/(nologin|false)$/ {print $1}' /etc/passwd | head -n 1)
        if [ -n "$CANDIDATE_USER" ]; then
             if whiptail --yesno "Running as root. Found potential regular user '$CANDIDATE_USER'.\nSet PiFire ownership and run user-specific commands as '$CANDIDATE_USER'?" ${r} ${c}; then
                EFFECTIVE_USER_NAME="$CANDIDATE_USER"
             else
                echo "Proceeding with 'root' as the effective user for ownership."
             fi
        fi
    fi
else # Script is run with sudo by a non-root user
    SUDO_CMD_PREFIX="sudo"
    if ! command_exists sudo; then echo "ERROR: sudo command not found."; exit 1; fi
    if ! $SUDO_CMD_PREFIX -v; then exit_with_error "Sudo privileges validation failed."; fi
    if [ -n "$SUDO_USER" ]; then EFFECTIVE_USER_NAME="$SUDO_USER";
    else exit_with_error "CRITICAL: Not root (EUID=$EUID), but SUDO_USER not set."; fi
fi

echo "Effective user for PiFire file ownership and user-specific commands: '$EFFECTIVE_USER_NAME'"

if ! id "$EFFECTIVE_USER_NAME" >/dev/null 2>&1; then
    exit_with_error "User '$EFFECTIVE_USER_NAME' NOT recognized by system ('id $EFFECTIVE_USER_NAME' failed).\nEnsure this user exists. This may be a system configuration issue."
fi
echo "User '$EFFECTIVE_USER_NAME' verified with 'id' command."

# ===>> ADDED: Explicit test of 'sudo -u <user> true' <<===
if [ "$EFFECTIVE_USER_NAME" != "root" ]; then # No need to 'sudo -u root true' if EFFECTIVE_USER_NAME is already root
    echo "Performing a test of 'sudo -u $EFFECTIVE_USER_NAME true' to check user-switching capability..."
    # The errors from this command will go to stderr and be visible.
    if ! $SUDO_CMD_PREFIX -u "$EFFECTIVE_USER_NAME" true; then
        # The actual error messages from sudo (like "unknown user" or "audit plugin") should appear just before this.
        exit_with_error "TEST of 'sudo -u $EFFECTIVE_USER_NAME true' FAILED.\nThis indicates a problem with sudo's ability to switch to user '$EFFECTIVE_USER_NAME'.\nThis is often caused by system-level sudo configuration issues (e.g., 'sudoers_audit' errors, incorrect /etc/sudoers, or PAM problems).\nThese system issues MUST be resolved before the script can proceed reliably."
    fi
    echo "'sudo -u $EFFECTIVE_USER_NAME true' test PASSED. Basic user switching via sudo appears functional."
fi
# Global SUDO variable for commands that need root privileges generally
SUDO="$SUDO_CMD_PREFIX"


# --- Install Essential Prerequisites for Script Operation ---
# (This section was already good, ensure $SUDO is used correctly if defined)
ESSENTIAL_PACKAGES_APT=("newt" "git" "curl" "jq")
PACKAGES_TO_INSTALL_APT=()
for pkg in "${ESSENTIAL_PACKAGES_APT[@]}"; do
    CMD_TO_CHECK="$pkg"
    if [[ "$pkg" == "newt" ]]; then CMD_TO_CHECK="whiptail"; fi
    if ! command_exists "$CMD_TO_CHECK"; then PACKAGES_TO_INSTALL_APT+=("$pkg"); fi
done
INSTALL_UV_VIA_CURL=false
if ! command_exists uv; then INSTALL_UV_VIA_CURL=true; fi

if [ ${#PACKAGES_TO_INSTALL_APT[@]} -gt 0 ] || $INSTALL_UV_VIA_CURL; then
    MSG_APT="" && if [ ${#PACKAGES_TO_INSTALL_APT[@]} -gt 0 ]; then MSG_APT="APT pkgs: ${PACKAGES_TO_INSTALL_APT[*]}"; fi
    MSG_UV="" && if $INSTALL_UV_VIA_CURL; then MSG_UV="Python packager 'uv'."; fi
    whiptail --title "Prerequisite Installation" --msgbox "Required tools will be installed/ensured:\n$MSG_APT\n$MSG_UV" ${r} ${c}

    if [ ${#PACKAGES_TO_INSTALL_APT[@]} -gt 0 ]; then
        echo "Updating package lists..."; $SUDO apt-get update || exit_with_error "Failed to update APT lists."
        echo "Installing: ${PACKAGES_TO_INSTALL_APT[*]}..."; $SUDO apt-get install -y "${PACKAGES_TO_INSTALL_APT[@]}" || exit_with_error "Failed to install: ${PACKAGES_TO_INSTALL_APT[*]}."
    fi
    if $INSTALL_UV_VIA_CURL; then
        echo "Installing uv...";
        # Use $SUDO for sh because it's writing to /usr/local/bin
        if ! (curl -LsSf https://astral.sh/uv/install.sh | $SUDO env UV_INSTALL_DIR="/usr/local/bin" sh); then
             exit_with_error "Failed to install 'uv'."
        fi
        if ! command_exists uv; then exit_with_error "'uv' cmd not found after install. Check PATH."; fi
        echo "'uv' installed to /usr/local/bin."
    fi
fi

# --- Welcome Message ---
whiptail --title "PiFire Automated Installer" --msgbox "Welcome! This script will guide you through installing PiFire.\nIntended for fresh Raspberry Pi OS Lite (Bullseye or later)." ${r} ${c}

# --- GitHub User Selection ---
GITHUB_USER=""
USER_MENU_ITEMS=( "1" "dogtreatfairy (Recommended)" "2" "nebhead" "3" "Other - Specify username" )
USER_CHOICE_TAG=$(whiptail --title "Select GitHub User" --menu "Whose '$PIFIRE_REPO_NAME' repository to use?" ${r} ${c} 3 "${USER_MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then exit_with_error "User selection cancelled."; fi
case "$USER_CHOICE_TAG" in
    "1") GITHUB_USER="dogtreatfairy" ;;
    "2") GITHUB_USER="nebhead" ;;
    "3") INPUT_USER=$(whiptail --title "Custom GitHub User" --inputbox "Enter GitHub username for '$PIFIRE_REPO_NAME' repo:" 8 78 3>&1 1>&2 2>&3)
         if [ $? -ne 0 ] || [ -z "$INPUT_USER" ]; then exit_with_error "No custom GitHub user entered or cancelled."; fi
         GITHUB_USER="$INPUT_USER" ;;
    *) exit_with_error "Invalid user selection." ;;
esac
whiptail --title "User Confirmed" --infobox "Will use GitHub user: $GITHUB_USER" 8 78

# --- Fetch and Select Branch ---
SELECTED_BRANCH=""
REPO_URL="https://github.com/$GITHUB_USER/$PIFIRE_REPO_NAME.git"
whiptail --title "Fetching Branches" --infobox "Fetching branches from:\n$REPO_URL" 10 ${c}
BRANCHES_OUTPUT=$(git ls-remote --heads "$REPO_URL" 2>&1); GIT_LS_REMOTE_STATUS=$?
if [ $GIT_LS_REMOTE_STATUS -ne 0 ]; then exit_with_error "Failed to fetch branches from '$REPO_URL'.\n\nDetails:\n$BRANCHES_OUTPUT\n\nCheck user ('$GITHUB_USER'), repo ('$PIFIRE_REPO_NAME'), visibility, and internet."; fi
mapfile -t PARSED_BRANCH_NAMES < <(echo "$BRANCHES_OUTPUT" | awk -F'/' '{print $NF}' | sort -u | grep -vE '^\s*$')
if [ ${#PARSED_BRANCH_NAMES[@]} -eq 0 ]; then exit_with_error "No branches found for '$REPO_URL' after parsing:\n$BRANCHES_OUTPUT"; fi
BRANCH_MENU_ITEMS=(); declare -A TAG_TO_BRANCH_NAME_MAP
for i in "${!PARSED_BRANCH_NAMES[@]}"; do
    BRANCH_NAME="${PARSED_BRANCH_NAMES[i]}"; MENU_TAG=$((i + 1))
    BRANCH_MENU_ITEMS+=("$MENU_TAG" "$BRANCH_NAME"); TAG_TO_BRANCH_NAME_MAP["$MENU_TAG"]="$BRANCH_NAME"
done
if [ ${#BRANCH_MENU_ITEMS[@]} -eq 0 ]; then exit_with_error "Failed to construct branch menu."; fi
BRANCH_CHOICE_TAG=$(whiptail --title "Select Branch" --menu "Select branch from '$GITHUB_USER/$PIFIRE_REPO_NAME':" ${r} ${c} ${#PARSED_BRANCH_NAMES[@]} "${BRANCH_MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then exit_with_error "Branch selection cancelled."; fi
SELECTED_BRANCH="${TAG_TO_BRANCH_NAME_MAP[$BRANCH_CHOICE_TAG]}"
if [ -z "$SELECTED_BRANCH" ]; then exit_with_error "Could not determine selected branch from tag '$BRANCH_CHOICE_TAG'."; fi
whiptail --title "Branch Confirmed" --infobox "Will install branch: $SELECTED_BRANCH" 8 78

# --- Clone Repository ---
clear; echo "Cloning '$PIFIRE_REPO_NAME' (User: $GITHUB_USER, Branch: $SELECTED_BRANCH) into $PIFIRE_INSTALL_DIR"
if [ ! -d "$(dirname "$PIFIRE_INSTALL_DIR")" ]; then $SUDO mkdir -p "$(dirname "$PIFIRE_INSTALL_DIR")" || exit_with_error "Failed create parent dir for $PIFIRE_INSTALL_DIR."; fi
if [ -d "$PIFIRE_INSTALL_DIR" ]; then
    if whiptail --yesno "Existing install: $PIFIRE_INSTALL_DIR\nRemove & re-clone?" ${r} ${c}; then
        $SUDO rm -rf "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed remove $PIFIRE_INSTALL_DIR."
    else exit_with_error "Install aborted (existing directory)."; fi
fi
if ! $SUDO git clone --depth 1 --branch "$SELECTED_BRANCH" "$REPO_URL" "$PIFIRE_INSTALL_DIR"; then exit_with_error "Failed to clone repo.\nBranch: '$SELECTED_BRANCH'\nURL: '$REPO_URL'"; fi
echo "Repo cloned to $PIFIRE_INSTALL_DIR."
FULL_PACKAGE_JSON_PATH="$PIFIRE_INSTALL_DIR/$PACKAGE_JSON_PATH_REL"
if [ ! -f "$FULL_PACKAGE_JSON_PATH" ]; then exit_with_error "Cloned repo, but $FULL_PACKAGE_JSON_PATH not found."; fi

# --- /tmp on RAM ---
echo "Configuring /tmp on RAM..."; if ! grep -q "tmpfs /tmp" /etc/fstab; then echo "tmpfs /tmp  tmpfs defaults,noatime,nosuid,nodev,size=256m 0 0" | $SUDO tee -a /etc/fstab > /dev/null; echo "/tmp added to /etc/fstab."; else echo "/tmp already in /etc/fstab."; fi

# --- APT Update/Upgrade ---
echo "Running apt-get update..."; $SUDO apt-get update || echo "Warning: apt-get update failed."
if whiptail --yesno "Upgrade all system packages (recommended)?" ${r} ${c}; then echo "Upgrading system..."; $SUDO apt-get upgrade -y || echo "Warning: apt upgrade had issues."; else echo "Skipping system upgrade."; fi

# --- Application APT Dependencies ---
echo "Installing App APT deps from package.json..."
APT_PACKAGES_CMD=$(jq -r '.apt[]? | select(.!=null and .!="") | @sh' "$FULL_PACKAGE_JSON_PATH" | xargs echo)
if [ -n "$APT_PACKAGES_CMD" ]; then echo "APT packages: $APT_PACKAGES_CMD"; $SUDO apt-get install -y $APT_PACKAGES_CMD || exit_with_error "Failed to install APT packages: $APT_PACKAGES_CMD"; else echo "No App APT packages."; fi

# --- Node.js Application Build ---
NPM_APP_DIR="$PIFIRE_INSTALL_DIR/pifire.app"
if [ -d "$NPM_APP_DIR" ] && [ -f "$NPM_APP_DIR/package.json" ]; then
    echo "Building Node.js app (pifire.app)..."; cd "$NPM_APP_DIR" || exit_with_error "Could not cd to $NPM_APP_DIR"
    echo "Running 'npm install'..."; if $SUDO npm install; then echo "npm install done. Running 'npm run build'..."; if ! $SUDO npm run build; then exit_with_error "'npm run build' failed."; fi
    else exit_with_error "'npm install' failed."; fi; cd "$PIFIRE_INSTALL_DIR"
else echo "Skipping npm build for pifire.app."; fi

# --- Python Virtual Environment and Dependencies ---
clear; echo "Setting up Python Virtual Environment & Installing Modules"
cd "$PIFIRE_INSTALL_DIR" || exit_with_error "Failed to cd to $PIFIRE_INSTALL_DIR for VENV."

echo "Setting ownership of $PIFIRE_INSTALL_DIR to '$EFFECTIVE_USER_NAME' prior to venv creation..."
$SUDO chown -R "$EFFECTIVE_USER_NAME:$EFFECTIVE_USER_NAME" "$PIFIRE_INSTALL_DIR" || exit_with_error "chown $PIFIRE_INSTALL_DIR to $EFFECTIVE_USER_NAME failed. User '$EFFECTIVE_USER_NAME' might be invalid for chown despite 'id' check. Check sudo logs."

echo "Creating Python .venv as user '$EFFECTIVE_USER_NAME' using system '/usr/local/bin/uv'..."
if ! $SUDO -u "$EFFECTIVE_USER_NAME" /usr/local/bin/uv venv --python python3 --system-site-packages .venv; then
    exit_with_error "Failed to create .venv using 'uv venv' as '$EFFECTIVE_USER_NAME'.\nThis is after the 'sudo -u $EFFECTIVE_USER_NAME true' test passed.\nThis suggests a more complex issue with 'sudo -u' for this specific command or user, possibly related to 'uv' execution or the persistent 'sudoers_audit' errors. Please check system 'sudo' logs carefully."
fi
if [ ! -d "$PIFIRE_INSTALL_DIR/.venv/bin" ]; then exit_with_error ".venv/bin not found after 'uv venv'. Creation failed."; fi
echo "Virtual environment created at $PIFIRE_INSTALL_DIR/.venv"

SYSTEM_UV_AS_USER_CMD_PREFIX="$SUDO -u \"$EFFECTIVE_USER_NAME\" /usr/local/bin/uv"

PIP_PACKAGES_JSON_CMD=$(jq -r '.pip[]? | select(.!=null and .!="") | @sh' "$FULL_PACKAGE_JSON_PATH" | xargs echo)
if [ -n "$PIP_PACKAGES_JSON_CMD" ]; then
    echo "Installing pip packages from package.json via uv: $PIP_PACKAGES_JSON_CMD"
    # shellcheck disable=SC2086
    if ! $SYSTEM_UV_AS_USER_CMD_PREFIX pip install $PIP_PACKAGES_JSON_CMD; then
         exit_with_error "Failed to install pip packages from package.json using '$SYSTEM_UV_AS_USER_CMD_PREFIX pip install ...'.\nCheck for 'sudo' errors (like 'sudoers_audit' or 'unknown user') or if '/usr/local/bin/uv' can be executed correctly by '$EFFECTIVE_USER_NAME' via 'sudo -u'."
    fi
else echo "No pip packages in package.json for venv."; fi

VENV_PYTHON_PATH="$PIFIRE_INSTALL_DIR/.venv/bin/python"
if $SUDO -u "$EFFECTIVE_USER_NAME" $VENV_PYTHON_PATH -c "import sys; sys.exit(0 if sys.version_info[:2] >= (3,11) else 1)"; then
    echo "Venv Python >= 3.11. Installing latest eventlet via uv."
    if ! $SYSTEM_UV_AS_USER_CMD_PREFIX pip install eventlet; then exit_with_error "Failed to install latest eventlet."; fi
else
    echo "Venv Python < 3.11. Installing eventlet==0.30.2 via uv."
    if ! $SYSTEM_UV_AS_USER_CMD_PREFIX pip install 'eventlet==0.30.2'; then exit_with_error "Failed to install eventlet==0.30.2."; fi
fi

REQUIREMENTS_TXT_PATH="$PIFIRE_INSTALL_DIR/auto-install/requirements.txt"
if [ -f "$REQUIREMENTS_TXT_PATH" ]; then
    echo "Installing from $REQUIREMENTS_TXT_PATH via uv..."
    if ! $SYSTEM_UV_AS_USER_CMD_PREFIX pip install -r "$REQUIREMENTS_TXT_PATH"; then exit_with_error "Failed install from requirements.txt."; fi
else echo "Warning: requirements.txt not found."; fi

# --- Permissions, Group, and Bluepy ---
echo "Setting up 'pifire' group and final permissions..."
if ! getent group pifire > /dev/null; then $SUDO groupadd pifire || echo "Warning: Failed add group 'pifire'."; fi
$SUDO usermod -a -G pifire "$EFFECTIVE_USER_NAME" || echo "Warning: Failed add $EFFECTIVE_USER_NAME to pifire group."
$SUDO chown -R "$EFFECTIVE_USER_NAME:pifire" "$PIFIRE_INSTALL_DIR"
$SUDO find "$PIFIRE_INSTALL_DIR" -type d -exec chmod 2775 {} \;
$SUDO find "$PIFIRE_INSTALL_DIR" -type f -exec chmod 0664 {} \;
if [ -f "$VENV_PYTHON_PATH" ]; then $SUDO chmod u+x "$VENV_PYTHON_PATH"; fi
BLUEPY_HELPERS=$($SUDO find "$PIFIRE_INSTALL_DIR/.venv/lib/" -name "bluepy-helper" -type f 2>/dev/null)
if [ -n "$BLUEPY_HELPERS" ]; then for helper in $BLUEPY_HELPERS; do echo "Caps for $helper"; $SUDO setcap 'cap_net_raw,cap_net_admin+eip' "$helper" && $SUDO getcap "$helper"; done
else echo "Warning: bluepy-helper not found."; fi
UPDATER_PY_PATH="$PIFIRE_INSTALL_DIR/updater.py"
if [ -f "$VENV_PYTHON_PATH" ] && [ -f "$UPDATER_PY_PATH" ]; then echo "Running updater.py -p..."; if ! $SUDO -u "$EFFECTIVE_USER_NAME" "$VENV_PYTHON_PATH" "$UPDATER_PY_PATH" -p; then echo "Warning: 'updater.py -p' failed."; fi
else echo "Warning: $VENV_PYTHON_PATH or $UPDATER_PY_PATH not found; skipping PIP list gen."; fi

# --- Nginx Setup ---
NGINX_CONFIG_DIR="$PIFIRE_INSTALL_DIR/auto-install/nginx"
if [ -d "$NGINX_CONFIG_DIR" ]; then clear; echo "Configuring nginx..."; cd "$NGINX_CONFIG_DIR" || exit_with_error "Failed cd $NGINX_CONFIG_DIR"
    if [ -f "/etc/nginx/sites-enabled/default" ] || [ -L "/etc/nginx/sites-enabled/default" ]; then $SUDO rm -f /etc/nginx/sites-enabled/default; fi
    $SUDO cp pifire.nginx /etc/nginx/sites-available/pifire || exit_with_error "Failed copy nginx conf."
    if [ ! -L "/etc/nginx/sites-enabled/pifire" ]; then $SUDO ln -sf /etc/nginx/sites-available/pifire /etc/nginx/sites-enabled/pifire || exit_with_error "Failed nginx symlink."; fi
    $SUDO cp server_error.html /usr/share/nginx/html/ || exit_with_error "Failed copy server_error.html."
    echo "Restarting nginx..."; $SUDO nginx -t && $SUDO systemctl restart nginx || exit_with_error "Nginx test/restart failed."
else echo "Warning: Nginx conf dir '$NGINX_CONFIG_DIR' not found."; fi

# --- Supervisor Setup ---
SUPERVISOR_CONFIG_DIR="$PIFIRE_INSTALL_DIR/auto-install/supervisor"
if [ -d "$SUPERVISOR_CONFIG_DIR" ]; then clear; echo "Configuring Supervisord..."; cd "$SUPERVISOR_CONFIG_DIR" || exit_with_error "Failed cd $SUPERVISOR_CONFIG_DIR"
    for conf_t in control.conf webapp.conf pifireapp.conf; do if [ -f "$conf_t" ]; then
            TEMP_CONF=$(mktemp); cp "$conf_t" "$TEMP_CONF"; sed -i '/^user=/d' "$TEMP_CONF"; echo "user=$EFFECTIVE_USER_NAME" >> "$TEMP_CONF"
            ESCAPED_INSTALL_DIR=$(echo "$PIFIRE_INSTALL_DIR" | sed 's/\//\\\//g'); ESCAPED_VENV_PYTHON=$(echo "$VENV_PYTHON_PATH" | sed 's/\//\\\//g')
            sed -i "s#%%PIFIRE_INSTALL_DIR%%#$ESCAPED_INSTALL_DIR#g" "$TEMP_CONF"; sed -i "s#%%VENV_PYTHON%%#$ESCAPED_VENV_PYTHON#g" "$TEMP_CONF"
            $SUDO cp "$TEMP_CONF" "/etc/supervisor/conf.d/$(basename "$conf_t")" || exit_with_error "Failed copy $conf_t."
            rm "$TEMP_CONF"; echo "Configured $(basename "$conf_t")."
        else echo "Warning: Supervisor template '$conf_t' not found."; fi; done
    if whiptail --yesno "Enable Supervisor WebUI (port 9001)?" ${r} ${c}; then if ! grep -q "\[inet_http_server\]" /etc/supervisor/supervisord.conf; then
            SVISOR_USER=$(whiptail --inputbox "Supervisor WebUI User [pifireuser]:" 8 78 "pifireuser" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ] && [ -n "$SVISOR_USER" ]; then SVISOR_PASS=$(whiptail --passwordbox "Pass for '$SVISOR_USER':" 8 78 3>&1 1>&2 2>&3)
                if [ $? -eq 0 ] && [ -n "$SVISOR_PASS" ]; then echo -e "\n[inet_http_server]\nport=0.0.0.0:9001\nusername=$SVISOR_USER\npassword=$SVISOR_PASS" | $SUDO tee -a /etc/supervisor/supervisord.conf >/dev/null; whiptail --msgbox "Supervisor WebUI enabled." ${r} ${c}
                else whiptail --msgbox "WebUI pass not set." ${r} ${c}; fi
            else whiptail --msgbox "WebUI user not set." ${r} ${c}; fi
        else whiptail --msgbox "WebUI already configured." ${r} ${c}; fi; fi
    echo "Reloading supervisor..."; $SUDO supervisorctl reread; $SUDO supervisorctl update
    if ! $SUDO systemctl is-active --quiet supervisor; then $SUDO systemctl start supervisor; $SUDO systemctl enable supervisor; else $SUDO systemctl restart supervisor; fi
    $SUDO systemctl status supervisor --no-pager
else echo "Warning: Supervisor config dir '$SUPERVISOR_CONFIG_DIR' not found."; fi

# --- Final Instructions & Reboot ---
clear
if whiptail --title "Installation Complete" --yesno "PiFire installation complete!\nReboot recommended.\nReboot now?" $(($r+2)) $c; then echo "Rebooting..."; $SUDO reboot
else echo "Installation complete. Please reboot manually."; fi
exit 0