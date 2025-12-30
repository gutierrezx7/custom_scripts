#!/usr/bin/env bash

# Docker Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting Docker Installation...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Updating system...${NC}"
apt-get update

echo -e "${YELLOW}Installing prerequisites...${NC}"
apt-get install -y ca-certificates curl gnupg

echo -e "${YELLOW}Adding Docker GPG key...${NC}"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo -e "${YELLOW}Adding Docker repository...${NC}"
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

echo -e "${YELLOW}Installing Docker Engine...${NC}"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo -e "${YELLOW}Verifying Docker installation...${NC}"
docker --version

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Docker installed successfully!${NC}"
    echo -e "${YELLOW}Note: Ensure 'Nesting' and 'keyctl' features are enabled in Proxmox LXC Options.${NC}"
else
    echo -e "${RED}Docker installation failed.${NC}"
    exit 1
fi
