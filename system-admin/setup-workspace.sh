#!/usr/bin/env bash
# Title: Configurar Workspace
# Description: Cria a estrutura de pastas /opt/stack
# Supported: VM, LXC
# Author: Custom Scripts Team

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO] Por favor, execute como root.${NC}"
    exit 1
fi

TARGET_DIR="/opt/stack"

if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    msg_info "Diretório criado: $TARGET_DIR"
    chmod 755 "$TARGET_DIR"
else
    msg_info "Diretório já existe: $TARGET_DIR"
fi
