#!/usr/bin/env bash
# Title: Instalar Tailscale
# Description: VPN Mesh segura e fácil de configurar
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

msg_info "Instalando Tailscale (Script Oficial)..."
curl -fsSL https://tailscale.com/install.sh | sh

if command -v tailscale >/dev/null; then
    msg_info "Tailscale instalado com sucesso!"
    msg_warn "Você precisa autenticar este dispositivo."
    read -p "Deseja iniciar a autenticação agora? (s/n): " AUTH
    if [[ "$AUTH" =~ ^[Ss]$ ]]; then
        tailscale up
    else
        msg_info "Para autenticar depois, execute: 'tailscale up'"
    fi
else
    echo -e "${RED}[ERRO] Instalação do Tailscale falhou.${NC}"
    exit 1
fi
