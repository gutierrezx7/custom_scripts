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
BUILD_DATE="2026-02-09"

# Debug opcional (export CS_DEBUG=1)
if [[ "${CS_DEBUG:-}" == "1" ]]; then
    set -x
    trap '_bs_error "Falha em: ${BASH_SOURCE[0]}:${LINENO} -> ${BASH_COMMAND}"' ERR
fi

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

    # Se estamos executando via pipe (SCRIPT_DIR vazio), não vamos clonar
    # Fonte as bibliotecas diretamente do repositório (modo remoto)
    if [[ -z "$SCRIPT_DIR" ]]; then
        REMOTE_MODE=1
        REMOTE_RAW_BASE="https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main"
        REMOTE_API_BASE="https://api.github.com/repos/gutierrezx7/custom_scripts/git/trees/main?recursive=1"

        _bs_step "Modo remoto detectado — carregando bibliotecas diretamente do GitHub..."

        # Carregar libs na ordem: common, state, registry, runner
        for lib in common state registry runner; do
            _bs_step "Carregando lib/$lib.sh..."
            if ! source <(curl -fsSL "${REMOTE_RAW_BASE}/lib/${lib}.sh"); then
                _bs_error "Falha ao carregar lib/$lib.sh do remoto."
                exit 1
            fi
        done

        return 0
    fi

    # Se o repo já existe em INSTALL_DIR, atualiza e re-executa de lá
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        _bs_step "Atualizando repositório em $INSTALL_DIR..."
        cd "$INSTALL_DIR"

        _bs_step "Conectando ao remoto origin..."
        if git remote show origin &>/dev/null; then
            _bs_step "Buscando alterações remotas..."
            if git fetch --all --prune --quiet 2>/dev/null; then
                # Detectar branch padrão remoto
                remote_default=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | tr -d '\r\n')
                remote_default=${remote_default:-main}
                _bs_step "Sincronizando com origin/${remote_default}..."
                if git reset --hard "origin/${remote_default}" &>/dev/null; then
                    _bs_info "Repositório atualizado para origin/${remote_default}."
                else
                    _bs_warn "Falha ao forçar reset. Tentando pull normal..."
                    git pull --rebase --autostash --quiet 2>/dev/null || _bs_warn "Falha ao atualizar (usando versão local)."
                fi
            else
                _bs_warn "Não foi possível buscar do remoto; usando versão local em $INSTALL_DIR."
            fi
        else
            _bs_warn "Remoto 'origin' não encontrado; usando versão local em $INSTALL_DIR."
        fi

        exec bash "$INSTALL_DIR/setup.sh" "${forward_args[@]}"
    fi

    # Primeira execução: instalar git se necessário e clonar
    _bs_header "Primeira Execução"
    if ! command -v git &>/dev/null; then
        _bs_step "Instalando git..."
        # Tentar atualizar cache (não fatal aqui) e instalar git
        if ! apt-get update -qq 2>/dev/null; then
            _bs_warn "apt-get update falhou — tentando instalar git mesmo assim"
        fi
        if ! apt-get install -y git -qq; then
            _bs_error "Falha ao instalar 'git'. Verifique sua conexão/repositórios."
            exit 1
        fi
    fi

    _bs_step "Clonando repositório para $INSTALL_DIR..."
    if ! git clone "$REPO_URL" "$INSTALL_DIR"; then
        _bs_error "Falha ao clonar repositório ${REPO_URL} para ${INSTALL_DIR}."
        exit 1
    fi
    cd "$INSTALL_DIR"
    chmod +x setup.sh

    _bs_step "Reiniciando a partir do repositório clonado..."
    exec bash "$INSTALL_DIR/setup.sh" "${forward_args[@]}"
}

# Executar bootstrap imediatamente (pode exec e nunca retornar)
bootstrap "$@"

