#!/usr/bin/env bash

# AdGuard Home Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting AdGuard Home Installation...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Installing dependencies (curl, tar)...${NC}"
apt-get update
apt-get install -y curl tar

echo -e "${YELLOW}Downloading and running official install script...${NC}"
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

if [ $? -eq 0 ]; then
    echo -e "${GREEN}AdGuard Home installed successfully!${NC}"
    echo -e "Access the setup interface at http://$(hostname -I | awk '{print $1}'):3000"
else
    echo -e "${RED}AdGuard Home installation failed.${NC}"
    exit 1
fi
