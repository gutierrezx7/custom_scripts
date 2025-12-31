#!/bin/bash

#############################################################
# Nome do Script: clean-system.sh
# Descrição: Limpeza completa do sistema Linux
# Autor: Custom Scripts Team
# Data: 22/12/2024
# Versão: 1.0
# Licença: GPL-3.0
#############################################################
# Interactive: no
# Reboot: no
# Network: safe

set -e
set -u
set -o pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

DRY_RUN=false
DEEP_CLEAN=false

msg_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

msg_error() {
    echo -e "${RED}[ERRO]${NC} $1" >&2
}

show_help() {
    cat << EOF
Uso: $(basename "$0") [opções]

Descrição:
    Limpeza do sistema removendo arquivos temporários e cache

Opções:
    -h, --help          Mostra esta mensagem
    -n, --dry-run       Simula limpeza sem remover
    -d, --deep          Limpeza profunda (mais agressiva)

Exemplos:
    sudo bash $(basename "$0") --dry-run
    sudo bash $(basename "$0") --deep

EOF
    exit 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "Este script precisa ser executado como root"
        exit 1
    fi
}

get_free_space() {
    df / | awk 'NR==2 {print $4}'
}

clean_apt_cache() {
    msg_info "Limpando cache do APT..."
    if [[ "$DRY_RUN" == false ]]; then
        apt-get clean
        apt-get autoclean
    fi
}

clean_temp_files() {
    msg_info "Limpando arquivos temporários..."
    if [[ "$DRY_RUN" == false ]]; then
        find /tmp -type f -atime +7 -delete 2>/dev/null || true
        find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    fi
}

clean_old_logs() {
    msg_info "Limpando logs antigos..."
    if [[ "$DRY_RUN" == false ]]; then
        find /var/log -type f -name "*.log.*" -delete 2>/dev/null || true
        find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
        journalctl --vacuum-time=7d
    fi
}

clean_thumbnail_cache() {
    msg_info "Limpando cache de miniaturas..."
    if [[ "$DRY_RUN" == false ]]; then
        rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
    fi
}

clean_package_cache() {
    msg_info "Limpando cache de pacotes..."
    if [[ "$DRY_RUN" == false ]]; then
        apt-get autoremove -y
    fi
}

deep_clean() {
    msg_info "Executando limpeza profunda..."
    
    if [[ "$DRY_RUN" == false ]]; then
        # Limpar cache do usuário
        rm -rf ~/.cache/* 2>/dev/null || true
        
        # Limpar arquivos órfãos
        find /var/cache -type f -atime +30 -delete 2>/dev/null || true
        
        # Limpar kernels antigos (manter os 2 mais recentes)
        if command -v purge-old-kernels &> /dev/null; then
            purge-old-kernels --keep 2
        fi
    fi
}

main() {
    msg_info "Iniciando limpeza do sistema..."
    
    check_root
    
    local space_before
    space_before=$(get_free_space)
    
    clean_apt_cache
    clean_temp_files
    clean_old_logs
    clean_thumbnail_cache
    clean_package_cache
    
    if [[ "$DEEP_CLEAN" == true ]]; then
        deep_clean
    fi
    
    local space_after
    space_after=$(get_free_space)
    local freed=$((space_after - space_before))
    
    msg_info "Limpeza concluída!"
    msg_info "Espaço liberado: ~$((freed / 1024)) MB"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -n|--dry-run)
            DRY_RUN=true
            msg_info "Modo dry-run ativado"
            shift
            ;;
        -d|--deep)
            DEEP_CLEAN=true
            shift
            ;;
        *)
            msg_error "Opção desconhecida: $1"
            show_help
            ;;
    esac
done

main "$@"
