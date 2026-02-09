#!/usr/bin/env bash
# Title: Configurar Firewall (UFW)
# Description: Instala e configura regras padrão do UFW
# Supported: VM
# Interactive: yes
# Reboot: no
# Network: risk
# Author: Custom Scripts Team

RED='\033[0;31m'
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO] Por favor, execute como root.${NC}"
    exit 1
fi

msg_info "Configurando Firewall (UFW)..."

if ! command -v ufw >/dev/null; then
    apt-get install -y ufw
fi

msg_info "Definindo políticas padrão..."
ufw default deny incoming
ufw default allow outgoing

msg_info "Liberando porta 22 (SSH)..."
ufw allow 22/tcp

msg_info "Liberando portas HTTP/HTTPS (80/443)..."
ufw allow 80/tcp
ufw allow 443/tcp

msg_info "Liberando porta 8000 (Supabase/API)..."
ufw allow 8000/tcp

msg_info "Liberando porta 5678 (n8n Workflow)..."
ufw allow 5678/tcp

read -p "Deseja ativar o firewall agora? (s/n): " ENABLE_UFW
if [[ "$ENABLE_UFW" =~ ^[Ss]$ ]]; then
    echo "y" | ufw enable
    msg_info "Firewall ativado."
fi
