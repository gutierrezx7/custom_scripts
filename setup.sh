#!/usr/bin/env bash

# Custom Scripts - Master Installer
# GitHub: https://github.com/gutierrezx7/custom_scripts
# License: GPL v3

# Configurações
REPO_URL="https://github.com/gutierrezx7/custom_scripts.git"
INSTALL_DIR="/opt/custom_scripts"
SCRIPT_NAME="setup.sh"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
msg_error() { echo -e "${RED}[ERRO]${NC} $1"; }
msg_header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Detectar Virtualização
detect_env() {
    if command -v systemd-detect-virt >/dev/null; then
        VIRT=$(systemd-detect-virt)
        if [ "$VIRT" == "lxc" ]; then
            ENV_TYPE="LXC"
        elif [ "$VIRT" == "none" ]; then
            ENV_TYPE="Bare-Metal" # Tratar como VM
        else
            ENV_TYPE="VM"
        fi
    else
        ENV_TYPE="Desconhecido"
    fi
}

# Auto-Bootstrap (Clona o repo se não estiver rodando localmente)
bootstrap() {
    # Se o diretório atual não é o INSTALL_DIR, ou se não tem .git
    if [[ "$PWD" != "$INSTALL_DIR" ]]; then
        msg_header "Inicialização"
        msg_info "Instalando dependências (git)..."
        if ! command -v git >/dev/null; then
            apt-get update -qq
            apt-get install -y git -qq
        fi

        if [ -d "$INSTALL_DIR" ]; then
            msg_info "Atualizando repositório em $INSTALL_DIR..."
            cd "$INSTALL_DIR"
            git pull
        else
            msg_info "Clonando repositório para $INSTALL_DIR..."
            git clone "$REPO_URL" "$INSTALL_DIR"
            cd "$INSTALL_DIR"
        fi

        chmod +x "$SCRIPT_NAME"
        msg_info "Reiniciando script a partir do diretório de instalação..."
        exec bash "$SCRIPT_NAME"
    fi
}

# Funções de Parsing de Script
get_script_metadata() {
    local file="$1"
    local tag="$2"
    grep "^# $tag:" "$file" | cut -d: -f2- | sed 's/^[ \t]*//'
}

# Scanner de Scripts
scan_scripts() {
    local category="$1"
    local scripts=()
    local i=1
    
    if [ ! -d "$category" ]; then
        return
    fi
    
    # Listar arquivos .sh
    for file in "$category"/*.sh; do
        [ -e "$file" ] || continue
        
        # Ler Metadata
        TITLE=$(get_script_metadata "$file" "Title")
        DESC=$(get_script_metadata "$file" "Description")
        SUPPORTED=$(get_script_metadata "$file" "Supported")
        
        # Fallback se não tiver metadata
        if [ -z "$TITLE" ]; then
            TITLE=$(basename "$file")
        fi
        
        # Filtro de Ambiente
        SHOW=true
        if [[ -n "$SUPPORTED" ]]; then
            if [[ "$ENV_TYPE" == "LXC" && "$SUPPORTED" != *"LXC"* ]]; then
                SHOW=false
            fi
            if [[ "$ENV_TYPE" != "LXC" && "$SUPPORTED" != *"VM"* && "$SUPPORTED" != *"ALL"* && -n "$SUPPORTED" ]]; then
                 # Se for VM e o script só suportar LXC (raro, mas possível)
                 if [[ "$SUPPORTED" == *"LXC"* && "$SUPPORTED" != *"VM"* ]]; then
                     SHOW=false
                 fi
            fi
        fi
        
        if [ "$SHOW" = true ]; then
            # Armazenar no array global
            MENU_ITEMS+=("$file|$TITLE|$DESC")
        fi
    done
}

# Menu Principal
show_menu() {
    clear
    echo -e "${BLUE}
    ################################################
    #            CUSTOM SCRIPTS MANAGER            #
    ################################################
    ${NC}"
    echo -e "Ambiente Detectado: ${CYAN}$ENV_TYPE${NC}"
    echo -e "IP: ${CYAN}$(hostname -I | awk '{print $1}')${NC}"
    echo -e "Host: ${CYAN}$(hostname)${NC}"
    echo
    echo "Categorias Disponíveis:"
    
    CATEGORIES=("system-admin" "docker" "network" "security" "monitoring" "maintenance" "backup")
    
    # Montar Menu Global Dinâmico
    MENU_ITEMS=() # Reset
    
    # 1. Core Setup (Prioridade)
    echo -e "${YELLOW}--- Configuração Inicial ---${NC}"
    i=1
    
    # Adicionar scripts específicos manualmente no topo para garantir ordem, ou scanear
    # Vamos scanear tudo e ordenar por categoria na exibição
    
    GLOBAL_INDEX=1
    declare -A SCRIPT_MAP
    
    for cat in "${CATEGORIES[@]}"; do
        # Captura itens desta categoria
        TEMP_ITEMS=()
        local original_len=${#MENU_ITEMS[@]}
        scan_scripts "$cat" # Popula MENU_ITEMS
        
        # Exibir cabeçalho da categoria se houver novos itens
        local new_len=${#MENU_ITEMS[@]}
        if [ $new_len -gt $original_len ]; then
             echo -e "\n${YELLOW}[ $cat ]${NC}"
             for (( j=$original_len; j<$new_len; j++ )); do
                IFS='|' read -r FILE TITLE DESC <<< "${MENU_ITEMS[$j]}"
                printf " %2d) %-30s %s\n" "$GLOBAL_INDEX" "$TITLE" "($DESC)"
                SCRIPT_MAP[$GLOBAL_INDEX]="$FILE"
                ((GLOBAL_INDEX++))
             done
        fi
    done
    
    echo
    echo "  0) Sair"
    echo
    read -p "Selecione uma opção: " CHOICE
    
    if [ "$CHOICE" == "0" ]; then
        exit 0
    fi
    
    if [ -n "${SCRIPT_MAP[$CHOICE]}" ]; then
        FILE="${SCRIPT_MAP[$CHOICE]}"
        msg_header "Executando: $FILE"
        bash "$FILE"
        echo
        read -p "Pressione Enter para voltar ao menu..."
    else
        msg_error "Opção inválida."
        sleep 1
    fi
}

main() {
    # Verificar root
    if [ "$EUID" -ne 0 ]; then
        msg_error "Por favor, execute como root."
        exit 1
    fi

    detect_env
    bootstrap
    
    while true; do
        show_menu
    done
}

main
