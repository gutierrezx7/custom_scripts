#!/usr/bin/env bash

# Webmin Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting Webmin Installation...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Updating package lists...${NC}"
apt-get update

echo -e "${YELLOW}Installing prerequisites...${NC}"
apt-get install -y wget apt-transport-https software-properties-common gnupg2

echo -e "${YELLOW}Adding Webmin repository key...${NC}"
# Replaced deprecated apt-key with signed-by approach
wget -qO - http://www.webmin.com/jcameron-key.asc | gpg --dearmor -o /usr/share/keyrings/webmin.gpg

echo -e "${YELLOW}Adding Webmin repository...${NC}"
sh -c 'echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list'

echo -e "${YELLOW}Updating package lists again...${NC}"
apt-get update

echo -e "${YELLOW}Installing Webmin...${NC}"
apt-get install -y webmin

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Webmin installed successfully!${NC}"
    echo -e "Access it at https://$(hostname -I | awk '{print $1}'):10000"
else
    echo -e "${RED}Webmin installation failed.${NC}"
    exit 1
fi
