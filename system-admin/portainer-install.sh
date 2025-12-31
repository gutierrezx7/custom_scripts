#!/usr/bin/env bash

# Portainer Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Iniciando Instalação do Portainer...${NC}"

# Verificar root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Por favor, execute como root.${NC}"
  exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker não está instalado. Por favor, instale o Docker primeiro (docker/docker-install.sh).${NC}"
    exit 1
fi

echo -e "${YELLOW}Criando Volume do Portainer...${NC}"
docker volume create portainer_data

echo -e "${YELLOW}Implantando Container do Portainer...${NC}"
docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Portainer instalado com sucesso!${NC}"
    echo -e "Acesse em https://$(hostname -I | awk '{print $1}'):9443"
else
    echo -e "${RED}Falha na instalação do Portainer.${NC}"
    exit 1
fi
