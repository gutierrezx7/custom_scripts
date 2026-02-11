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
INSTALL_DIR="${CS_INSTALL_DIR:-/opt/custom_scripts}"
CS_VERSION="2.1.0"
# shellcheck disable=SC2034
BUILD_DATE="2026-02-11"

# Debug opcional (export CS_DEBUG=1)
if [[ "${CS_DEBUG:-}" == "1" ]]; then
    set -x
    trap '_bs_error "Falha em: ${BASH_SOURCE[0]}:${LINENO} -> ${BASH_COMMAND}"' ERR
fi

# ── Funções mínimas para fase de bootstrap ───────────────────────────────────
_bs_info()   { echo -e "\033[0;32m[INFO]\033[0m    $1"; }
_bs_warn()   { echo -e "\033[1;33m[AVISO]\033[0m   $1"; }
_bs_error()  { echo -e "\033[0;31m[ERRO]\033[0m    $1" >&2; }
_bs_header() { echo -e "\n\033[0;34m\033[1m━━━ $1 ━━━\033[0m"; }
_bs_step()   { echo -e "  \033[0;36m➜\033[0m $1"; }

# ── Resolver diretório do script ─────────────────────────────────────────────
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR=""
fi

# ── Auto-Bootstrap ───────────────────────────────────────────────────────────
bootstrap() {
    # Garante que set -u não quebre o bootstrap se herdado do ambiente
    set +u

    local forward_args=("$@")

    # Já estamos no diretório de instalação com lib/ disponível?
    if [[ -n "$SCRIPT_DIR" && "$SCRIPT_DIR" == "$INSTALL_DIR" ]]; then
        return 0
    fi

    # Dev mode local?
    if [[ -n "$SCRIPT_DIR" && -d "${SCRIPT_DIR}/.git" && -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
        return 0
    fi

    if [[ "$EUID" -ne 0 && "${CS_SKIP_ROOT_CHECK:-}" != "true" ]]; then
        _bs_error "Por favor, execute como root (sudo)."
        exit 1
    fi

    # Remote Mode (Pipe)
    if [[ -z "$SCRIPT_DIR" ]]; then
        REMOTE_MODE=1
        REMOTE_RAW_BASE="https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main"
        REMOTE_API_BASE="https://api.github.com/repos/gutierrezx7/custom_scripts/git/trees/main?recursive=1"

        _bs_step "Modo remoto detectado — carregando bibliotecas..."

        # Ordem de carga atualizada
        for lib in common system display state registry runner; do
            _bs_step "Carregando lib/$lib.sh..."
            if ! source <(curl -fsSL "${REMOTE_RAW_BASE}/lib/${lib}.sh"); then
                _bs_error "Falha ao carregar lib/$lib.sh do remoto."
                exit 1
            fi
        done
        return 0
    fi

    # Update Mode
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        _bs_step "Atualizando repositório em $INSTALL_DIR..."
        cd "$INSTALL_DIR"
        git fetch --all --prune --quiet 2>/dev/null || true
        git pull --rebase --autostash --quiet 2>/dev/null || _bs_warn "Falha ao atualizar (usando versão local)."
        exec bash "$INSTALL_DIR/setup.sh" "${forward_args[@]}"
    fi

    # Install Mode
    _bs_header "Primeira Execução"
    if ! command -v git &>/dev/null; then
        _bs_step "Instalando git..."
        apt-get update -qq 2>/dev/null || true
        apt-get install -y git -qq
    fi

    _bs_step "Clonando repositório..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    chmod +x setup.sh

    _bs_step "Reiniciando a partir do repositório clonado..."
    exec bash "$INSTALL_DIR/setup.sh" "${forward_args[@]}"
}

bootstrap "$@"

# ── Load Libs ────────────────────────────────────────────────────────────────
set -u
if [[ "${REMOTE_MODE:-}" != "1" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
    source "${SCRIPT_DIR}/lib/system.sh"
    source "${SCRIPT_DIR}/lib/display.sh"
    source "${SCRIPT_DIR}/lib/state.sh"
    source "${SCRIPT_DIR}/lib/registry.sh"
    source "${SCRIPT_DIR}/lib/runner.sh"
fi

# ── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    echo -e "${CS_CYAN}${CS_BOLD}"
    cat << 'BANNER'
   ╔═══════════════════════════════════════════╗
   ║       🐧  Custom Scripts  v2.1           ║
   ║       Scripts Linux Sortidos 2025         ║
   ╚═══════════════════════════════════════════╝
BANNER
    echo -e "${CS_NC}"

    # Garante detecção atualizada
    cs_system_detect

    echo -e "  ${CS_DIM}Ambiente:${CS_NC} ${CS_BOLD}${CS_VIRT_TYPE^^}${CS_NC}  │  ${CS_DIM}OS:${CS_NC} ${CS_BOLD}${CS_OS_PRETTY}${CS_NC}"
    echo -e "  ${CS_DIM}Recursos:${CS_NC} ${CS_BOLD}${CS_RAM_MB}MB RAM / ${CS_DISK_GB}GB Disk${CS_NC}"

    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        echo -e "  ${CS_MAGENTA}${CS_BOLD}DRY-RUN ATIVO - Nenhuma alteração será feita${CS_NC}"
    fi
    echo ""
}

# ── Menu Principal ───────────────────────────────────────────────────────────
show_menu() {
    # Scan e Filtro
    cs_registry_scan "${SCRIPT_DIR}" || true
    cs_registry_filter_env || true

    if [[ ${#CS_REGISTRY_FILES[@]} -eq 0 ]]; then
        cs_ui_msgbox "Aviso" "Nenhum script compatível encontrado para este ambiente (${CS_VIRT_TYPE})."
        return 0
    fi

    # Preparar opções para Checklist (Group by Category)
    local whip_args=()
    local -a indexed_files=()
    local idx=0

    # Obter categorias ordenadas
    local categories
    categories=$(cs_registry_get_categories)

    for cat in $categories; do
        local cat_files
        cat_files=$(cs_registry_get_by_category "$cat")

        for file in $cat_files; do
            local title="${CS_REGISTRY_TITLE[$file]}"
            local tags=""
            [[ "${CS_REGISTRY_INTERACTIVE[$file]}" == "yes" ]] && tags+=" [I]"
            [[ "${CS_REGISTRY_REBOOT[$file]}" == "yes" ]]      && tags+=" [R]"
            [[ "${CS_REGISTRY_NETWORK[$file]}" == "risk" ]]    && tags+=" [!]"

            # Formatação alinhada
            local display
            display=$(printf "(%-12s) %s %s" "$cat" "${title:0:40}" "$tags")

            whip_args+=("$idx" "$display" "OFF")
            indexed_files+=("$file")
            ((idx+=1))
        done
    done

    # Exibir Menu Checklist
    local result
    if result=$(cs_ui_checklist "Seleção de Scripts [${CS_VIRT_TYPE}]" \
        "Selecione com ESPAÇO, confirme com ENTER:\n[I]=Interativo [R]=Reboot [!]=Rede" \
        "${whip_args[@]}"); then

        # Parse output (remove quotes "1" "2")
        result=$(echo "$result" | tr -d '"')
        [[ -z "$result" ]] && return 0

        # Mapear IDs para arquivos
        local selected_files=()
        for id in $result; do
            selected_files+=("${indexed_files[$id]}")
        done

        # Confirmar e Executar
        echo ""
        msg_header "Scripts selecionados:"
        for file in "${selected_files[@]}"; do
            echo -e "  - ${CS_REGISTRY_TITLE[$file]}"
        done
        echo ""

        if cs_ui_yesno "Confirmação" "Deseja executar os scripts selecionados?"; then
            cs_runner_reset
            cs_run_batch "${selected_files[@]}"
        else
            msg_info "Cancelado pelo usuário."
        fi
    fi
}

# ── Wizard ───────────────────────────────────────────────────────────────────
run_wizard() {
    cs_ui_msgbox "Wizard" "Este assistente irá configurar Hostname, Rede e Timezone."

    local current_hostname new_hostname
    current_hostname=$(hostname)

    new_hostname=$(cs_ui_inputbox "Hostname" "Novo Hostname:" "$current_hostname") || return 0

    # ── Passo 2: IP Estático ─────────────────────────────────────────────
    if [[ "$CS_VIRT_TYPE" != "lxc" ]]; then
        local default_iface current_ip
        default_iface=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -n1)
        current_ip=$(ip -4 addr show "$default_iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)

        if cs_ui_yesno "Rede (IP Estático)" "Interface: ${default_iface}\nIP Atual: ${current_ip:-DHCP}\n\nDeseja configurar IP estático?"; then
            local static_iface static_ip static_gw static_dns set_static_ip="yes"

            static_iface=$(cs_ui_inputbox "Rede" "Interface:" "${default_iface}") || set_static_ip="no"
            if [[ "$set_static_ip" == "yes" ]]; then
                static_ip=$(cs_ui_inputbox "Rede" "IP/Máscara (ex: 192.168.1.10/24):" "${current_ip:-192.168.1.10/24}") || set_static_ip="no"
            fi
            if [[ "$set_static_ip" == "yes" ]]; then
                local default_gw_val
                default_gw_val=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1)
                static_gw=$(cs_ui_inputbox "Rede" "Gateway:" "${default_gw_val:-192.168.1.1}") || set_static_ip="no"
            fi
            if [[ "$set_static_ip" == "yes" ]]; then
                static_dns=$(cs_ui_inputbox "Rede" "DNS (separado por vírgula):" "1.1.1.1, 8.8.8.8") || set_static_ip="no"
            fi

            if [[ "$set_static_ip" == "yes" ]]; then
                # Aplicar Netplan
                if [[ "${CS_DRY_RUN}" == "true" ]]; then
                    msg_dry_run "Criaria Netplan para $static_ip em $static_iface"
                else
                    local netplan_file="/etc/netplan/99-custom-scripts.yaml"
                    mkdir -p /etc/netplan
                    cat > "$netplan_file" << NETEOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${static_iface}:
      dhcp4: no
      addresses:
        - ${static_ip}
      routes:
        - to: default
          via: ${static_gw}
      nameservers:
        addresses: [${static_dns}]
NETEOF
                    chmod 600 "$netplan_file"
                    msg_success "IP estático configurado (será aplicado no reboot)"
                fi
            fi
        fi
    else
        msg_step "Rede: Configuração ignorada em LXC (gerenciado pelo host)."
    fi

    # ── Passo 3: Timezone ────────────────────────────────────────────────
    local current_tz new_tz
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "UTC")

    new_tz=$(cs_ui_inputbox "Timezone" "Fuso Horário (ex: America/Sao_Paulo):" "$current_tz") || new_tz="$current_tz"

    if [[ "$new_tz" != "$current_tz" ]]; then
        if [[ "${CS_DRY_RUN}" == "true" ]]; then
             msg_dry_run "timedatectl set-timezone $new_tz"
        else
             timedatectl set-timezone "$new_tz" || true
        fi
    fi

    if [[ "$new_hostname" != "$current_hostname" ]]; then
        if [[ "${CS_DRY_RUN}" == "true" ]]; then
            msg_dry_run "hostnamectl set-hostname $new_hostname"
        else
            hostnamectl set-hostname "$new_hostname"
        fi
    fi

    # Chama o menu normal para scripts
    show_menu
}

# ── Entry Point ──────────────────────────────────────────────────────────────
main() {
    local action="menu"
    local run_target=""

    # Argument Parsing
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)   CS_DRY_RUN=true; shift ;;
            --verbose)   CS_VERBOSE=true; shift ;;
            --no-color)  NO_COLOR=1; shift ;;
            --list)      action="list"; shift ;;
            --run)       action="run"; run_target="${2:-}"; shift 2 ;;
            --wizard)    action="wizard"; shift ;;
            --resume)    action="resume"; shift ;;
            --version)   echo "Custom Scripts v${CS_VERSION}"; exit 0 ;;
            --help|-h)   show_help; exit 0 ;; # Assume show_help existe ou remove
            *)           msg_error "Opção desconhecida: $1"; exit 1 ;;
        esac
    done

    check_root
    cs_system_detect

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
            # Implementar run_specific usando registry novo
            cs_registry_scan "${SCRIPT_DIR}"
            local found=""
            for file in "${CS_REGISTRY_FILES[@]}"; do
                if [[ "$file" == *"$run_target"* ]]; then
                    found="$file"
                    break
                fi
            done
            if [[ -n "$found" ]]; then
                cs_runner_reset
                # Wrap single execution in batch logic or run direct? Run direct is fine via runner.
                # Runner exposes internal function, lets make public or use _cs_run_single wrapper
                # Actually, cs_run_batch handles queues. For single run, just pass one file.
                cs_run_batch "$found"
            else
                msg_error "Script não encontrado."
            fi
            ;;
        wizard)
            show_banner
            run_wizard
            ;;
        resume)
            cs_run_resume # Precisa checar se essa função ainda existe em runner.sh?
            # Eu removi cs_run_resume do runner.sh novo?
            # VOU CHECAR O RUNNER.SH NOVO.
            ;;
        menu)
            show_banner
            while true; do
                local choice
                choice=$(cs_ui_menu "Menu Principal" "Escolha uma opção:" \
                    "1" "Wizard (Configuração Inicial)" \
                    "2" "Selecionar Scripts" \
                    "3" "Listar Todos" \
                    "4" "Sair") || exit 0

                case "$choice" in
                    1) run_wizard ;;
                    2) show_menu ;;
                    3) cs_registry_scan "${SCRIPT_DIR}"; cs_registry_filter_env; cs_registry_print; echo ""; read -p "Enter..." ;;
                    4) exit 0 ;;
                esac
            done
            ;;
    esac
}

main "$@"
