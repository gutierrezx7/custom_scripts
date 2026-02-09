#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - Master Installer (setup.sh) v2.0
#
# Menu principal interativo com auto-discovery de scripts.
# Detecta ambiente, escaneia pastas, filtra por compatibilidade e executa.
#
# Uso:
#   bash setup.sh                  # Menu interativo
#   bash setup.sh --list           # Listar scripts disponíveis
#   bash setup.sh --dry-run        # Menu com simulação (nada é instalado)
#   bash setup.sh --run <script>   # Executar script específico
#   bash setup.sh --help           # Ajuda
#
# GitHub: https://github.com/gutierrezx7/custom_scripts
# License: GPL v3
# =============================================================================

set -eo pipefail

# ── Configurações ────────────────────────────────────────────────────────────
REPO_URL="https://github.com/gutierrezx7/custom_scripts.git"
INSTALL_DIR="/opt/custom_scripts"
VERSION="2.0.0"

# ── Funções mínimas para fase de bootstrap ───────────────────────────────────
# Usadas ANTES de lib/common.sh estar disponível (execução remota via wget/curl)
_bs_info()   { echo -e "\033[0;32m[INFO]\033[0m    $1"; }
_bs_warn()   { echo -e "\033[1;33m[AVISO]\033[0m   $1"; }
_bs_error()  { echo -e "\033[0;31m[ERRO]\033[0m    $1" >&2; }
_bs_header() { echo -e "\n\033[0;34m\033[1m━━━ $1 ━━━\033[0m"; }
_bs_step()   { echo -e "  \033[0;36m➜\033[0m $1"; }

# ── Resolver diretório do script ─────────────────────────────────────────────
# BASH_SOURCE fica vazio quando executado via: bash -c "$(wget -qLO - URL)"
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Execução remota (wget/curl pipe) — sem arquivo local
    SCRIPT_DIR=""
fi

