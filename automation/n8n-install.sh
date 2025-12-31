#!/usr/bin/env bash

# N8N Installer (NPM Method) for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting N8N Installation (NPM Method)...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Updating system...${NC}"
apt-get update && apt-get upgrade -y

echo -e "${YELLOW}Installing dependencies (build-essential, python3)...${NC}"
apt-get install -y build-essential python3 curl

echo -e "${YELLOW}Installing Node.js (v20 LTS)...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo -e "${YELLOW}Installing N8N globally via NPM...${NC}"
npm install n8n -g

echo -e "${YELLOW}Creating Systemd Service for N8N...${NC}"
# Determine user to run N8N (recommend a non-root user, but for simple LXC scripts root is common or create one)
# We'll create a user 'n8n'
if ! id -u n8n > /dev/null 2>&1; then
    useradd -m -s /bin/bash n8n
fi

SERVICE_FILE="/etc/systemd/system/n8n.service"
cat <<EOF > $SERVICE_FILE
[Unit]
Description=n8n - Workflow Automation Tool
Documentation=https://docs.n8n.io
After=network.target

[Service]
Type=simple
User=n8n
ExecStart=/usr/bin/n8n
Restart=on-failure
Environment="N8N_PORT=5678"
Environment="N8N_LISTEN_ADDRESS=0.0.0.0"
# Environment="WEBHOOK_URL=https://n8n.example.com"

[Install]
WantedBy=multi-user.target
EOF

echo -e "${YELLOW}Enabling and starting N8N service...${NC}"
systemctl daemon-reload
systemctl enable n8n
systemctl start n8n

if systemctl is-active --quiet n8n; then
    echo -e "${GREEN}N8N installed and running!${NC}"
    echo -e "Access it at http://$(hostname -I | awk '{print $1}'):5678"
else
    echo -e "${RED}N8N service failed to start. Check logs with 'journalctl -u n8n'.${NC}"
    exit 1
fi
