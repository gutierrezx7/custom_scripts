#!/usr/bin/env bash

# TacticalRMM Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3
# This script wraps the official TacticalRMM installer and patches it to bypass LXC detection.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting TacticalRMM Installation Wrapper...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Installing prerequisites for download...${NC}"
apt-get update
apt-get install -y wget ca-certificates

echo -e "${YELLOW}Downloading official install script...${NC}"
wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/install.sh -O tactical_install.sh

if [ ! -f tactical_install.sh ]; then
    echo -e "${RED}Failed to download install script.${NC}"
    exit 1
fi

echo -e "${YELLOW}Patching script to bypass LXC detection...${NC}"
# Mock systemd-detect-virt to return 'kvm' instead of 'lxc'
# This is safer than deleting lines as it won't break if the upstream script structure changes.
sed -i 's/systemd-detect-virt/echo kvm/g' tactical_install.sh

# Make executable
chmod +x tactical_install.sh

echo -e "${GREEN}Starting patched installer...${NC}"
echo -e "${YELLOW}WARNING: You are installing TacticalRMM in an LXC container. This is officially unsupported.${NC}"
echo -e "${YELLOW}Make sure you have at least 4GB RAM assigned to this container.${NC}"
echo -e "${YELLOW}Press ENTER to continue or Ctrl+C to cancel.${NC}"
read -r

./tactical_install.sh

# Cleanup
# rm tactical_install.sh
# Interactive: yes
# Reboot: no
# Network: safe
