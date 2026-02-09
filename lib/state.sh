#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - State Persistence Engine (state.sh)
#
# Permite salvar o progresso da execução em lote e retomar após reboot.
#
# Como funciona:
#   1. Antes de executar, salva a fila completa em STATE_FILE
#   2. A cada script concluído, marca como "done" no arquivo
#   3. Se reboot for necessário, instala serviço systemd que re-executa
#   4. No próximo boot, setup.sh detecta --resume e continua de onde parou
#   5. Ao finalizar tudo, remove o serviço e limpa o estado
#
# Arquivo de estado: /var/lib/custom_scripts/state
# Serviço systemd:  /etc/systemd/system/custom-scripts-resume.service
# =============================================================================

[[ -n "${_CS_STATE_LOADED:-}" ]] && return 0
readonly _CS_STATE_LOADED=1

# ── Caminhos ─────────────────────────────────────────────────────────────────
CS_STATE_DIR="${CS_STATE_DIR:-/var/lib/custom_scripts}"
CS_STATE_FILE="${CS_STATE_DIR}/state"
CS_STATE_WIZARD="${CS_STATE_DIR}/wizard"
CS_RESUME_SERVICE="custom-scripts-resume"
CS_RESUME_SERVICE_FILE="${CS_RESUME_SERVICE_FILE:-/etc/systemd/system/${CS_RESUME_SERVICE}.service}"

# ── Criar diretório de estado ────────────────────────────────────────────────
_cs_state_init() {
    mkdir -p "$CS_STATE_DIR"
}

# Atualiza o status de um arquivo no STATE_FILE de forma atômica
_cs_state_update_status() {
    local file_path="$1"
    local from_status="$2"
    local to_status="$3"
    [[ ! -f "$CS_STATE_FILE" ]] && return

    awk -F'|' -v f="$file_path" -v fr="$from_status" -v to="$to_status" 'BEGIN{OFS=FS} {if($1==fr && $2==f) $1=to; print}' "$CS_STATE_FILE" > "${CS_STATE_FILE}.tmp" && mv "${CS_STATE_FILE}.tmp" "$CS_STATE_FILE"
}

# ── Verificar se existe estado pendente ──────────────────────────────────────
cs_state_has_pending() {
    [[ -f "$CS_STATE_FILE" ]] && grep -q "^PENDING|" "$CS_STATE_FILE" 2>/dev/null
}

# ── Verificar se existe dados do wizard ──────────────────────────────────────
cs_state_has_wizard() {
    [[ -f "$CS_STATE_WIZARD" ]]
}

# ── Salvar fila de execução ──────────────────────────────────────────────────
# Formato: STATUS|FILE_PATH
# STATUS: PENDING, RUNNING, DONE, FAILED
cs_state_save_queue() {
    local files=("$@")
    _cs_state_init

    # Limpar estado anterior
    > "$CS_STATE_FILE"

    for file in "${files[@]}"; do
        echo "PENDING|${file}" >> "$CS_STATE_FILE"
    done

    msg_debug "Estado salvo: ${#files[@]} scripts na fila."
}

# ── Marcar script como concluído ─────────────────────────────────────────────
cs_state_mark_done() {
    local file="$1"
    [[ ! -f "$CS_STATE_FILE" ]] && return

    # Substitui PENDING|file ou RUNNING|file por DONE|file (atômico)
    _cs_state_update_status "$file" "PENDING" "DONE"
    _cs_state_update_status "$file" "RUNNING" "DONE"
}

# ── Marcar script como em execução ───────────────────────────────────────────
cs_state_mark_running() {
    local file="$1"
    [[ ! -f "$CS_STATE_FILE" ]] && return

    # Marca apenas a entrada PENDING|file → RUNNING|file
    _cs_state_update_status "$file" "PENDING" "RUNNING"
}

# ── Marcar script como falho ────────────────────────────────────────────────
cs_state_mark_failed() {
    local file="$1"
    [[ ! -f "$CS_STATE_FILE" ]] && return

    # Marca PENDING/RUNNING → FAILED (atômico)
    _cs_state_update_status "$file" "PENDING" "FAILED"
    _cs_state_update_status "$file" "RUNNING" "FAILED"
}

# ── Obter scripts pendentes ─────────────────────────────────────────────────
cs_state_get_pending() {
    [[ ! -f "$CS_STATE_FILE" ]] && return

    # RUNNING também conta como pendente (interrompido no meio)
    grep -E "^(PENDING|RUNNING)\|" "$CS_STATE_FILE" 2>/dev/null | cut -d'|' -f2
}

# ── Obter scripts concluídos ────────────────────────────────────────────────
cs_state_get_done() {
    [[ ! -f "$CS_STATE_FILE" ]] && return

    grep "^DONE|" "$CS_STATE_FILE" 2>/dev/null | cut -d'|' -f2
}

# ── Obter scripts falhos ────────────────────────────────────────────────────
cs_state_get_failed() {
    [[ ! -f "$CS_STATE_FILE" ]] && return

    grep "^FAILED|" "$CS_STATE_FILE" 2>/dev/null | cut -d'|' -f2
}

