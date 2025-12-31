#!/bin/bash
# Title: Atualizar Sistema
# Description: Atualização segura do sistema (apt update/upgrade/clean)
# Supported: VM, LXC
# Author: Custom Scripts Team

#############################################################
# Nome do Script: update-system.sh
# Descrição: Script para atualização completa do sistema
# Autor: Custom Scripts Team
# Data: 22/12/2024
# Versão: 1.0
# Licença: GPL-3.0
#############################################################

set -e
set -u
set -o pipefail

# Cores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Variáveis
REBOOT=false
CLEANUP=false
BACKUP_DIR="/var/backups/apt"

msg_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

msg_error() {
    echo -e "${RED}[ERRO]${NC} $1" >&2
}

msg_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

show_help() {
    cat << EOF
Uso: $(basename "$0") [opções]

Descrição:
    Atualiza o sistema de forma segura com backup e validação

Opções:
    -h, --help          Mostra esta mensagem
    -r, --reboot        Reinicia após atualização se necessário
    -c, --cleanup       Remove pacotes desnecessários após atualização

Exemplos:
    sudo bash $(basename "$0")
    sudo bash $(basename "$0") --cleanup --reboot

EOF
    exit 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "Este script precisa ser executado como root"
        exit 1
    fi
}

detect_distro() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

backup_package_list() {
    msg_info "Fazendo backup da lista de pacotes..."
    mkdir -p "$BACKUP_DIR"
    
    local distro
    distro=$(detect_distro)
    case $distro in
        debian)
            dpkg --get-selections > "$BACKUP_DIR/packages-$(date +%Y%m%d).txt"
            ;;
        redhat)
            rpm -qa > "$BACKUP_DIR/packages-$(date +%Y%m%d).txt"
            ;;
    esac
    
    msg_info "Backup salvo em $BACKUP_DIR"
}

update_debian() {
    msg_info "Atualizando sistema Debian/Ubuntu..."
    
    apt-get update
    apt-get upgrade -y
    apt-get dist-upgrade -y
    
    if [[ "$CLEANUP" == true ]]; then
        msg_info "Removendo pacotes desnecessários..."
        apt-get autoremove -y
        apt-get autoclean -y
    fi
}

update_redhat() {
    msg_info "Atualizando sistema RedHat/CentOS..."
    
    if command -v dnf &> /dev/null; then
        dnf update -y
        if [[ "$CLEANUP" == true ]]; then
            dnf autoremove -y
            dnf clean all
        fi
    else
        yum update -y
        if [[ "$CLEANUP" == true ]]; then
            yum autoremove -y
            yum clean all
        fi
    fi
}

check_reboot_required() {
    if [[ -f /var/run/reboot-required ]]; then
        msg_warning "Reinicialização necessária!"
        if [[ "$REBOOT" == true ]]; then
            msg_info "Reiniciando em 10 segundos..."
            sleep 10
            reboot
        else
            msg_info "Execute 'sudo reboot' quando possível"
        fi
    fi
}

main() {
    msg_info "Iniciando atualização do sistema..."
    
    check_root
    backup_package_list
    
    local distro
    distro=$(detect_distro)
    case $distro in
        debian)
            update_debian
            ;;
        redhat)
            update_redhat
            ;;
        *)
            msg_error "Distribuição não suportada"
            exit 1
            ;;
    esac
    
    check_reboot_required
    
    msg_info "Atualização concluída com sucesso!"
}

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -r|--reboot)
            REBOOT=true
            shift
            ;;
        -c|--cleanup)
            CLEANUP=true
            shift
            ;;
        *)
            msg_error "Opção desconhecida: $1"
            show_help
            ;;
    esac
done

main "$@"
