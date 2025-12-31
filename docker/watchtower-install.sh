#!/usr/bin/env bash
# Title: Watchtower (Auto-Update)
# Description: Atualiza automaticamente containers Docker
# Supported: VM, LXC
# Interactive: no
# Reboot: no
# Network: safe
# Author: Custom Scripts Team

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
msg_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    msg_error "Por favor, execute como root."
    exit 1
fi

if ! command -v docker >/dev/null; then
    msg_error "Docker não encontrado."
    exit 1
fi

msg_info "Iniciando Watchtower..."
docker run -d \
    --name watchtower \
    --restart unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower --interval 86400

if [ $? -eq 0 ]; then
    msg_info "Watchtower instalado! Verificará atualizações a cada 24 horas."
else
    msg_error "Falha ao instalar Watchtower."
    exit 1
fi
