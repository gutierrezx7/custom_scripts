#!/usr/bin/env bash

# AdGuard Home Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Iniciando Instalação do AdGuard Home...${NC}"

# Verificar root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Por favor, execute como root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Instalando dependências (curl, tar)...${NC}"
apt-get update
apt-get install -y curl tar

echo -e "${YELLOW}Baixando e executando script de instalação oficial...${NC}"
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

if [ $? -eq 0 ]; then
    echo -e "${GREEN}AdGuard Home instalado com sucesso!${NC}"
    echo -e "Acesse a interface de configuração em http://$(hostname -I | awk '{print $1}'):3000"
else
    echo -e "${RED}Falha na instalação do AdGuard Home.${NC}"
    exit 1
fi
