#!/usr/bin/env bash

# Automatic Installation Script for WSL
# Adapted from the PiFire project (pivpn.io)
# Run from https://raw.githubusercontent.com/nebhead/pifire/master/auto-install/install.sh
#
# Install with this command (from your WSL terminal):
#
# curl https://raw.githubusercontent.com/nebhead/pifire/master/auto-install/install.sh | bash
#
# NOTE: This installer is intended to be run on a fresh WSL installation.

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
whiptail --msgbox --backtitle "Welcome" --title "PiFire Automated Installer for WSL" "This installer will set up the PiFire environment for debugging purposes on WSL." ${r} ${c}

# Starting actual steps for installation
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
$SUDO apt install python3-dev python3-pip python3-venv python3-scipy nginx git supervisor redis-server gfortran libatlas-base-dev libopenblas-dev liblapack-dev libopenjp2-7 -y

# Grab project files
clear
echo "*************************************************************************"
echo "**                                                                     **"
echo "**      Cloning PiFire from GitHub...                                  **"
echo "**                                                                     **"
echo "*************************************************************************"
cd /usr/local/bin
# Use a shallow clone to reduce download size
$SUDO git clone --depth 1 --branch nh-release-dtfe https://github.com/dogtreatfairy/pifire

echo " - Setting Up PiFire Group"
cd /usr/local/bin
$SUDO groupadd pifire 
$SUDO usermod -a -G pifire ryan 
$SUDO usermod -a -G pifire root 
# Change ownership to ryan:pifire for all files/directories in pifire 
$SUDO chown -R ryan:pifire pifire 
# Change ability for pifire group to read/write/execute 
$SUDO chmod -R 775 pifire/

echo " - Setting up VENV"
# Setup VENV
python3 -m venv --system-site-packages pifire
cd /usr/local/bin/pifire
source bin/activate 

echo " - Installing module dependencies... "
# Install module dependencies 
python3 -m pip install "flask==2.3.3" 
python3 -m pip install flask-mobility
python3 -m pip install flask-qrcode
python3 -m pip install flask-socketio
if ! python3 -c "import sys; assert sys.version_info[:2] >= (3,11)" > /dev/null; then
    echo "System is running a python version lower than 3.11, installing eventlet==0.30.2";
    python3 -m pip install "eventlet==0.30.2"
else
    echo "System is running a python version 3.11 or greater, installing latest eventlet"
    python3 -m pip install eventlet
fi      
python3 -m pip install gunicorn
python3 -m pip install redis
python3 -m pip install uuid
python3 -m pip install influxdb-client[ciso]
python3 -m pip install apprise
python3 -m pip install scikit-fuzzy
python3 -m pip install "scikit-learn==1.4.2"
python3 -m pip install ratelimitingfilter
python3 -m pip install "pillow>=9.2.0"
python3 -m pip install paho-mqtt
python3 -m pip install psutil

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
echo "user=ryan" | tee -a control.conf > /dev/null
echo "user=ryan" | tee -a webapp.conf > /dev/null

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

# Ask for the location of the development folder on the Windows C drive
DEV_FOLDER=$(whiptail --inputbox "Enter the location of the development folder on your Windows C drive [default: /mnt/c/Users/ryans/OneDrive/Documents/GitHub/pifire]" 10 78 "/mnt/c/Users/ryans/OneDrive/Documents/GitHub/pifire" --title "Development Folder Location" 3>&1 1>&2 2>&3)

# Correct the path if necessary
if [[ $DEV_FOLDER == Users* || $DEV_FOLDER == /Users* ]]; then
    DEV_FOLDER="/mnt/c/$DEV_FOLDER"
elif [[ $DEV_FOLDER == C:/ || $DEV_FOLDER == C:\\ ]]; then
    DEV_FOLDER="/mnt/c/${DEV_FOLDER:3}"
fi

# Remove existing pifire() function if it exists
sed -i '/^pifire() {/,/^}/d' ~/.bashrc

# Add custom command to .bashrc
echo '# Custom command to activate venv, wait, and run control.py' >> ~/.bashrc
echo 'pifire() {' >> ~/.bashrc
echo '    if [ "$1" == "--install" ]; then' >> ~/.bashrc
echo "        cd \"$DEV_FOLDER/auto-install\"" >> ~/.bashrc
echo '        bash wslinstall.sh' >> ~/.bashrc
echo '    elif [ "$1" == "--update" ]; then' >> ~/.bashrc
echo "        rsync -avz $DEV_FOLDER/ /usr/local/bin/pifire/" >> ~/.bashrc
echo '        clear' >> ~/.bashrc
echo '        echo ""' >> ~/.bashrc
echo '        echo -e "\e[1;32mUpdate Completed\e[0m"' >> ~/.bashrc
echo '        echo ""' >> ~/.bashrc
echo '    elif [ "$1" == "--help" ]; then' >> ~/.bashrc
echo '        echo ""' >> ~/.bashrc
echo '        echo "----HELP MENU----"' >> ~/.bashrc
echo '        echo ""' >> ~/.bashrc
echo '        echo "--install   Install or Reinstall Pifire"' >> ~/.bashrc
echo '        echo "--update    Update current PiFire install to mirror Git Development on C Drive"' >> ~/.bashrc
echo '        echo "--help      Show this help menu"' >> ~/.bashrc
echo '        echo ""' >> ~/.bashrc
echo '    else' >> ~/.bashrc
echo '        echo -e "\e[1;32mStarting\e[0m - PiFire at 127.0.0.1:80..."' >> ~/.bashrc
echo '        cd /usr/local/bin/pifire' >> ~/.bashrc
echo '        source bin/activate' >> ~/.bashrc
echo '        sleep 2' >> ~/.bashrc
echo '        python3 control.py' >> ~/.bashrc
echo '    fi' >> ~/.bashrc
echo '}' >> ~/.bashrc

# Source the updated .bashrc
source ~/.bashrc

clear

# Restart WSL
echo "Installation complete. You can now run 'pifire' to execute control.py. --install will run wslinstall.sh from the Dev Folder, and --update will update from the Dev Folder"
