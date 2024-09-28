#!/bin/bash

# Use command-line prompts to gather user input
read -p "Enter the SMB server IP or hostname (e.g., 192.168.1.105): " SMB_SERVER_IP
read -p "Enter the SMB share name (e.g., WOKHOME): " SMB_SHARE
read -p "Enter the mount point path (default: /mnt/smbshare): " MOUNT_POINT
read -p "Enter the username to access the SMB share (default: root): " SMB_USERNAME
read -s -p "Enter the password for the SMB share: " SMB_PASSWORD
echo
read -p "Enter the SMB version to use (default is 3.0): " SMB_VERSION

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
echo "Installing cifs-utils..."
sudo apt update && sudo apt install -y cifs-utils

# Step 2: Create mount point
echo "Creating mount point at $MOUNT_POINT..."
sudo mkdir -p $MOUNT_POINT

# Step 3: Create credentials file
echo "Creating credentials file at $CREDENTIALS_FILE..."
sudo bash -c "cat <<EOL > $CREDENTIALS_FILE
username=$SMB_USERNAME
password=$SMB_PASSWORD
EOL"

# Secure the credentials file
sudo chmod 600 $CREDENTIALS_FILE

# Step 4: Create systemd mount unit
echo "Creating systemd mount unit at $UNIT_FILE..."
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
echo "Reloading systemd daemon and starting mount unit..."
sudo systemctl daemon-reload
sudo systemctl enable $(echo $MOUNT_POINT | sed 's/\//-/g').mount
sudo systemctl start $(echo $MOUNT_POINT | sed 's/\//-/g').mount

# Step 6: Enable systemd-networkd-wait-online for network readiness
echo "Enabling systemd-networkd-wait-online.service..."
sudo systemctl enable systemd-networkd-wait-online.service
sudo systemctl start systemd-networkd-wait-online.service

echo "SMB share mounted and set to persist after reboot."
