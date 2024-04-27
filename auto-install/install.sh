#!/usr/bin/env bash

# Automatic Installation Script
# Many thanks to the PiVPN project (pivpn.io) for much of the inspiration for this script
# Run from https://raw.githubusercontent.com/dogtreatfairy/pifire/development/auto-install/install.sh
#
# Install with this command (from your Pi):
#
# curl https://raw.githubusercontent.com/dogtreatfairy/pifire/development/auto-install/install.sh | bash
#
# NOTE: Pre-Requisites to run Raspi-Config first.  See README.md.

APT_PACKAGES=("python3-dev" "python3-pip" "python3-venv" "python3-rpi.gpio" "python3-scipy" "nginx" "git" "supervisor" "ttf-mscorefonts-installer" "redis-server" "libatlas-base-dev" "libopenjp2-7" "rpi-hardware-pwm")
GIT_REPO=("https://github.com/dogtreatfairy/pifire")
GIT_BRANCH=("development")

# Must be root to install
if [[ $EUID -eq 0 ]];then
    echo "You are root."
    echo ""
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
# Check if /usr/local/bin/pifire exists
if [ -d "/usr/local/bin/pifire" ]; then
    DESCRIPTION="This installer will transform your Single Board Computer into a connected Smoker Controller.  NOTE: This installer is intended to be run on a fresh install of Raspberry Pi OS Lite 32-Bit Bullseye or later."
    OPTION=$(whiptail --title "PiFire-DTFE (Dev) Installer" --menu "$DESCRIPTION\n\nChoose your option" 20 78 4 \
    "Re-Install" "Purge and re-install PiFire" \
    "Uninstall" "Remove PiFire" \
    "Exit" "Exit installer" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ "$OPTION" = "Exit" ]; then
            exit 0
        elif [ "$OPTION" = "Uninstall" ]; then
            # Ask if the user wants to keep user settings
            if (whiptail --title "Keep User Settings" --yesno "Do you want to save user settings?" 10 60) then
                sudo cp /usr/local/bin/pifire/settings.json /usr/local/bin/settings-bak.json
                echo ""
                echo -e "User Settings - \e[32mSAVED\e[0m"
                echo ""
            fi

            # Uninstall PYTHON_MODULES in the virtual environment
            cd /usr/local/bin/pifire || { echo "Failed to change directory"; exit 1; }
            source bin/activate || { echo "Failed to activate virtual environment"; exit 1; }
            pip freeze | xargs pip uninstall -y || { echo "Failed to uninstall pip packages"; exit 1; }
            deactivate || { echo "Failed to deactivate virtual environment"; exit 1; }
            cd / || { echo "Failed to change directory"; exit 1; }

            for pkg in "${APT_PACKAGES[@]}"; do
                sudo apt-get purge -y $pkg
                
            done

            sudo rm -rf /usr/local/bin/pifire

            # Ask if the user wants to remove Samba
            if (whiptail --title "Remove Samba" --yesno "Do you want to remove Samba?" 10 60) then
                sudo apt-get purge -y samba
            fi

            sudo apt autoremove -y
            sudo apt autoclean -y

            exit 0
        elif [ "$OPTION" = "Re-Install" ]; then
            # Ask if the user wants to keep user settings
            if (whiptail --title "Keep User Settings" --yesno "Do you want to keep user settings?" 10 60) then
                sudo cp /usr/local/bin/pifire/settings.json /usr/local/bin/settings-bak.json
                echo ""
                echo -e "User Settings - \e[32mSAVED\e[0m"
                echo ""                
            fi

            # Uninstall PYTHON_MODULES in the virtual environment
            cd /usr/local/bin/pifire || { echo "Failed to change directory"; exit 1; }
            source bin/activate || { echo "Failed to activate virtual environment"; exit 1; }
            pip freeze | xargs pip uninstall -y || { echo "Failed to uninstall pip packages"; exit 1; }
            deactivate || { echo "Failed to deactivate virtual environment"; exit 1; }
            cd / || { echo "Failed to change directory"; exit 1; }

            for pkg in "${APT_PACKAGES[@]}"; do
                sudo apt-get purge -y $pkg
            done

            sudo apt autoremove -y
            sudo apt autoclean -y

            sudo rm -rf /usr/local/bin/pifire

            # Ask if the user wants to remove Samba
            if (whiptail --title "Remove Samba" --yesno "Do you want to remove Samba?" 10 60) then
                sudo apt-get purge -y samba
            fi
        fi
    else
        DESCRIPTION="This installer will transform your Single Board Computer into a connected Smoker Controller.  NOTE: This installer is intended to be run on a fresh install of Raspberry Pi OS Lite 32-Bit Bullseye or later."
        OPTION=$(whiptail --title "PiFire-DTFE (Dev) Installer" --menu "$DESCRIPTION\n\nChoose your option" 20 78 2 \
        "Install" "Install PiFire" \
        "Exit" "Exit installer" 3>&1 1>&2 2>&3)
    fi
fi
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
for pkg in "${APT_PACKAGES[@]}"; do
    sudo apt install -y $pkg
done

