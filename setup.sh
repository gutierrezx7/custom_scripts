#!/usr/bin/env bash

# Custom Scripts - Master Installer
# GitHub: https://github.com/gutierrezx7/custom_scripts
# License: GPL v3

# Configurações
REPO_URL="https://github.com/gutierrezx7/custom_scripts.git"
INSTALL_DIR="/opt/custom_scripts"
SCRIPT_NAME="setup.sh"
SUMMARY_LOG="/var/log/custom_scripts_summary.log"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variáveis Globais de Estado
declare -A SCRIPT_MAP
declare -a ORDERED_SCRIPTS
NEED_REBOOT=false
declare -a FAILED_SCRIPTS
declare -a SUCCESS_SCRIPTS

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

# Verificar Dependências do Sistema
check_dependencies() {
    if ! command -v whiptail >/dev/null; then
        msg_info "Instalando whiptail..."
        apt-get update -qq
        apt-get install -y whiptail -qq
    fi
}

# Funções de Parsing de Script
get_script_metadata() {
    local file="$1"
    local tag="$2"
    # Procura pela tag e remove espaços extras
    grep "^# $tag:" "$file" | cut -d: -f2- | sed 's/^[ \t]*//'
}

# Scanner de Scripts
scan_scripts() {
    local category="$1"
    
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
        
        # Novos Metadados
        INTERACTIVE=$(get_script_metadata "$file" "Interactive")
        REBOOT=$(get_script_metadata "$file" "Reboot")
        NETWORK=$(get_script_metadata "$file" "Network")
        
        # Defaults
        [ -z "$TITLE" ] && TITLE=$(basename "$file")
        [ -z "$INTERACTIVE" ] && INTERACTIVE="no"
        [ -z "$REBOOT" ] && REBOOT="no"
        [ -z "$NETWORK" ] && NETWORK="safe"
        
        # Filtro de Ambiente
        SHOW=true
        if [[ -n "$SUPPORTED" ]]; then
            if [[ "$ENV_TYPE" == "LXC" && "$SUPPORTED" != *"LXC"* ]]; then
                SHOW=false
            fi
            if [[ "$ENV_TYPE" != "LXC" && "$SUPPORTED" != *"VM"* && "$SUPPORTED" != *"ALL"* && -n "$SUPPORTED" ]]; then
                 if [[ "$SUPPORTED" == *"LXC"* && "$SUPPORTED" != *"VM"* ]]; then
                     SHOW=false
                 fi
            fi
        fi
        
        if [ "$SHOW" = true ]; then
            # Format: FILE|TITLE|DESC|INTERACTIVE|REBOOT|NETWORK|CATEGORY
            MENU_ITEMS+=("$file|$TITLE|$DESC|$INTERACTIVE|$REBOOT|$NETWORK|$category")
        fi
    done
}

