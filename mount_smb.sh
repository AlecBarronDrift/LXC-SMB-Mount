#!/bin/bash

# Check if Zenity is installed
if ! command -v zenity &> /dev/null
then
    ZENITY_INSTALLED_BEFORE=false
    echo "Installing Zenity for GUI prompts..."
    sudo apt update
    sudo apt install -y zenity
else
    ZENITY_INSTALLED_BEFORE=true
fi

# Use Zenity dialogs to prompt for user input
SMB_SERVER_IP=$(zenity --entry --title="SMB Server IP" --text="Enter the SMB server IP or hostname (e.g., 192.168.1.105):")
SMB_SHARE=$(zenity --entry --title="SMB Share" --text="Enter the SMB share name (e.g., WOKHOME):")
MOUNT_POINT=$(zenity --entry --title="Mount Point" --text="Enter the mount point path (default: /mnt/smbshare):" --entry-text="/mnt/smbshare")
SMB_USERNAME=$(zenity --entry --title="Username" --text="Enter the username to access the SMB share (this is the login you use to access the SMB drive, not the container, default: root):" --entry-text="root")
SMB_PASSWORD=$(zenity --password --title="Password" --text="Enter the password for the SMB share (this is the login you use to access the SMB drive, not the container):")
SMB_VERSION=$(zenity --entry --title="SMB Version" --text="Enter the SMB version to use (default is 3.0, press Enter to use default):" --entry-text="3.0")

# Default to /mnt/smbshare if no mount point is provided
MOUNT_POINT=${MOUNT_POINT:-/mnt/smbshare}
# Default to SMB version 3.0 if no input is provided
SMB_VERSION=${SMB_VERSION:-3.0}
# Default to root if no username is provided
SMB_USERNAME=${SMB_USERNAME:-root}

# Set the credentials file and mount unit paths
CREDENTIALS_FILE="/etc/smb-credentials"
UNIT_FILE="/etc/systemd/system/$(echo $MOUNT_POINT | sed 's/\//-/g').mount"

# Step 1: Install CIFS utils
zenity --info --title="Installing cifs-utils" --text="Installing cifs-utils package..."
sudo apt update && sudo apt install -y cifs-utils

# Step 2: Create mount point
zenity --info --title="Creating Mount Point" --text="Creating mount point at $MOUNT_POINT..."
sudo mkdir -p $MOUNT_POINT

# Step 3: Create credentials file
zenity --info --title="Creating Credentials File" --text="Creating credentials file at $CREDENTIALS_FILE..."
sudo bash -c "cat <<EOL > $CREDENTIALS_FILE
username=$SMB_USERNAME
password=$SMB_PASSWORD
EOL"

# Secure the credentials file
sudo chmod 600 $CREDENTIALS_FILE

# Step 4: Create systemd mount unit
zenity --info --title="Creating Mount Unit" --text="Creating systemd mount unit at $UNIT_FILE..."
sudo bash -c "cat <<EOL > $UNIT_FILE
[Unit]
Description=Mount SMB Share at $MOUNT_POINT
After=network-online.target
Wants=network-online.target

[Mount]
What=//$SMB_SERVER_IP/$SMB_SHARE
Where=$MOUNT_POINT
Type=cifs
Options=credentials=$CREDENTIALS_FILE,uid=1000,gid=1000,vers=$SMB_VERSION

[Install]
WantedBy=multi-user.target
EOL"

# Step 5: Enable and start systemd service
zenity --info --title="Reloading systemd" --text="Reloading systemd daemon and starting mount unit..."
sudo systemctl daemon-reload
sudo systemctl enable $(echo $MOUNT_POINT | sed 's/\//-/g').mount
sudo systemctl start $(echo $MOUNT_POINT | sed 's/\//-/g').mount

# Step 6: Enable systemd-networkd-wait-online for network readiness
zenity --info --title="Enabling Network Wait Service" --text="Enabling systemd-networkd-wait-online.service..."
sudo systemctl enable systemd-networkd-wait-online.service
sudo systemctl start systemd-networkd-wait-online.service

# Step 7: Remove Zenity if it wasn't installed before
if [ "$ZENITY_INSTALLED_BEFORE" = false ]; then
    sudo apt remove -y zenity
    echo "Zenity has been removed because it was not previously installed."
fi

zenity --info --title="Success" --text="SMB share mounted and set to persist after reboot."
