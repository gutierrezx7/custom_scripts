#!/bin/bash
# =============================================================================
# Custom Scripts - Mock System Library (mock_sys.sh)
#
# Intercepta comandos de sistema para testes e dry-run avançado.
# =============================================================================

export MOCK_LOG_FILE="${MOCK_LOG_FILE:-/tmp/cs_mock_sys.log}"

_mock_log() {
    local cmd="$1"
    shift
    local args="$*"
    echo "[MOCK] $cmd $args" >> "$MOCK_LOG_FILE"
}

# ── Mock: apt-get ────────────────────────────────────────────────────────────
apt-get() {
    _mock_log "apt-get" "$@"
    if [[ "${MOCK_FAIL_APT}" == "true" ]]; then
        echo "Simulating apt-get failure" >&2
        return 1
    fi
    return 0
}

# ── Mock: systemctl ──────────────────────────────────────────────────────────
systemctl() {
    _mock_log "systemctl" "$@"
    # Se for check de active, talvez queira simular status
    if [[ "$1" == "is-active" ]]; then
        if [[ "${MOCK_SERVICE_ACTIVE}" == "true" ]]; then
            return 0
        else
            return 1 # Inactive
        fi
    fi
    return 0
}

# ── Mock: ip ─────────────────────────────────────────────────────────────────
ip() {
    _mock_log "ip" "$@"
    # Se for comando de leitura, precisamos retornar algo sensato
    if [[ "$1" == "route" ]]; then
        echo "default via 192.168.1.1 dev eth0 proto dhcp src 192.168.1.100 metric 100"
    elif [[ "$1" == "-4" && "$2" == "addr" ]]; then
        echo "    inet 192.168.1.100/24 brd 192.168.1.255 scope global dynamic eth0"
    fi
    return 0
}

# ── Mock: hostnamectl ────────────────────────────────────────────────────────
hostnamectl() {
    _mock_log "hostnamectl" "$@"
    if [[ "$1" == "set-hostname" ]]; then
        export MOCK_HOSTNAME="$2"
    fi
    return 0
}

# ── Mock: timedatectl ────────────────────────────────────────────────────────
timedatectl() {
    _mock_log "timedatectl" "$@"
    return 0
}

# ── Mock: reboot ─────────────────────────────────────────────────────────────
reboot() {
    _mock_log "reboot" "$@"
    echo "Simulating REBOOT..."
    exit 0
}

# ── Mock: curl / wget / git ──────────────────────────────────────────────────
curl() {
    _mock_log "curl" "$@"
    # Se for download para arquivo temporário, criar arquivo vazio
    local output=""
    local prev=""
    for arg in "$@"; do
        if [[ "$prev" == "-o" ]]; then output="$arg"; fi
        prev="$arg"
    done

    if [[ -n "$output" ]]; then
        touch "$output"
    fi
    return 0
}

wget() {
    _mock_log "wget" "$@"
    return 0
}

git() {
    _mock_log "git" "$@"
    if [[ "$1" == "clone" && -n "$3" ]]; then
        mkdir -p "$3"
    fi
    return 0
}

# ── Mock: whiptail ───────────────────────────────────────────────────────────
# O whiptail é complicado pois precisa interagir com stdin/stdout.
# Se MOCK_INPUT_FILE estiver definido, lê as respostas dele.
whiptail() {
    local args=("$@")
    _mock_log "whiptail" "${args[*]}"

    # Simplesmente retorna sucesso se não precisarmos simular input complexo
    # Se o script espera output (ex: inputbox), precisamos imprimir algo.

    local type=""
    for arg in "${args[@]}"; do
        case "$arg" in
            --yesno) type="yesno" ;;
            --msgbox) type="msgbox" ;;
            --inputbox) type="inputbox" ;;
            --menu) type="menu" ;;
            --checklist) type="checklist" ;;
        esac
    done

    # Ler resposta pré-definida de arquivo ou env
    # Formato do arquivo: uma resposta por linha
    local response=""
    if [[ -f "${MOCK_INPUT_FILE:-}" ]]; then
        response=$(head -1 "$MOCK_INPUT_FILE")
        echo "[MOCK-DEBUG] Whiptail consuming: '$response'" >> "$MOCK_LOG_FILE"
        # Remove a linha lida (simula consumo)
        tail -n +2 "$MOCK_INPUT_FILE" > "$MOCK_INPUT_FILE.tmp" && mv "$MOCK_INPUT_FILE.tmp" "$MOCK_INPUT_FILE"
    fi

    # Se inputbox/menu/checklist, imprimir resposta no stderr (whiptail padrão)
    if [[ "$type" == "inputbox" || "$type" == "menu" || "$type" == "checklist" ]]; then
        echo "${response:-}" >&2
    fi

    # Yes/No retorna exit code
    if [[ "$type" == "yesno" ]]; then
        if [[ "${response,,}" == "no" || "${response,,}" == "n" ]]; then
            return 1
        fi
        return 0
    fi

    return 0
}

# ── Exportar Funções para Subshells ──────────────────────────────────────────
export -f _mock_log
export -f apt-get
export -f systemctl
export -f ip
export -f hostnamectl
export -f timedatectl
export -f reboot
export -f curl
export -f wget
export -f git
export -f whiptail

# ── Inicialização ────────────────────────────────────────────────────────────
echo "Mock System Loaded. Log: $MOCK_LOG_FILE"