# Menu Principal com Whiptail
show_menu_whiptail() {
    CATEGORIES=("system-admin" "docker" "network" "security" "monitoring" "maintenance" "backup")
    MENU_ITEMS=()
    FAILED_SCRIPTS=()
    SUCCESS_SCRIPTS=()
    NEED_REBOOT=false
    
    # Coletar todos os scripts
    for cat in "${CATEGORIES[@]}"; do
        scan_scripts "$cat"
    done
    
    # Construir argumentos para o whiptail
    local WHIP_ARGS=()
    
    for i in "${!MENU_ITEMS[@]}"; do
        IFS='|' read -r FILE TITLE DESC INTERACTIVE REBOOT NETWORK CAT <<< "${MENU_ITEMS[$i]}"
        
        # Tags visuais
        local TAGS=""
        [[ "$INTERACTIVE" == "yes" ]] && TAGS+=" [Int]"
        [[ "$REBOOT" == "yes" ]] && TAGS+=" [Reboot]"
        [[ "$NETWORK" == "risk" ]] && TAGS+=" [NetSafe]" # Ou risco, mas vamos padronizar
        [[ "$NETWORK" != "safe" ]] && TAGS+=" [NetRisk]"

        # Formatação estilo tabela
        # printf "%-30s | %-12s | %s" "$TITLE" "$CAT" "$TAGS"
        # Usando printf para alinhar texto para o whiptail
        local DISPLAY_STR=$(printf "%-25s  %-12s  %s" "${TITLE:0:25}" "(${CAT})" "${TAGS}")
        
        # ID é o índice no array MENU_ITEMS
        WHIP_ARGS+=("$i" "$DISPLAY_STR" "OFF")
    done
    
    if [ ${#WHIP_ARGS[@]} -eq 0 ]; then
        msg_error "Nenhum script disponível para este ambiente ($ENV_TYPE)."
        exit 1
    fi
    
    CHOICES=$(whiptail --title "Custom Scripts Manager ($ENV_TYPE)" \
                       --checklist "Selecione os scripts para instalar/executar:\nUse ESPAÇO para selecionar, ENTER para confirmar." \
                       22 85 12 \
                       "${WHIP_ARGS[@]}" 3>&1 1>&2 2>&3)
    
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        exit 0
    fi
    
    # Remover aspas do output do whiptail
    CHOICES=$(echo "$CHOICES" | tr -d '"')
    
    if [ -z "$CHOICES" ]; then
        return
    fi
    
    run_queue "$CHOICES"
}

# Lógica de Execução Inteligente
run_queue() {
    local choices_str="$1"
    
    local interactive_queue=()
    local safe_queue=()
    local risk_queue=()
    
    # Separar em filas
    for id in $choices_str; do
        IFS='|' read -r FILE TITLE DESC INTERACTIVE REBOOT NETWORK CAT <<< "${MENU_ITEMS[$id]}"
        
        # Prioridade de Risco: Se for Network Risk, vai para o final, mesmo se for interativo.
        if [[ "$NETWORK" == "risk" ]]; then
            risk_queue+=("$id")
        elif [[ "$INTERACTIVE" == "yes" ]]; then
            interactive_queue+=("$id")
        else
            safe_queue+=("$id")
        fi
    done
    
    # Combinar filas na ordem correta
    # Ordem: Interativos -> Seguros -> Risco de Rede
    local final_queue=("${interactive_queue[@]}" "${safe_queue[@]}" "${risk_queue[@]}")
    
    clear
    msg_header "Iniciando Execução em Lote"
    echo "Total de scripts selecionados: ${#final_queue[@]}"
    sleep 2
    
    # Limpar log anterior
    echo "--- Execução iniciada em $(date) ---" > "$SUMMARY_LOG"

    for id in "${final_queue[@]}"; do
        IFS='|' read -r FILE TITLE DESC INTERACTIVE REBOOT NETWORK CAT <<< "${MENU_ITEMS[$id]}"
        
        msg_header "Executando ($CAT): $TITLE"
        if [[ "$REBOOT" == "yes" ]]; then
            msg_warn "Este script requer reinicialização. O reboot será agendado para o final."
        fi
        
        # Executar Script
        bash "$FILE"
        local ret=$?
        
        if [ $ret -eq 0 ]; then
            msg_info "$TITLE concluído com sucesso."
            SUCCESS_SCRIPTS+=("$TITLE")
            if [[ "$REBOOT" == "yes" ]]; then
                NEED_REBOOT=true
            fi
        else
            msg_error "$TITLE falhou (Código: $ret). Continuando..."
            FAILED_SCRIPTS+=("$TITLE (Exit Code: $ret)")
            sleep 3
        fi
        
        echo "------------------------------------------------"
    done
    
    finalize
}

generate_summary() {
    local summary_text="Resumo da Execução:\n\n"

    if [ ${#SUCCESS_SCRIPTS[@]} -gt 0 ]; then
        summary_text+="SUCESSO:\n"
        for s in "${SUCCESS_SCRIPTS[@]}"; do
            summary_text+="  - $s\n"
        done
        summary_text+="\n"
    fi

    if [ ${#FAILED_SCRIPTS[@]} -gt 0 ]; then
        summary_text+="FALHAS:\n"
        for f in "${FAILED_SCRIPTS[@]}"; do
            summary_text+="  - $f\n"
        done
        summary_text+="\nVerifique o console para mais detalhes."
    else
        summary_text+="Todos os scripts foram executados com sucesso."
    fi

    # Gravar no log
    echo -e "$summary_text" >> "$SUMMARY_LOG"

    # Exibir no Whiptail
    whiptail --title "Relatório de Execução" --msgbox "$summary_text" 20 70
}

finalize() {
    generate_summary

    msg_header "Execução Finalizada"
    
    if [ "$NEED_REBOOT" = true ]; then
        if (whiptail --title "Reinicialização Necessária" --yesno "Um ou mais scripts solicitam reinicialização para aplicar as alterações.\nDeseja reiniciar agora?" 10 60); then
            msg_info "Reiniciando sistema..."
            reboot
        else
            msg_warn "Por favor, reinicie o sistema manualmente quando possível."
        fi
    else
        msg_info "Todos os processos concluídos. Pressione Enter para sair."
        read -r
    fi
    exit 0
}

main() {
    # Verificar root
    if [ "$EUID" -ne 0 ]; then
        echo "Por favor, execute como root."
        exit 1
    fi

    detect_env
    bootstrap
    check_dependencies
    
    while true; do
        show_menu_whiptail
    done
}

main
