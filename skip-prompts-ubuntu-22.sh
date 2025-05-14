#!/bin/bash

# Exit on any error
set -e

# Set non-interactive frontend for APT and debconf
export DEBIAN_FRONTEND=noninteractive
echo "Setting debconf to non-interactive mode..."
echo "SET debconf/frontend noninteractive" | sudo debconf-communicate

# Ensure needrestart is configured to avoid prompts at the start
echo "Disabling needrestart prompts..."
if [ -f /etc/needrestart/needrestart.conf ]; then
    sudo sed -i 's/#nrconf{restart} = .*/nrconf{restart} = '\''a'\'';/' /etc/needrestart/needrestart.conf
    sudo sed -i 's/#nrconf{kernelhints} = .*/nrconf{kernelhints} = -1;/' /etc/needrestart/needrestart.conf
else
    sudo apt install -y needrestart
    sudo bash -c 'echo "nrconf{restart} = '\''a'\'';" >> /etc/needrestart/needrestart.conf'
    sudo bash -c 'echo "nrconf{kernelhints} = -1;" >> /etc/needrestart/needrestart.conf'
fi

# Configure debconf to skip kernel upgrade prompts
echo "Configuring debconf for non-interactive kernel upgrades..."
echo "linux-base linux-base/removable-media-upgrade note" | sudo debconf-set-selections
echo "linux-image-$(uname -r) linux-image-$(uname -r)/prune-modules boolean true" | sudo debconf-set-selections

# Install and configure unattended-upgrades if not already installed
echo "Setting up unattended-upgrades..."
sudo apt install -y unattended-upgrades
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

# Configure unattended-upgrades to handle kernel upgrades
echo "Configuring unattended-upgrades for kernel packages..."
sudo bash -c 'cat << EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "Ubuntu:jammy-security";
};
Unattended-Upgrade::Package-Blacklist {
};
"linux-image-.*";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF'

# Run unattended-upgrades to apply kernel updates first
echo "Running unattended-upgrades to handle kernel updates..."
sudo unattended-upgrades --dry-run  # Check what will happen
sudo unattended-upgrades -v

# Update package lists
echo "Running apt update..."
sudo apt update -y

# Perform upgrade non-interactively
echo "Running apt upgrade..."
sudo apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Check if a reboot is required and handle it
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required due to kernel upgrade. Rebooting now..."
    sudo reboot
fi

echo "Non-interactive APT update and configuration completed successfully."