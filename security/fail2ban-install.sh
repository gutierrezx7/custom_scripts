#!/usr/bin/env bash
# Title: Instalar Fail2Ban
# Description: Proteção contra força bruta (SSH e outros serviços)
# Supported: VM, LXC
# Interactive: no
# Reboot: no
# Network: safe
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

msg_info "Instalando Fail2Ban..."
apt-get update -qq
apt-get install -y fail2ban -qq

msg_info "Configurando Jail padrão (SSH)..."
# Criar cópia segura do arquivo de configuração
if [ ! -f /etc/fail2ban/jail.local ]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi

# Configuração básica para SSH
cat > /etc/fail2ban/jail.d/defaults-debian.conf <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

msg_info "Reiniciando serviço Fail2Ban..."
systemctl restart fail2ban
systemctl enable fail2ban

if systemctl is-active --quiet fail2ban; then
    msg_info "Fail2Ban instalado e ativo!"
    msg_info "Status atual:"
    fail2ban-client status sshd
else
    echo -e "${RED}[ERRO] Falha ao iniciar Fail2Ban.${NC}"
    exit 1
fi
