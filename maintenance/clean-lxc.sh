#!/usr/bin/env bash

# Title: Limpeza de LXC
# Description: Script de limpeza para containers LXC (cache, logs)
# Supported: LXC
# Interactive: no
# Reboot: no
# Network: safe
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting System Cleanup...${NC}"

# Check if running as root
# Interactive: no
# Reboot: no
# Network: safe
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Cleaning apt cache...${NC}"
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

echo -e "${YELLOW}Cleaning journal logs (keeping last 2 days)...${NC}"
journalctl --vacuum-time=2d

echo -e "${YELLOW}Cleaning old log files in /var/log...${NC}"
find /var/log -type f -name "*.gz" -delete
find /var/log -type f -name "*.1" -delete

echo -e "${GREEN}Cleanup complete!${NC}"
