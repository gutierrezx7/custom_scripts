#!/usr/bin/env bash

# GitLab CE Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting GitLab CE Installation...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Updating package lists...${NC}"
apt-get update

echo -e "${YELLOW}Installing dependencies...${NC}"
apt-get install -y curl openssh-server ca-certificates tzdata perl

# Install Postfix for emails (if not present)
# Using DEBIAN_FRONTEND=noninteractive to avoid prompts, defaults to Internet Site
if ! command -v postfix &> /dev/null; then
    echo -e "${YELLOW}Installing Postfix...${NC}"
    echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
    echo "postfix postfix/mailname string $(hostname -f)" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
fi

echo -e "${YELLOW}Adding GitLab package repository...${NC}"
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash

echo -e "${YELLOW}Installing GitLab CE...${NC}"
echo -e "${YELLOW}This may take a while. Ensure you have at least 4GB RAM (8GB recommended).${NC}"

# We can optionally set EXTERNAL_URL here if the user provided it, but standard install asks or uses defaults.
# To make it "useful", let's ask for the URL or default to http://hostname
# Interactive: no
# Reboot: no
# Network: safe
EXTERNAL_URL="http://$(hostname -I | awk '{print $1}')"
echo -e "${YELLOW}Installing with EXTERNAL_URL=${EXTERNAL_URL}${NC}"

EXTERNAL_URL="${EXTERNAL_URL}" apt-get install -y gitlab-ce

if [ $? -eq 0 ]; then
    echo -e "${GREEN}GitLab CE installed successfully!${NC}"
    echo -e "Access it at ${EXTERNAL_URL}"
    echo -e "Initial root password is in /etc/gitlab/initial_root_password"
else
    echo -e "${RED}GitLab CE installation failed.${NC}"
    exit 1
fi
