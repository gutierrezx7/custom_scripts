#!/usr/bin/env bash
# Title: Preparação do Sistema
# Description: Atualiza pacotes, define Hostname e instala ferramentas básicas
# Supported: VM, LXC
# Author: Custom Scripts Team

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO] Por favor, execute como root.${NC}"
    exit 1
fi

msg_info "Iniciando Preparação do Sistema..."

msg_info "Atualizando listas de pacotes e sistema..."
apt-get update && apt-get upgrade -y

# Hostname
CURRENT_HOSTNAME=$(hostname)
read -p "Digite o novo Hostname [$CURRENT_HOSTNAME]: " NEW_HOSTNAME
NEW_HOSTNAME=${NEW_HOSTNAME:-$CURRENT_HOSTNAME}

if [ "$NEW_HOSTNAME" != "$CURRENT_HOSTNAME" ]; then
    hostnamectl set-hostname "$NEW_HOSTNAME"
    # Atualizar hosts para evitar warning do sudo
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    msg_info "Hostname alterado para $NEW_HOSTNAME"
fi

# Ferramentas Básicas
TOOLS="curl wget git htop unzip nano"
msg_info "Instalando ferramentas essenciais: $TOOLS"
apt-get install -y $TOOLS

msg_info "Preparação do Sistema concluída!"
