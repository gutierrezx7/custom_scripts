#!/usr/bin/env bash
# Title: Nginx Proxy Manager
# Description: Instala NPM via Docker Compose (Portas 80, 81, 443)
# Supported: VM, LXC
# Interactive: no
# Reboot: no
# Network: safe
# Author: Custom Scripts Team

RED='\033[0;31m'
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
msg_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    msg_error "Por favor, execute como root."
    exit 1
fi

# Verificar Docker
if ! command -v docker >/dev/null; then
    msg_error "Docker não encontrado. Por favor, instale o Docker primeiro."
    exit 1
fi

INSTALL_DIR="/opt/npm"

if [ ! -d "$INSTALL_DIR" ]; then
    msg_info "Criando diretório $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
fi

msg_info "Criando docker-compose.yml..."
cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF

msg_info "Iniciando Nginx Proxy Manager..."
cd "$INSTALL_DIR" || exit 1
docker compose up -d

if [ $? -eq 0 ]; then
    msg_info "Nginx Proxy Manager iniciado!"
    msg_info "Acesse a interface Admin: http://$(hostname -I | awk '{print $1}'):81"
    msg_info "Login Padrão: admin@example.com / changeme"
else
    msg_error "Falha ao iniciar o container."
    exit 1
fi