# ── Imprimir resumo do estado atual ──────────────────────────────────────────
cs_state_print_summary() {
    [[ ! -f "$CS_STATE_FILE" ]] && return

    local done_count pending_count failed_count
    done_count=$(grep -c "^DONE|" "$CS_STATE_FILE" 2>/dev/null || echo 0)
    pending_count=$(grep -cE "^(PENDING|RUNNING)\|" "$CS_STATE_FILE" 2>/dev/null || echo 0)
    failed_count=$(grep -c "^FAILED|" "$CS_STATE_FILE" 2>/dev/null || echo 0)
    local total=$((done_count + pending_count + failed_count))

    echo ""
    echo -e "  ${CS_BOLD}Progresso:${CS_NC} ${done_count}/${total} concluídos"
    if [[ $failed_count -gt 0 ]]; then
        echo -e "  ${CS_RED}Falhas: ${failed_count}${CS_NC}"
    fi

    if [[ $done_count -gt 0 ]]; then
        echo -e "  ${CS_GREEN}✔ Já concluídos:${CS_NC}"
        while IFS= read -r file; do
            local title="${CS_REGISTRY_TITLE[$file]:-$(basename "$file")}"
            echo -e "    ${CS_DIM}•${CS_NC} ${title}"
        done < <(cs_state_get_done)
    fi

    if [[ $pending_count -gt 0 ]]; then
        echo -e "  ${CS_YELLOW}⏳ Pendentes:${CS_NC}"
        while IFS= read -r file; do
            local title="${CS_REGISTRY_TITLE[$file]:-$(basename "$file")}"
            echo -e "    ${CS_CYAN}•${CS_NC} ${title}"
        done < <(cs_state_get_pending)
    fi
    echo ""
}

# ── Salvar dados do wizard (hostname, IP, etc.) ─────────────────────────────
cs_state_save_wizard() {
    _cs_state_init
    # Aceita pares KEY=VALUE como argumentos
    > "$CS_STATE_WIZARD"
    for kv in "$@"; do
        echo "$kv" >> "$CS_STATE_WIZARD"
    done
}

# ── Ler valor do wizard ─────────────────────────────────────────────────────
cs_state_get_wizard() {
    local key="$1"
    [[ ! -f "$CS_STATE_WIZARD" ]] && return

    grep "^${key}=" "$CS_STATE_WIZARD" 2>/dev/null | head -1 | cut -d'=' -f2-
}

# ── Instalar serviço de resume (systemd) ────────────────────────────────────
# Cria um serviço oneshot que executa setup.sh --resume no próximo boot
cs_state_install_resume_service() {
    local install_dir="${1:-/opt/custom_scripts}"

    msg_step "Instalando serviço de retomada pós-reboot..."

    # Verificar se systemd está disponível
    if ! command -v systemctl &>/dev/null || [[ ! -d "/run/systemd/system" ]]; then
        msg_warn "systemd não detectado; não é possível instalar serviço de retomada. Estado salvo em ${CS_STATE_FILE}."
        return 0
    fi

    cat > "$CS_RESUME_SERVICE_FILE" << EOF
[Unit]
Description=Custom Scripts - Retomar execução após reboot
After=network-online.target
Wants=network-online.target
ConditionPathExists=${CS_STATE_FILE}

[Service]
Type=oneshot
ExecStart=/usr/bin/bash ${install_dir}/setup.sh --resume
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${CS_RESUME_SERVICE}" 2>/dev/null

    msg_debug "Serviço ${CS_RESUME_SERVICE} instalado e habilitado."
}

# ── Remover serviço de resume ────────────────────────────────────────────────
cs_state_remove_resume_service() {
    if [[ -f "$CS_RESUME_SERVICE_FILE" ]]; then
        msg_step "Removendo serviço de retomada..."
        systemctl disable "${CS_RESUME_SERVICE}" 2>/dev/null || true
        rm -f "$CS_RESUME_SERVICE_FILE"
        systemctl daemon-reload
    fi
}

# ── Limpar todo o estado ─────────────────────────────────────────────────────
cs_state_cleanup() {
    cs_state_remove_resume_service
    rm -f "$CS_STATE_FILE" "$CS_STATE_WIZARD"
    msg_debug "Estado limpo."
}

# ── Reboot inteligente com resume ────────────────────────────────────────────
# Instala o serviço de resume e reinicia a máquina
cs_state_reboot_and_resume() {
    local install_dir="${1:-/opt/custom_scripts}"

    msg_header "↻ Reinicialização Necessária"
    echo ""

    cs_state_print_summary

    cs_state_install_resume_service "$install_dir"

    echo -e "  ${CS_YELLOW}${CS_BOLD}O sistema irá reiniciar agora.${CS_NC}"
    echo -e "  ${CS_DIM}Após o boot, a execução continuará automaticamente no TTY1.${CS_NC}"
    echo -e "  ${CS_DIM}Você também pode reconectar via SSH e rodar: bash setup.sh --resume${CS_NC}"
    echo ""

    sleep 3
    reboot
}
