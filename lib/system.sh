#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - System Detection Library (system.sh)
#
# Responsável por detectar o ambiente de execução com precisão.
# Identifica: OS, Versão, Virtualização (LXC/VM/Docker), Arquitetura e Recursos.
#
# Uso: source lib/system.sh && cs_system_detect
# =============================================================================

# Evitar loading duplicado
[[ -n "${_CS_SYSTEM_LOADED:-}" ]] && return 0
readonly _CS_SYSTEM_LOADED=1

# ── Variáveis Globais Exportadas ─────────────────────────────────────────────
# Preenchidas por cs_system_detect
export CS_OS=""              # ex: debian, ubuntu, alpine
export CS_OS_VERSION=""      # ex: 12, 22.04
export CS_OS_CODENAME=""     # ex: bookworm, jammy
export CS_OS_PRETTY=""       # ex: Debian GNU/Linux 12 (bookworm)
export CS_ARCH=""            # ex: amd64, arm64
export CS_VIRT_TYPE=""       # ex: lxc, kvm, docker, metal, unknown
export CS_RAM_MB=0           # ex: 4096
export CS_DISK_GB=0          # ex: 20

# ── Detecção de Sistema Operacional ──────────────────────────────────────────
_cs_detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        CS_OS="${ID:-unknown}"
        CS_OS_VERSION="${VERSION_ID:-unknown}"
        CS_OS_CODENAME="${VERSION_CODENAME:-unknown}"
        CS_OS_PRETTY="${PRETTY_NAME:-$ID $VERSION_ID}"
    elif [[ -f /etc/lsb-release ]]; then
        # shellcheck source=/dev/null
        source /etc/lsb-release
        CS_OS="${DISTRIB_ID,,}"
        CS_OS_VERSION="${DISTRIB_RELEASE}"
        CS_OS_CODENAME="${DISTRIB_CODENAME}"
        CS_OS_PRETTY="${DISTRIB_DESCRIPTION}"
    else
        CS_OS="unknown"
        CS_OS_VERSION="unknown"
    fi

    # Normalizar Ubuntu/Debian
    [[ "$CS_OS" == "ubuntu" ]] && CS_OS="ubuntu"
    [[ "$CS_OS" == "debian" ]] && CS_OS="debian"
    return 0
}

# ── Detecção de Virtualização ────────────────────────────────────────────────
_cs_detect_virt() {
    # 1. Tentar systemd-detect-virt (mais confiável)
    if command -v systemd-detect-virt &>/dev/null; then
        local virt
        virt=$(systemd-detect-virt -v 2>/dev/null || echo "")
        if [[ -z "$virt" || "$virt" == "none" ]]; then
            # Tentar flag container (-c) e vm (-v) separadamente
            if systemd-detect-virt -c -q; then
                virt=$(systemd-detect-virt -c)
            elif systemd-detect-virt -v -q; then
                virt=$(systemd-detect-virt -v)
            else
                virt="metal"
            fi
        fi
        CS_VIRT_TYPE="$virt"
    else
        # 2. Fallback: Verificar /.dockerenv
        if [[ -f /.dockerenv ]]; then
            CS_VIRT_TYPE="docker"
        # 3. Fallback: Verificar /proc/1/cgroup
        elif grep -qE 'docker|lxc|kubepods' /proc/1/cgroup 2>/dev/null; then
            if grep -q lxc /proc/1/cgroup; then
                CS_VIRT_TYPE="lxc"
            else
                CS_VIRT_TYPE="docker" # ou k8s, assumindo container
            fi
        else
            CS_VIRT_TYPE="unknown" # Pode ser VM ou Metal sem systemd
        fi
    fi

    # Normalização
    case "$CS_VIRT_TYPE" in
        lxc|lxc-libvirt) CS_VIRT_TYPE="lxc" ;;
        kvm|qemu|bochs)  CS_VIRT_TYPE="vm" ;;
        docker|podman)   CS_VIRT_TYPE="docker" ;;
        none|metal)      CS_VIRT_TYPE="metal" ;;
        *)               CS_VIRT_TYPE="vm" ;; # Default seguro: tratar como VM se desconhecido
    esac
}

# ── Detecção de Arquitetura ──────────────────────────────────────────────────
_cs_detect_arch() {
    CS_ARCH=$(uname -m)
    case "$CS_ARCH" in
        x86_64)  CS_ARCH="amd64" ;;
        aarch64) CS_ARCH="arm64" ;;
        armv7l)  CS_ARCH="armhf" ;;
    esac
}

# ── Detecção de Recursos (RAM/Disk) ──────────────────────────────────────────
_cs_detect_resources() {
    # RAM em MB
    if [[ -r /proc/meminfo ]]; then
        local mem_kb
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        CS_RAM_MB=$((mem_kb / 1024))
    fi

    # Disco Root em GB
    if command -v df &>/dev/null; then
        local disk_kb
        disk_kb=$(df -k / | tail -1 | awk '{print $2}')
        CS_DISK_GB=$((disk_kb / 1024 / 1024))
    fi
}

# ── Função Principal Pública ─────────────────────────────────────────────────
cs_system_detect() {
    _cs_detect_os
    _cs_detect_virt
    _cs_detect_arch
    _cs_detect_resources

    # Log de debug se ativo
    if [[ "${CS_VERBOSE:-}" == "true" ]]; then
        echo "DEBUG: OS=$CS_OS Ver=$CS_OS_VERSION Arch=$CS_ARCH Virt=$CS_VIRT_TYPE RAM=${CS_RAM_MB}MB Disk=${CS_DISK_GB}GB"
    fi
}

# ── Verificadores de Compatibilidade ─────────────────────────────────────────

# Verifica se o script suporta o ambiente atual
# Uso: cs_system_check_compatibility "lxc,vm" "debian,ubuntu"
cs_system_check_compatibility() {
    local supported_virt="${1:-all}"
    local supported_os="${2:-all}"

    # 1. Verificar Virtualização
    if [[ "$supported_virt" != "all" ]]; then
        local virt_ok=false
        # Iterar sobre lista separada por vírgula
        IFS=',' read -ra VIRTS <<< "$supported_virt"
        for v in "${VIRTS[@]}"; do
            v=$(echo "$v" | tr -d ' ')
            if [[ "$v" == "$CS_VIRT_TYPE" ]]; then
                virt_ok=true
                break
            fi
            # 'vm' pode englobar metal em alguns contextos, mas vamos ser estritos
            # Se script pede 'vm', e estamos em 'metal', geralmente ok?
            # NÃO, melhor ser explícito.
        done

        if [[ "$virt_ok" == "false" ]]; then
            return 1 # Incompatível
        fi
    fi

    # 2. Verificar OS
    if [[ "$supported_os" != "all" ]]; then
        local os_ok=false
        IFS=',' read -ra OSS <<< "$supported_os"
        for o in "${OSS[@]}"; do
            o=$(echo "$o" | tr -d ' ')
            if [[ "$CS_OS" == "$o" ]]; then
                os_ok=true
                break
            fi
        done

        if [[ "$os_ok" == "false" ]]; then
            return 2 # OS Incompatível
        fi
    fi

    return 0 # Compatível
}

# Executa auto-detecção ao carregar (se não estiver em teste unitário)
if [[ "${CS_TEST_MODE:-}" != "true" ]]; then
    cs_system_detect
fi
