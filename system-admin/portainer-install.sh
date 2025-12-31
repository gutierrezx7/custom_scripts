#!/usr/bin/env bash

# Portainer Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting Portainer Installation...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first (docker/docker-install.sh).${NC}"
    exit 1
fi

echo -e "${YELLOW}Creating Portainer Volume...${NC}"
docker volume create portainer_data

echo -e "${YELLOW}Deploying Portainer Container...${NC}"
docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Portainer installed successfully!${NC}"
    echo -e "Access it at https://$(hostname -I | awk '{print $1}'):9443"
else
    echo -e "${RED}Portainer installation failed.${NC}"
    exit 1
fi
