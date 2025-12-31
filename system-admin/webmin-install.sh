#!/usr/bin/env bash
# Title: Instalar Webmin
# Description: Interface web para administração de sistemas
# Supported: VM, LXC
# Interactive: no
# Reboot: no
# Network: safe
# Author: Custom Scripts Team

# Webmin Installer for Proxmox LXC (Debian/Ubuntu)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Iniciando Instalação do Webmin...${NC}"

# Verificar root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Por favor, execute como root.${NC}"
  exit 1
fi

echo -e "${YELLOW}Atualizando listas de pacotes...${NC}"
apt-get update

echo -e "${YELLOW}Instalando pré-requisitos...${NC}"
apt-get install -y curl gnupg2

echo -e "${YELLOW}Configurando repositório Webmin (via script oficial)...${NC}"
# Utiliza o script oficial do Webmin para configurar repositórios e chaves corretamente
# Isso resolve problemas com chaves DSA antigas no Ubuntu 24.04+
curl -fsSL https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh | sh -s -- --force

if [ $? -ne 0 ]; then
    echo -e "${RED}Falha na configuração do repositório Webmin.${NC}"
    exit 1
fi

echo -e "${YELLOW}Instalando Webmin...${NC}"
apt-get update
apt-get install -y webmin

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Webmin instalado com sucesso!${NC}"
    echo -e "Acesse em https://$(hostname -I | awk '{print $1}'):10000"
else
    echo -e "${RED}Falha na instalação do Webmin.${NC}"
    exit 1
fi