# ── Auto-Bootstrap ───────────────────────────────────────────────────────────
# Deve rodar ANTES de carregar lib/ (que pode não existir ainda)
bootstrap() {
    local forward_args=("$@")

    # Já estamos no diretório de instalação com lib/ disponível? Nada a fazer.
    if [[ -n "$SCRIPT_DIR" && "$SCRIPT_DIR" == "$INSTALL_DIR" ]]; then
        return 0
    fi

    # Estamos num clone local com lib/? (dev mode) Nada a fazer.
    if [[ -n "$SCRIPT_DIR" && -d "${SCRIPT_DIR}/.git" && -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
        return 0
    fi

    # ── Daqui em diante, precisamos clonar/atualizar o repositório ────────

    # Verificar root
    if [[ "$EUID" -ne 0 ]]; then
        _bs_error "Por favor, execute como root (sudo)."
        exit 1
    fi

    # Se o repo já existe em INSTALL_DIR, atualiza e re-executa de lá
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        _bs_step "Atualizando repositório em $INSTALL_DIR..."
        cd "$INSTALL_DIR"
        git pull --quiet 2>/dev/null || _bs_warn "Falha ao atualizar (usando versão local)."
        exec bash "$INSTALL_DIR/setup.sh" "${forward_args[@]}"
    fi

    # Primeira execução: instalar git se necessário e clonar
    _bs_header "Primeira Execução"
    if ! command -v git &>/dev/null; then
        _bs_step "Instalando git..."
        apt-get update -qq
        apt-get install -y git -qq
    fi

    _bs_step "Clonando repositório para $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    chmod +x setup.sh

    _bs_step "Reiniciando a partir do repositório clonado..."
    exec bash "$INSTALL_DIR/setup.sh" "${forward_args[@]}"
}

# Executar bootstrap imediatamente (pode exec e nunca retornar)
bootstrap "$@"

# ── Se chegou aqui, SCRIPT_DIR é válido e lib/ existe ───────────────────────
set -u  # Agora é seguro ativar nounset

# ── Carregar bibliotecas ─────────────────────────────────────────────────────
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/registry.sh"
source "${SCRIPT_DIR}/lib/runner.sh"

# ── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    echo -e "${CS_CYAN}${CS_BOLD}"
    cat << 'BANNER'
   ╔═══════════════════════════════════════════╗
   ║       🐧  Custom Scripts  v2.0           ║
   ║       Scripts Linux Sortidos 2025         ║
   ╚═══════════════════════════════════════════╝
BANNER
    echo -e "${CS_NC}"

    detect_env
    detect_distro
    echo -e "  ${CS_DIM}Ambiente:${CS_NC} ${CS_BOLD}${CS_ENV_TYPE}${CS_NC}  │  ${CS_DIM}Distro:${CS_NC} ${CS_BOLD}${CS_DISTRO_PRETTY}${CS_NC}"

    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        echo -e "  ${CS_MAGENTA}${CS_BOLD}⚠ MODO DRY-RUN ATIVO - Nenhuma alteração será feita${CS_NC}"
    fi
    echo ""
}

# ── Menu com Whiptail ────────────────────────────────────────────────────────
show_menu() {
    # Garantir whiptail
    if ! check_command whiptail; then
        msg_step "Instalando whiptail..."
        cs_apt_install whiptail
    fi

    # Escanear e filtrar
    cs_registry_scan "${SCRIPT_DIR}"
    cs_registry_filter_env

    if [[ ${#CS_REGISTRY_FILES[@]} -eq 0 ]]; then
        msg_error "Nenhum script disponível para este ambiente (${CS_ENV_TYPE})."
        exit 1
    fi

    # Calcular dimensões do terminal
    local term_h term_w
    term_h=$(tput lines 2>/dev/null || echo 24)
    term_w=$(tput cols 2>/dev/null || echo 80)

    local box_h=$((term_h - 4)); [[ $box_h -lt 12 ]] && box_h=12
    local box_w=$((term_w - 4)); [[ $box_w -lt 60 ]] && box_w=60
    local list_h=$((box_h - 8)); [[ $list_h -lt 5 ]] && list_h=5
    local max_title=$((box_w - 45)); [[ $max_title -lt 20 ]] && max_title=20

    # Construir itens do menu agrupados por categoria
    local whip_args=()
    local -a indexed_files=()
    local idx=0
    local current_cat=""

    while IFS= read -r cat; do
        while IFS= read -r file; do
            local title="${CS_REGISTRY_TITLE[$file]}"
            local interactive="${CS_REGISTRY_INTERACTIVE[$file]}"
            local reboot="${CS_REGISTRY_REBOOT[$file]}"
            local network="${CS_REGISTRY_NETWORK[$file]}"

            # Tags visuais
            local tags=""
            [[ "$interactive" == "yes" ]] && tags+=" ⚙"
            [[ "$reboot" == "yes" ]]      && tags+=" ↻"
            [[ "$network" == "risk" ]]    && tags+=" ⚠"

            # Categoria label
            local cat_short="${cat}"
            [[ "$cat" != "$current_cat" ]] && current_cat="$cat"

            local display
            display=$(printf "%-${max_title}s  (%-12s) %s" "${title:0:$max_title}" "$cat_short" "$tags")

            whip_args+=("$idx" "$display" "OFF")
            indexed_files+=("$file")
            ((idx++))
        done < <(cs_registry_by_category "$cat")
    done < <(cs_registry_categories)

    # Título dinâmico
    local menu_title="Custom Scripts v${VERSION} [${CS_ENV_TYPE}]"
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        menu_title+=" 🔍 DRY-RUN"
    fi

    # Mostrar menu
    local choices
    choices=$(whiptail \
        --title "$menu_title" \
        --checklist "Selecione com ESPAÇO, confirme com ENTER:\n\n⚙ = Interativo  ↻ = Reboot  ⚠ = Risco de Rede" \
        "$box_h" "$box_w" "$list_h" \
        "${whip_args[@]}" \
        3>&1 1>&2 2>&3) || return 0

    # Remover aspas
    choices=$(echo "$choices" | tr -d '"')
    [[ -z "$choices" ]] && return 0

    # Mapear IDs para arquivos
    local selected_files=()
    for id in $choices; do
        selected_files+=("${indexed_files[$id]}")
    done

    # Confirmar seleção
    echo ""
    msg_header "Scripts selecionados"
    for file in "${selected_files[@]}"; do
        local title="${CS_REGISTRY_TITLE[$file]}"
        local cat="${CS_REGISTRY_CATEGORY[$file]}"
        echo -e "  ${CS_CYAN}•${CS_NC} ${title} ${CS_DIM}(${cat})${CS_NC}"
    done
    echo ""

    if ! confirm "Confirma a execução?" "y"; then
        msg_info "Operação cancelada."
        return 0
    fi

    # Executar
    cs_runner_reset
    cs_run_batch "${selected_files[@]}"
}

# ── Executar script específico ───────────────────────────────────────────────
run_specific() {
    local target="$1"

    cs_registry_scan "${SCRIPT_DIR}"

    # Buscar por nome parcial
    local found=""
    for file in "${CS_REGISTRY_FILES[@]}"; do
        if [[ "$file" == *"$target"* ]]; then
            found="$file"
            break
        fi
    done

    if [[ -z "$found" ]]; then
        msg_error "Script não encontrado: $target"
        msg_info "Use --list para ver scripts disponíveis."
        exit 1
    fi

    msg_info "Encontrado: ${CS_REGISTRY_TITLE[$found]} (${found})"
    cs_runner_reset
    cs_run_script "$found"
}

# ── Ajuda ────────────────────────────────────────────────────────────────────
show_help() {
    cat << EOF
${CS_BOLD}Custom Scripts v${VERSION}${CS_NC} - Scripts Linux Sortidos

${CS_BOLD}Uso:${CS_NC}
  bash setup.sh [opções]

${CS_BOLD}Opções:${CS_NC}
  ${CS_GREEN}(sem opções)${CS_NC}         Menu interativo (recomendado)
  ${CS_GREEN}--list${CS_NC}               Listar todos os scripts disponíveis
  ${CS_GREEN}--dry-run${CS_NC}            Modo simulação (nada é instalado)
  ${CS_GREEN}--run <script>${CS_NC}       Executar script específico (nome parcial)
  ${CS_GREEN}--verbose${CS_NC}            Modo detalhado (debug)
  ${CS_GREEN}--version${CS_NC}            Mostrar versão
  ${CS_GREEN}--help${CS_NC}               Esta mensagem

${CS_BOLD}Exemplos:${CS_NC}
  bash setup.sh                          # Menu interativo
  bash setup.sh --dry-run                # Testar sem instalar nada
  bash setup.sh --list                   # Ver scripts disponíveis
  bash setup.sh --run docker-install     # Instalar Docker direto
  bash setup.sh --dry-run --run tailscale # Simular instalação do Tailscale

${CS_BOLD}Mais informações:${CS_NC}
  https://github.com/gutierrezx7/custom_scripts

EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    local action="menu"
    local run_target=""

    # Parse de argumentos
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)   CS_DRY_RUN=true; shift ;;
            --verbose)   CS_VERBOSE=true; shift ;;
            --no-color)  NO_COLOR=1; shift ;;
            --list)      action="list"; shift ;;
            --run)       action="run"; run_target="${2:-}"; shift 2 ;;
            --version)   echo "Custom Scripts v${VERSION}"; exit 0 ;;
            --help|-h)   show_help; exit 0 ;;
            *)           msg_error "Opção desconhecida: $1"; show_help; exit 1 ;;
        esac
    done

    # Verificar root
    check_root

    # Detectar ambiente
    detect_env
    detect_distro

    # Executar ação
    case "$action" in
        list)
            show_banner
            cs_registry_scan "${SCRIPT_DIR}"
            cs_registry_filter_env
            cs_registry_print
            ;;
        run)
            show_banner
            if [[ -z "$run_target" ]]; then
                msg_error "Especifique o nome do script: --run <nome>"
                exit 1
            fi
            run_specific "$run_target"
            ;;
        menu)
            show_banner
            while true; do
                show_menu
                echo ""
                if ! confirm "Voltar ao menu principal?" "y"; then
                    msg_info "Até a próxima! 👋"
                    exit 0
                fi
            done
            ;;
    esac
}

main "$@"
