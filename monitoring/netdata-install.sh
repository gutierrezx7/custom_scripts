#!/usr/bin/env bash

# NetData Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting NetData Installation...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Downloading and running official kickstart script...${NC}"
# Using --non-interactive to automate install
# Interactive: no
# Reboot: no
# Network: safe
wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh --non-interactive

if [ $? -eq 0 ]; then
    echo -e "${GREEN}NetData installed successfully!${NC}"
    echo -e "Access it at http://$(hostname -I | awk '{print $1}'):19999"
else
    echo -e "${RED}NetData installation failed.${NC}"
    exit 1
fi
