#!/usr/bin/env bash
# Title: Configurar IP Estático
# Description: Configuração interativa de rede via Netplan
# Supported: VM
# Interactive: yes
# Reboot: yes
# Network: risk
# Author: Custom Scripts Team

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
msg_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    msg_error "Por favor, execute como root."
    exit 1
fi

# Checar ambiente (Safety Check adicional)
if command -v systemd-detect-virt >/dev/null; then
    if [ "$(systemd-detect-virt)" == "lxc" ]; then
        msg_error "Este script não deve ser executado em containers LXC."
        exit 1
    fi
fi

msg_warn "ATENÇÃO: Alterar o IP via SSH pode desconectar sua sessão."

# Identificar interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
read -p "Interface de Rede detectada [$INTERFACE]: " INPUT_IF
INTERFACE=${INPUT_IF:-$INTERFACE}

read -p "Endereço IP desejado (ex: 192.168.1.50/24): " IP_ADDR
read -p "Gateway (ex: 192.168.1.1): " GATEWAY
read -p "DNS (ex: 8.8.8.8, 1.1.1.1): " DNS_SERVERS

if [[ -z "$IP_ADDR" || -z "$GATEWAY" || -z "$DNS_SERVERS" ]]; then
    msg_error "Dados incompletos. Cancelando."
    exit 1
fi

NETPLAN_FILE="/etc/netplan/99-custom.yaml"

cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $IP_ADDR
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVERS]
EOF

msg_info "Arquivo criado: $NETPLAN_FILE"
chmod 600 "$NETPLAN_FILE"

read -p "Deseja aplicar as configurações agora? Isso pode desconectar você. (s/n): " APPLY
if [[ "$APPLY" =~ ^[Ss]$ ]]; then
    msg_warn "Aplicando configurações em 5 segundos..."
    msg_warn "Se desconectar, reconecte-se no novo IP: ${IP_ADDR%/*}"
    sleep 5
    netplan apply
fi