# ── Se chegou aqui, se não estivermos em REMOTE_MODE, carregar libs locais ───
set -u  # Agora é seguro ativar nounset
if [[ "${REMOTE_MODE:-}" != "1" ]]; then
    # ── Carregar bibliotecas locais ─────────────────────────────────────────
    source "${SCRIPT_DIR}/lib/common.sh"
    source "${SCRIPT_DIR}/lib/state.sh"
    source "${SCRIPT_DIR}/lib/registry.sh"
    source "${SCRIPT_DIR}/lib/runner.sh"
fi

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

    if [[ "${REMOTE_MODE:-}" == "1" ]]; then
        echo -e "  ${CS_DIM}Fonte:${CS_NC} ${CS_BOLD}GitHub (raw/main)${CS_NC}  │  ${CS_DIM}Build:${CS_NC} ${CS_BOLD}${BUILD_DATE}${CS_NC}"
    else
        echo -e "  ${CS_DIM}Fonte:${CS_NC} ${CS_BOLD}Local${CS_NC}  │  ${CS_DIM}Build:${CS_NC} ${CS_BOLD}${BUILD_DATE}${CS_NC}"
    fi

    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        echo -e "  ${CS_MAGENTA}${CS_BOLD}DRY-RUN ATIVO - Nenhuma alteração será feita${CS_NC}"
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
    cs_registry_scan "${SCRIPT_DIR}" || true
    cs_registry_filter_env || true

    if [[ ${#CS_REGISTRY_FILES[@]} -eq 0 ]]; then
        msg_error "Nenhum script disponível para este ambiente (${CS_ENV_TYPE})."
        return 0
    fi

    # Calcular dimensões do terminal
    local term_h term_w
    term_h=$(tput lines 2>/dev/null || echo 24)
    term_w=$(tput cols 2>/dev/null || echo 80)

    local box_h=$((term_h - 4)); [[ $box_h -lt 14 ]] && box_h=14
    local box_w=$((term_w - 4)); [[ $box_w -lt 60 ]] && box_w=60
    # list_h precisa de margem para texto (3 linhas) + borders/buttons (~7 linhas) = 10
    local list_h=$((box_h - 10)); [[ $list_h -lt 4 ]] && list_h=4
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
            [[ "$interactive" == "yes" ]] && tags+=" [I]"
            [[ "$reboot" == "yes" ]]      && tags+=" [R]"
            [[ "$network" == "risk" ]]    && tags+=" [!]"

            # Categoria label
            local cat_short="${cat}"
            [[ "$cat" != "$current_cat" ]] && current_cat="$cat"

            local display
            display=$(printf "%-${max_title}s  (%-12s) %s" "${title:0:$max_title}" "$cat_short" "$tags")

            whip_args+=("$idx" "$display" "OFF")
            indexed_files+=("$file")
            ((idx+=1))
        done < <(cs_registry_by_category "$cat")
    done < <(cs_registry_categories)

    # Título dinâmico
    local menu_title="Custom Scripts v${VERSION} [${CS_ENV_TYPE}]"
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        menu_title+=" DRY-RUN"
    fi

    # Mostrar menu
    local choices
    local exit_code=0

    # Captura saída e exit code separadamente
    # Desativa debug temporariamente para não quebrar whiptail
    local debug_on=0
    if [[ "$-" == *x* ]]; then debug_on=1; set +x; fi

    choices=$(whiptail \
        --title "$menu_title" \
        --checklist "Selecione com ESPAÇO, confirme com ENTER:\n\n[I] = Interativo  [R] = Reboot  [!] = Risco de Rede" \
        "$box_h" "$box_w" "$list_h" \
        "${whip_args[@]}" \
        3>&1 1>&2 2>&3) || exit_code=$?

    if [[ "$debug_on" == "1" ]]; then set -x; fi

    if [[ $exit_code -ne 0 ]]; then
        # Se usuário cancelou (1) ou ESC (255), retorna silenciosamente
        # Mas se for erro de geometria ou outro erro, mostra alerta se houver output
        if [[ $exit_code -eq 1 || $exit_code -eq 255 ]]; then
            return 0
        fi

        msg_error "Erro ao abrir menu (exit code: $exit_code):"
        echo "$choices"
        echo ""
        msg_warn "Seu terminal pode estar muito pequeno. Tente maximizar a janela."
        return 0
    fi

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
        echo -e "  - ${title} ${CS_DIM}(${cat})${CS_NC}"
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

    cs_registry_scan "${SCRIPT_DIR}" || true

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
  ${CS_GREEN}--wizard${CS_NC}             Assistente inicial (hostname, IP, scripts)
  ${CS_GREEN}--resume${CS_NC}             Retomar execução interrompida por reboot
  ${CS_GREEN}--list${CS_NC}               Listar todos os scripts disponíveis
  ${CS_GREEN}--dry-run${CS_NC}            Modo simulação (nada é instalado)
  ${CS_GREEN}--run <script>${CS_NC}       Executar script específico (nome parcial)
  ${CS_GREEN}--verbose${CS_NC}            Modo detalhado (debug)
  ${CS_GREEN}--version${CS_NC}            Mostrar versão
  ${CS_GREEN}--help${CS_NC}               Esta mensagem

${CS_BOLD}Exemplos:${CS_NC}
  bash setup.sh                          # Menu interativo
  bash setup.sh --wizard                 # Assistente: hostname + IP + scripts
  bash setup.sh --dry-run                # Testar sem instalar nada
  bash setup.sh --list                   # Ver scripts disponíveis
  bash setup.sh --run docker-install     # Instalar Docker direto
  bash setup.sh --resume                 # Continuar após reboot

${CS_BOLD}Mais informações:${CS_NC}
  https://github.com/gutierrezx7/custom_scripts

EOF
}

# ── Assistente Inicial (Wizard) ──────────────────────────────────────────────
# Fluxo guiado: Hostname → IP Estático → Timezone → Seleção de Scripts
# Coleta tudo primeiro, aplica junto, e faz reboot com resume se necessário
run_wizard() {
    if ! check_command whiptail; then
        msg_step "Instalando whiptail..."
        cs_apt_install whiptail
    fi

    local current_hostname new_hostname
    local set_static_ip="no" static_iface="" static_ip="" static_gw="" static_dns=""
    local current_tz new_tz
    local need_reboot_for_wizard=false

    msg_header "🧙 Assistente de Configuração Inicial"
    echo ""
    echo -e "  ${CS_DIM}Este assistente vai configurar a máquina passo a passo.${CS_NC}"
    echo -e "  ${CS_DIM}Se precisar reiniciar, ele retoma de onde parou.${CS_NC}"
    echo ""

    # ── Passo 1: Hostname ────────────────────────────────────────────────
    msg_header "Passo 1/4 — Hostname"
    current_hostname=$(hostname)
    echo -e "  Hostname atual: ${CS_BOLD}${current_hostname}${CS_NC}"

    new_hostname=$(whiptail --inputbox \
        "Digite o novo hostname para esta máquina:\n\n(Deixe vazio para manter: ${current_hostname})" \
        10 60 "$current_hostname" \
        3>&1 1>&2 2>&3) || new_hostname="$current_hostname"

    [[ -z "$new_hostname" ]] && new_hostname="$current_hostname"

    # ── Passo 2: IP Estático ─────────────────────────────────────────────
    detect_env
    if [[ "$CS_ENV_TYPE" != "LXC" ]]; then
        msg_header "Passo 2/4 — Rede (IP Estático)"

        local default_iface current_ip
        default_iface=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -n1)
        current_ip=$(ip -4 addr show "$default_iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)

        echo -e "  Interface: ${CS_BOLD}${default_iface:-N/A}${CS_NC}"
        echo -e "  IP atual:  ${CS_BOLD}${current_ip:-DHCP}${CS_NC}"

        if whiptail --yesno "Deseja configurar um IP estático?\n\nInterface: ${default_iface}\nIP atual: ${current_ip:-DHCP}" \
            12 60 3>&1 1>&2 2>&3; then

            set_static_ip="yes"

            static_iface=$(whiptail --inputbox "Interface de rede:" 8 60 "$default_iface" \
                3>&1 1>&2 2>&3) || static_iface="$default_iface"

            static_ip=$(whiptail --inputbox "Endereço IP com máscara (ex: 192.168.1.50/24):" 8 60 "${current_ip:-192.168.1.50/24}" \
                3>&1 1>&2 2>&3) || static_ip=""

            local default_gw
            default_gw=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1)
            static_gw=$(whiptail --inputbox "Gateway padrão:" 8 60 "${default_gw:-192.168.1.1}" \
                3>&1 1>&2 2>&3) || static_gw=""

            static_dns=$(whiptail --inputbox "Servidores DNS (separados por vírgula):" 8 60 "1.1.1.1, 8.8.8.8" \
                3>&1 1>&2 2>&3) || static_dns="1.1.1.1, 8.8.8.8"

            if [[ -z "$static_ip" || -z "$static_gw" ]]; then
                msg_warn "Dados incompletos. IP estático será ignorado."
                set_static_ip="no"
            fi
        fi
    else
        msg_step "Passo 2/4 — Rede: Pulado (LXC — configure IP no host/Proxmox)."
    fi

    # ── Passo 3: Timezone ────────────────────────────────────────────────
    msg_header "Passo 3/4 — Fuso Horário"
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "UTC")
    echo -e "  Timezone atual: ${CS_BOLD}${current_tz}${CS_NC}"

    new_tz=$(whiptail --inputbox \
        "Fuso horário (ex: America/Sao_Paulo):\n\n(Atual: ${current_tz})" \
        10 60 "$current_tz" \
        3>&1 1>&2 2>&3) || new_tz="$current_tz"

    [[ -z "$new_tz" ]] && new_tz="$current_tz"

    # ── Passo 4: Selecionar scripts ──────────────────────────────────────
    msg_header "Passo 4/4 — Selecionar Scripts para Instalar"

    cs_registry_scan "${SCRIPT_DIR}" || true
    cs_registry_filter_env || true

    local term_h term_w
    term_h=$(tput lines 2>/dev/null || echo 24)
    term_w=$(tput cols 2>/dev/null || echo 80)
    local box_h=$((term_h - 4)); [[ $box_h -lt 14 ]] && box_h=14
    local box_w=$((term_w - 4)); [[ $box_w -lt 60 ]] && box_w=60
    local list_h=$((box_h - 10)); [[ $list_h -lt 4 ]] && list_h=4
    local max_title=$((box_w - 45)); [[ $max_title -lt 20 ]] && max_title=20

    local whip_args=()
    local -a indexed_files=()
    local idx=0

    while IFS= read -r cat; do
        while IFS= read -r file; do
            local title="${CS_REGISTRY_TITLE[$file]}"
            local tags=""
            [[ "${CS_REGISTRY_INTERACTIVE[$file]}" == "yes" ]] && tags+=" [I]"
            [[ "${CS_REGISTRY_REBOOT[$file]}" == "yes" ]]      && tags+=" [R]"
            [[ "${CS_REGISTRY_NETWORK[$file]}" == "risk" ]]    && tags+=" [!]"

            local display
            display=$(printf "%-${max_title}s  (%-12s) %s" "${title:0:$max_title}" "$cat" "$tags")

            whip_args+=("$idx" "$display" "OFF")
            indexed_files+=("$file")
            ((idx+=1))
        done < <(cs_registry_by_category "$cat")
    done < <(cs_registry_categories)

    local choices=""
    if [[ ${#whip_args[@]} -gt 0 ]]; then
        local exit_code=0
        choices=$(whiptail \
            --title "Wizard - Selecionar Scripts [${CS_ENV_TYPE}]" \
            --checklist "Selecione scripts adicionais para instalar:\n(ESPAÇO = selecionar, ENTER = confirmar, vazio = pular)" \
            "$box_h" "$box_w" "$list_h" \
            "${whip_args[@]}" \
            3>&1 1>&2 2>&3) || exit_code=$?

        if [[ $exit_code -ne 0 && $exit_code -ne 1 && $exit_code -ne 255 ]]; then
            msg_warn "Falha ao abrir menu de seleção (código $exit_code)."
            echo "$choices"
            choices=""
        elif [[ $exit_code -ne 0 ]]; then
            choices=""
        fi
    fi

    local selected_files=()
    if [[ -n "$choices" ]]; then
        choices=$(echo "$choices" | tr -d '"')
        for id in $choices; do
            selected_files+=("${indexed_files[$id]}")
        done
    fi

    # ── Resumo e confirmação ─────────────────────────────────────────────
    clear
    msg_header "Resumo do Assistente"
    echo ""
    echo -e "  ${CS_BOLD}Hostname:${CS_NC}  ${current_hostname} → ${CS_CYAN}${new_hostname}${CS_NC}"

    if [[ "$set_static_ip" == "yes" ]]; then
        echo -e "  ${CS_BOLD}IP:${CS_NC}        ${static_iface}: ${CS_CYAN}${static_ip}${CS_NC}"
        echo -e "  ${CS_BOLD}Gateway:${CS_NC}   ${static_gw}"
        echo -e "  ${CS_BOLD}DNS:${CS_NC}       ${static_dns}"
    else
        echo -e "  ${CS_BOLD}IP:${CS_NC}        ${CS_DIM}(manter atual / DHCP)${CS_NC}"
    fi

    echo -e "  ${CS_BOLD}Timezone:${CS_NC}  ${current_tz} → ${CS_CYAN}${new_tz}${CS_NC}"

    if [[ ${#selected_files[@]} -gt 0 ]]; then
        echo -e "  ${CS_BOLD}Scripts (${#selected_files[@]}):${CS_NC}"
        for file in "${selected_files[@]}"; do
            echo -e "    - ${CS_REGISTRY_TITLE[$file]} ${CS_DIM}(${CS_REGISTRY_CATEGORY[$file]})${CS_NC}"
        done
    else
        echo -e "  ${CS_BOLD}Scripts:${CS_NC}   ${CS_DIM}(nenhum selecionado)${CS_NC}"
    fi
    echo ""

    if ! confirm "Aplicar todas estas configurações?" "y"; then
        msg_info "Assistente cancelado."
        return 0
    fi

    # ── Aplicar configurações ────────────────────────────────────────────
    msg_header "Aplicando Configurações"

    # Hostname
    if [[ "$new_hostname" != "$current_hostname" ]]; then
        msg_step "Alterando hostname para ${new_hostname}..."
        if [[ "${CS_DRY_RUN}" == "true" ]]; then
            msg_dry_run "hostnamectl set-hostname $new_hostname"
        else
            hostnamectl set-hostname "$new_hostname"
            sed -i "s/127.0.1.1.*${current_hostname}/127.0.1.1\t${new_hostname}/g" /etc/hosts 2>/dev/null || true
            # Garantir que existe a entrada
            if ! grep -q "127.0.1.1" /etc/hosts; then
                echo -e "127.0.1.1\t${new_hostname}" >> /etc/hosts
            fi
        fi
        msg_success "Hostname: ${new_hostname}"
    fi

    # Timezone
    if [[ "$new_tz" != "$current_tz" ]]; then
        msg_step "Configurando timezone: ${new_tz}..."
        cs_run timedatectl set-timezone "$new_tz" 2>/dev/null || true
        msg_success "Timezone: ${new_tz}"
    fi

    # IP Estático
    if [[ "$set_static_ip" == "yes" ]]; then
        msg_step "Configurando IP estático..."
        local netplan_file="/etc/netplan/99-custom-scripts.yaml"

        if [[ "${CS_DRY_RUN}" == "true" ]]; then
            msg_dry_run "Criaria $netplan_file com IP $static_ip"
        else
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
            need_reboot_for_wizard=true
        fi
    fi

    # Atualizar pacotes básicos
    msg_step "Atualizando sistema e instalando ferramentas básicas..."
    cs_run apt-get update -qq
    cs_run apt-get upgrade -y
    cs_run apt-get install -y curl wget git htop unzip nano

    msg_success "Sistema base configurado."

    # ── Executar scripts selecionados ────────────────────────────────────
    if [[ ${#selected_files[@]} -gt 0 ]]; then
        # Se precisa reiniciar por causa do IP antes de rodar scripts,
        # salvar scripts como pendentes para resume
        if [[ "$need_reboot_for_wizard" == "true" && "${CS_DRY_RUN}" != "true" ]]; then
            msg_header "Reboot necessário antes de instalar scripts"
            msg_info "A mudança de IP será aplicada no próximo boot."
            msg_info "Os ${#selected_files[@]} scripts serão instalados automaticamente após o reboot."

            # Salvar fila para resume
            cs_state_save_queue "${selected_files[@]}"
            cs_state_reboot_and_resume "${SCRIPT_DIR}"
            exit 0
        fi

        # Sem reboot pendente — executar normalmente
        cs_runner_reset
        cs_run_batch "${selected_files[@]}"
    else
        # Sem scripts, mas pode precisar de reboot (hostname/IP)
        if [[ "$need_reboot_for_wizard" == "true" || "$new_hostname" != "$current_hostname" ]]; then
            echo ""
            msg_warn "Recomendado reiniciar para aplicar hostname/rede."
            if confirm "Reiniciar agora?" "y"; then
                reboot
            fi
        fi
    fi

    echo ""
    msg_success "Assistente concluído! 🎉"
}

# ── Retomar execução pendente ────────────────────────────────────────────────
run_resume() {
    show_banner

    # Carregar registry para ter os metadados disponíveis
    cs_registry_scan "${SCRIPT_DIR}"

    cs_runner_reset
    cs_run_resume
}

# ── Menu principal (com opção de wizard) ─────────────────────────────────────
show_main_menu() {
    if ! check_command whiptail; then
        msg_step "Instalando whiptail..."
        cs_apt_install whiptail
    fi

    # Verificar se há execução pendente
    if cs_state_has_pending; then
        msg_warn "Há uma execução pendente de uma sessão anterior!"
        cs_registry_scan "${SCRIPT_DIR}"
        cs_state_print_summary

        if confirm "Retomar execução pendente?" "y"; then
            run_resume
            return
        else
            msg_info "Descartando estado anterior..."
            cs_state_cleanup
        fi
    fi

    local term_h term_w
    term_h=$(tput lines 2>/dev/null || echo 24)
    term_w=$(tput cols 2>/dev/null || echo 80)
    local box_h=14; [[ $term_h -gt 20 ]] && box_h=16
    local box_w=$((term_w - 10)); [[ $box_w -lt 60 ]] && box_w=60; [[ $box_w -gt 80 ]] && box_w=80

    # Garantir título do menu mesmo que não tenha sido inicializado globalmente
    local menu_title
    menu_title="Custom Scripts v${VERSION} [${CS_ENV_TYPE}]"
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        menu_title+=" DRY-RUN"
    fi

    local choice
    local debug_on=0
    if [[ "$-" == *x* ]]; then debug_on=1; set +x; fi

    choice=$(whiptail \
        --title "$menu_title" \
        --menu "Escolha uma opção:" \
        "$box_h" "$box_w" 6 \
        "1" "Wizard - Assistente inicial (hostname, IP, timezone)" \
        "2" "Selecionar scripts (menu)" \
        "3" "Listar scripts disponíveis" \
        "4" "Sair" \
        3>&1 1>&2 2>&3) || choice="4"

    if [[ "$debug_on" == "1" ]]; then set -x; fi

    case "$choice" in
        1) run_wizard ;;
        2) show_menu ;;
        3)
            cs_registry_scan "${SCRIPT_DIR}"
            cs_registry_filter_env
            cs_registry_print
            ;;
        4)
            msg_info "Até a próxima! 👋"
            exit 0
            ;;
    esac
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
            --wizard)    action="wizard"; shift ;;
            --resume)    action="resume"; shift ;;
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
        wizard)
            show_banner
            run_wizard
            ;;
        resume)
            run_resume
            ;;
        menu)
            show_banner
            while true; do
                show_main_menu
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
