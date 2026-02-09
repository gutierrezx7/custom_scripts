#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - Shared Library (common.sh)
# Biblioteca compartilhada com funções utilitárias reutilizáveis.
# Source este arquivo no início de qualquer script do projeto.
#
# Uso:  source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
#   ou: LIB_DIR já definido pelo setup.sh antes do source.
# =============================================================================

# Guard contra double-source
[[ -n "${_CS_COMMON_LOADED:-}" ]] && return 0
readonly _CS_COMMON_LOADED=1

# ── Cores ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    readonly CS_RED='\033[0;31m'
    readonly CS_GREEN='\033[0;32m'
    readonly CS_YELLOW='\033[1;33m'
    readonly CS_BLUE='\033[0;34m'
    readonly CS_CYAN='\033[0;36m'
    readonly CS_MAGENTA='\033[0;35m'
    readonly CS_BOLD='\033[1m'
    readonly CS_DIM='\033[2m'
    readonly CS_NC='\033[0m'
else
    readonly CS_RED='' CS_GREEN='' CS_YELLOW='' CS_BLUE=''
    readonly CS_CYAN='' CS_MAGENTA='' CS_BOLD='' CS_DIM='' CS_NC=''
fi

# ── Aliases de cor legados (backward-compatible) ─────────────────────────────
RED="${CS_RED}"; GREEN="${CS_GREEN}"; YELLOW="${CS_YELLOW}"
BLUE="${CS_BLUE}"; CYAN="${CS_CYAN}"; NC="${CS_NC}"

# ── Estado global ────────────────────────────────────────────────────────────
CS_DRY_RUN="${CS_DRY_RUN:-false}"
CS_VERBOSE="${CS_VERBOSE:-false}"
CS_LOG_FILE="${CS_LOG_FILE:-/var/log/custom_scripts.log}"

# ── Funções de mensagem ─────────────────────────────────────────────────────
msg_info()    { echo -e "${CS_GREEN}[INFO]${CS_NC}    $1"; }
msg_warn()    { echo -e "${CS_YELLOW}[AVISO]${CS_NC}   $1"; }
msg_error()   { echo -e "${CS_RED}[ERRO]${CS_NC}    $1" >&2; }
msg_header()  { echo -e "\n${CS_BLUE}${CS_BOLD}━━━ $1 ━━━${CS_NC}"; }
msg_success() { echo -e "${CS_GREEN}${CS_BOLD}[✔]${CS_NC} $1"; }
msg_step()    { echo -e "${CS_CYAN}  ➜${CS_NC} $1"; }
msg_debug()   {
    [[ "${CS_VERBOSE}" == "true" ]] && echo -e "${CS_DIM}[DEBUG]${CS_NC}  $1"
}
msg_dry_run() {
    echo -e "${CS_MAGENTA}[DRY-RUN]${CS_NC} $1"
}

# ── Logging ──────────────────────────────────────────────────────────────────
log() {
    local level="$1"; shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "${CS_LOG_FILE}" 2>/dev/null || true
}

# ── Execução com Dry-Run ────────────────────────────────────────────────────
# Wrapper: executa o comando ou apenas exibe o que faria.
# Uso: cs_run apt-get install -y nginx
cs_run() {
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_dry_run "$ $*"
        log "DRY-RUN" "$*"
        return 0
    else
        msg_debug "$ $*"
        log "EXEC" "$*"
        "$@"
    fi
}

# ── Verificações comuns ──────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "Este script precisa ser executado como root (sudo)."
        exit 1
    fi
}

check_internet() {
    msg_step "Verificando conexão com a internet..."
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null && \
       ! ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
        msg_error "Sem conexão com a internet."
        exit 1
    fi
    msg_debug "Conectividade OK."
}

check_command() {
    command -v "$1" &>/dev/null
}

# ── Detecção de Ambiente ────────────────────────────────────────────────────
detect_env() {
    if [[ -n "${CS_ENV_TYPE:-}" ]]; then return; fi

    if check_command systemd-detect-virt; then
        local virt
        virt=$(systemd-detect-virt 2>/dev/null || echo "unknown")
        case "$virt" in
            lxc)   CS_ENV_TYPE="LXC" ;;
            none)  CS_ENV_TYPE="Bare-Metal" ;;
            *)     CS_ENV_TYPE="VM" ;;
        esac
    else
        CS_ENV_TYPE="Desconhecido"
    fi
    export CS_ENV_TYPE
}

# ── Detecção de Distro ──────────────────────────────────────────────────────
detect_distro() {
    if [[ -n "${CS_DISTRO:-}" ]]; then return; fi

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        CS_DISTRO="${ID}"
        CS_DISTRO_VERSION="${VERSION_ID:-unknown}"
        CS_DISTRO_PRETTY="${PRETTY_NAME:-$ID}"
    else
        CS_DISTRO="unknown"
        CS_DISTRO_VERSION="unknown"
        CS_DISTRO_PRETTY="Unknown"
    fi
    export CS_DISTRO CS_DISTRO_VERSION CS_DISTRO_PRETTY
}

# ── Instalação de pacotes (APT) ─────────────────────────────────────────────
cs_apt_install() {
    cs_run apt-get update -qq
    cs_run apt-get install -y "$@"
}

# ── Verificar dependências (lista) ──────────────────────────────────────────
check_dependencies() {
    local missing=()
    for dep in "$@"; do
        if ! check_command "$dep"; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        msg_warn "Dependências faltando: ${missing[*]}"
        msg_step "Instalando dependências..."
        cs_apt_install "${missing[@]}"
    fi
}

# ── Spinner para operações longas ────────────────────────────────────────────
spinner() {
    local pid=$1
    local message="${2:-Aguarde...}"
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CS_CYAN}  %s${CS_NC} %s" "${chars:$i:1}" "$message"
        i=$(( (i + 1) % ${#chars} ))
        sleep 0.1
    done
    printf "\r\033[K" # limpa a linha
}

# ── Confirmação do usuário ───────────────────────────────────────────────────
confirm() {
    local message="${1:-Deseja continuar?}"
    local default="${2:-n}"

    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_dry_run "Confirmação pulada: $message"
        return 0
    fi

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="${message} [Y/n]: "
    else
        prompt="${message} [y/N]: "
    fi

    read -rp "$(echo -e "${CS_YELLOW}${prompt}${CS_NC}")" answer
    answer="${answer:-$default}"

    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

# ── Trap para cleanup ───────────────────────────────────────────────────────
_cs_cleanup_functions=()

cs_on_exit() {
    _cs_cleanup_functions+=("$1")
}

_cs_run_cleanup() {
    for fn in "${_cs_cleanup_functions[@]}"; do
        "$fn" 2>/dev/null || true
    done
}

trap _cs_run_cleanup EXIT INT TERM

# ── Parse de argumentos comuns (--dry-run, --verbose, --help) ────────────────
cs_parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)  CS_DRY_RUN=true; shift ;;
            --verbose)  CS_VERBOSE=true; shift ;;
            --no-color) NO_COLOR=1; shift ;;
            *)          shift ;;
        esac
    done
}