# Grab project files
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Cloning PiFire from GitHub...                                  **"
echo "**                                                                     **"
echo "*************************************************************************"
cd /usr/local/bin
# Use a shallow clone to reduce download size
#$SUDO git clone --depth 1 https://github.com/dogtreatfairy/pifire
# Replace the below command to fetch development branch
$SUDO git clone --depth 1 --branch $GIT_BRANCH $GIT_REPO

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
python -m pip install "flask==2.3.3" 
python -m pip install flask-mobility
python -m pip install flask-qrcode
python -m pip install flask-socketio
if ! python -c "import sys; assert sys.version_info[:2] >= (3,11)" > /dev/null; then
    echo "System is running a python version lower than 3.11, installing eventlet==0.30.2";
    python -m pip install "eventlet==0.30.2"
else
    echo "System is running a python version 3.11 or greater, installing latest eventlet"
    python -m pip install eventlet
fi      
python -m pip install gunicorn
python -m pip install gpiozero
python -m pip install redis
python -m pip install uuid
python -m pip install influxdb-client[ciso]
python -m pip install apprise
python -m pip install scikit-fuzzy
python -m pip install scikit-learn
python -m pip install ratelimitingfilter
python -m pip install "pillow>=9.2.0"
python -m pip install paho-mqtt
python -m pip install psutil

# Setup config.txt to enable busses 
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Configuring config.txt                                         **"
echo "**                                                                     **"
echo "*************************************************************************"

# Enable SPI - Needed for some displays
echo "dtparam=spi=on" | $SUDO tee -a /boot/config.txt > /dev/null
# Enable I2C - Needed for some displays, ADCs, distance sensors
echo "dtparam=i2c_arm=on" | $SUDO tee -a /boot/config.txt > /dev/null
echo "i2c-dev" | $SUDO tee -a /etc/modules > /dev/null
# Enable Hardware PWM - Needed for hardware PWM support 
echo "dtoverlay=pwm,pin=13,func=4" | $SUDO tee -a /boot/config.txt > /dev/null

# Setup backlight / power permissions if a DSI screen is installed  
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Configuring Backlight UDEV Rules                               **"
echo "**                                                                     **"
echo "*************************************************************************"
echo 'SUBSYSTEM=="backlight",RUN+="/bin/chmod 666 /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power"' | $SUDO tee -a /etc/udev/rules.d/backlight-permissions.rules > /dev/null

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

clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Configuring SAMBA Share...                                     **"
echo "**                                                                     **"
echo "*************************************************************************"

SAMBA=$(whiptail --title "Install SAMBA Server?" --yesno "Do you want to install the SAMBA server and configure a share?" 8 78 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    sudo apt-get install -y samba

    # Create the directory if it doesn't exist
    sudo mkdir -p /usr/local/bin/pifire

    # Get list of users
    users=$(cut -d: -f1 /etc/passwd)

    # Convert users to array
    users_array=($users)

    # Create menu options
    menu_options=()
    for user in "${users_array[@]}"; do
        menu_options+=("$user" "")
    done

    # Prompt for Samba username
    smb_user=$(whiptail --title "User Selection" --menu "Select a user for the Samba share:" 20 78 10 "${menu_options[@]}" 3>&1 1>&2 2>&3)

    # Add the user to the Samba password database
    for i in {1..3}
    do
        sudo pdbedit -a -u $smb_user
        if [ $? -eq 0 ]; then
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done

    if [ $i -eq 3 ]; then
        echo "Failed to set Samba password after 3 attempts. Continuing without setting password."
    fi

    # Set up Samba configuration
    while true; do
        if echo "[pifire]" | sudo tee -a /etc/samba/smb.conf &&
           echo "comment = PiFire Share" | sudo tee -a /etc/samba/smb.conf &&
           echo "path = /usr/local/bin/pifire" | sudo tee -a /etc/samba/smb.conf &&
           echo "browsable = yes" | sudo tee -a /etc/samba/smb.conf &&
           echo "valid users = $smb_user" | sudo tee -a /etc/samba/smb.conf &&
           echo "read only = no" | sudo tee -a /etc/samba/smb.conf &&
           echo "create mask = 0664" | sudo tee -a /etc/samba/smb.conf &&
           echo "directory mask = 0775" | sudo tee -a /etc/samba/smb.conf; then
            break
        else
            echo "Failed to write to smb.conf. Try again? (y/n) "
            read choice
            case "$choice" in
                y|Y ) continue;;
                * ) echo "Continuing without updating smb.conf"; break;;
            esac
        fi
    done

    # Restart Samba services
    sudo systemctl restart smbd nmbd
fi

sleep 1


clear
# Rebooting

echo "Congratulations, the installation is complete.  At this time, we will perform a reboot and your application should be ready.  On first boot, the wizard will guide you through the remaining setup steps.  You should be able to access your application by opening a browser on your PC or other device and using the IP address (or http://[hostname].local) for this device.  Enjoy!"
echo ""

echo "Press any key to cancel."
echo "Rebooting in:"
for i in 5 4 3 2 1; do
    echo "$i..."
    read -r -s -n 1 -t 1 key
    if [ $? -eq 0 ]; then
        echo "Reboot cancelled"
        exit 0
    fi
done

$SUDO reboot
