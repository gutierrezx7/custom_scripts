#!/usr/bin/env bash

# Master Setup Script para LXC
# Part of Custom Scripts
# License: GPL v3

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

msg_title() { echo -e "${BLUE}=== $1 ===${NC}"; }
msg_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    msg_error "Por favor, execute como root."
    exit 1
fi

# Função para executar scripts
run_script() {
    SCRIPT_PATH="$1"
    if [ -f "$SCRIPT_PATH" ]; then
        bash "$SCRIPT_PATH"
    else
        echo -e "${YELLOW}Script local não encontrado. Baixando do GitHub...${NC}"
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/$SCRIPT_PATH)"
    fi
}

show_menu() {
    clear
    msg_title "Custom Scripts - Configuração de LXC"
    echo "1. Atualizar Sistema (system-admin/update-system.sh)"
    echo "2. Instalar Docker (docker/docker-install.sh)"
    echo "3. Instalar AdGuard Home (network/adguard-install.sh)"
    echo "4. Instalar Webmin (system-admin/webmin-install.sh)"
    echo "5. Instalar Portainer (system-admin/portainer-install.sh)"
    echo "0. Sair"
    echo
}

while true; do
    show_menu
    read -p "Escolha o que deseja instalar: " OPTION

    case $OPTION in
        1) run_script "system-admin/update-system.sh" ;;
        2) run_script "docker/docker-install.sh" ;;
        3) run_script "network/adguard-install.sh" ;;
        4) run_script "system-admin/webmin-install.sh" ;;
        5) run_script "system-admin/portainer-install.sh" ;;
        0) exit 0 ;;
        *) msg_error "Opção inválida!" ;;
    esac

    read -p "Pressione Enter para continuar..."
done
