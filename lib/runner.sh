#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - Runner / Execution Engine (runner.sh)
#
# Motor de execução transacional com filas priorizadas e relatório consolidado.
# =============================================================================

[[ -n "${_CS_RUNNER_LOADED:-}" ]] && return 0
readonly _CS_RUNNER_LOADED=1

# ── Estado do Runner ─────────────────────────────────────────────────────────
declare -a CS_RUN_RESULTS=() # Formato: "STATUS|TITULO|MSG"
CS_RUN_NEED_REBOOT=false

# ── Executar Script Individual ───────────────────────────────────────────────
_cs_run_single() {
    local file="$1"
    local title="${CS_REGISTRY_TITLE[$file]}"
    local interactive="${CS_REGISTRY_INTERACTIVE[$file]}"
    local reboot="${CS_REGISTRY_REBOOT[$file]}"

    # Header visual
    msg_header "Executando: $title"
    log "INFO" "Iniciando execução de $file ($title)"

    # Verificar existência
    if [[ ! -f "$file" && "${REMOTE_MODE:-}" != "1" ]]; then
        msg_error "Arquivo não encontrado: $file"
        CS_RUN_RESULTS+=("FAIL|$title|Arquivo não encontrado")
        return 1
    fi

    # Dry Run Check
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_dry_run "Executando $file (Simulado)"
        # Se for interativo, podemos mostrar um input mockado
        if [[ "$interactive" == "yes" ]]; then
             msg_dry_run "[Interativo] Usuário veria prompts aqui."
        fi

        # Simular sucesso
        sleep 0.5
        CS_RUN_RESULTS+=("DRY|$title|Simulação OK")
        return 0
    fi

    # Execução Real
    local exit_code=0

    # Se remoto, baixar temp
    local run_file="$file"
    local temp_file=""
    if [[ "${REMOTE_MODE:-}" == "1" && ! -f "$file" ]]; then
        if temp_file=$(cs_fetch_script_to_temp "$file"); then
            run_file="$temp_file"
        else
            CS_RUN_RESULTS+=("FAIL|$title|Falha ao baixar script remoto")
            return 1
        fi
    fi

    # Executar
    # Usamos 'bash' explícito. Passamos as variáveis de ambiente necessárias.
    export CS_CTX_TITLE="$title"

    # Capturar saída se não for interativo?
    # Scripts interativos precisam do TTY. Scripts não interativos poderiam ter log capturado.
    # Por simplicidade, deixamos stdout/stderr fluir, mas poderíamos usar 'tee'.

    if bash "$run_file"; then
        exit_code=0
        msg_success "Concluído: $title"
        CS_RUN_RESULTS+=("OK|$title|Sucesso")
        [[ "$reboot" == "yes" ]] && CS_RUN_NEED_REBOOT=true

        if [[ "${CS_DRY_RUN}" != "true" ]]; then
            cs_state_mark_done "$file" 2>/dev/null || true
        fi
    else
        exit_code=$?
        msg_error "Falha em $title (Exit Code: $exit_code)"
        CS_RUN_RESULTS+=("FAIL|$title|Erro código $exit_code")

        if [[ "${CS_DRY_RUN}" != "true" ]]; then
            cs_state_mark_failed "$file" 2>/dev/null || true
        fi
    fi

    # Cleanup temp
    [[ -n "$temp_file" ]] && rm -f "$temp_file"

    return $exit_code
}

# ── Processador de Fila ──────────────────────────────────────────────────────
cs_run_queue() {
    local queue_name="$1"
    shift
    local files=("$@")

    [[ ${#files[@]} -eq 0 ]] && return 0

    msg_header "Iniciando Fila: $queue_name"

    for file in "${files[@]}"; do
        if ! _cs_run_single "$file"; then
            # Em caso de erro, perguntar (se interativo) ou logar
            if [[ "${CS_DRY_RUN}" != "true" ]]; then
                # Se for erro fatal em script crítico, poderíamos parar.
                # Por padrão, continuamos, mas avisamos.
                if _cs_is_interactive; then
                    if ! cs_ui_yesno "Erro na Execução" "O script '${CS_REGISTRY_TITLE[$file]}' falhou.\nDeseja continuar com os próximos?"; then
                        msg_warn "Execução abortada pelo usuário."
                        return 1 # Abortar fila
                    fi
                fi
            fi
        fi
    done
    return 0
}

# ── Retomar Execução (Resume) ────────────────────────────────────────────────
cs_run_resume() {
    if ! cs_state_has_pending; then
        msg_info "Nenhuma execução pendente para retomar."
        cs_state_cleanup
        return 0
    fi

    msg_header "↻ Retomando execução após reboot"
    cs_state_print_summary

    # Coletar pendentes
    local pending_files=()
    while IFS= read -r file; do
        pending_files+=("$file")
    done < <(cs_state_get_pending)

    if [[ ${#pending_files[@]} -eq 0 ]]; then
        msg_info "Todos os scripts já foram concluídos!"
        cs_state_cleanup
        return 0
    fi

    if _cs_is_interactive; then
        if ! cs_ui_yesno "Resume" "Existem ${#pending_files[@]} scripts pendentes de execução.\nDeseja continuar?"; then
            msg_warn "Execução cancelada. Estado mantido."
            return 0
        fi
    fi

    # Executar pendentes (mantendo ordem original da fila salva)
    # Como a fila salva já foi ordenada por prioridade antes do reboot,
    # apenas executamos sequencialmente.

    msg_header "Continuando fila salva..."

    for file in "${pending_files[@]}"; do
        if ! _cs_run_single "$file"; then
             if [[ "${CS_DRY_RUN}" != "true" ]]; then
                if _cs_is_interactive; then
                    if ! cs_ui_yesno "Erro na Execução" "O script '${CS_REGISTRY_TITLE[$file]}' falhou.\nDeseja continuar?"; then
                        msg_warn "Abortado."
                        return 1
                    fi
                fi
            fi
        fi
        # Marcar como feito no estado? _cs_run_single não faz isso explicitamente.
        # O antigo fazia `cs_state_mark_done`. Precisamos disso?
        # Sim, se cairmos novamente.
        if [[ "${CS_DRY_RUN}" != "true" ]]; then
             cs_state_mark_done "$file" 2>/dev/null || true
        fi
    done

    cs_state_cleanup
    _cs_print_summary
}

# ── Execução em Lote (Orquestrador) ──────────────────────────────────────────
cs_run_batch() {
    local selected_files=("$@")

    # 1. Classificação
    local q_safe_non_interactive=()
    local q_safe_interactive=()
    local q_risk=()

    for file in "${selected_files[@]}"; do
        local interactive="${CS_REGISTRY_INTERACTIVE[$file]}"
        # shellcheck disable=SC2034
        local network="${CS_REGISTRY_NETWORK[$file]}"
        local risk="${CS_REGISTRY_NETWORK[$file]}" # network=risk é o principal risco

        # Lógica de prioridade
        if [[ "$risk" == "risk" ]]; then
            q_risk+=("$file")
        elif [[ "$interactive" == "yes" ]]; then
            q_safe_interactive+=("$file")
        else
            q_safe_non_interactive+=("$file")
        fi
    done

    # 2. Persistência de Estado (Salvar fila completa)
    local final_queue=("${q_safe_non_interactive[@]}" "${q_safe_interactive[@]}" "${q_risk[@]}")
    if [[ "${CS_DRY_RUN}" != "true" ]]; then
        cs_state_save_queue "${final_queue[@]}"
    fi

    # 3. Execução Ordenada

    # Fila 1: Safe Non-Interactive (Rápida, sem perguntas)
    cs_run_queue "Automáticos (Seguros)" "${q_safe_non_interactive[@]}" || return 1

    # Fila 2: Safe Interactive (Pede dados ao usuário)
    cs_run_queue "Interativos" "${q_safe_interactive[@]}" || return 1

    # Fila 3: Risk (Rede/Reboot - deixa por último para não cair conexão antes)
    if [[ ${#q_risk[@]} -gt 0 ]]; then
        if [[ "${CS_ENV_TYPE}" == "SSH" || -n "${SSH_CLIENT:-}" ]]; then
            msg_warn "Scripts de Risco de Rede detectados. Isso pode desconectar sua sessão SSH."
            if _cs_is_interactive; then
                cs_ui_msgbox "Atenção" "Os próximos scripts podem alterar configurações de rede.\nSe a conexão cair, reconecte e verifique os logs."
            fi
            sleep 3
        fi
        cs_run_queue "Risco / Rede" "${q_risk[@]}" || return 1
    fi

    # 3. Relatório Final
    _cs_print_summary
}

# ── Relatório Consolidado ────────────────────────────────────────────────────
_cs_print_summary() {
    local success_count=0
    local fail_count=0
    local dry_count=0

    # Tabela simples
    echo ""
    msg_header "Relatório Final"
    printf "%-10s %-50s %s\n" "STATUS" "SCRIPT" "MSG"
    printf "%-10s %-50s %s\n" "──────" "──────" "───"

    for result in "${CS_RUN_RESULTS[@]}"; do
        IFS='|' read -r status title msg <<< "$result"

        local color="$CS_NC"
        case "$status" in
            OK)   color="$CS_GREEN"; ((success_count++)) ;;
            FAIL) color="$CS_RED";   ((fail_count++)) ;;
            DRY)  color="$CS_MAGENTA"; ((dry_count++)) ;;
        esac

        printf "${color}%-10s${CS_NC} %-50s %s\n" "$status" "${title:0:48}" "$msg"
    done

    echo ""
    if [[ $fail_count -gt 0 ]]; then
        msg_error "Houve $fail_count falha(s)."
    elif [[ $dry_count -gt 0 ]]; then
        msg_dry_run "Simulação concluída."
    else
        msg_success "Todos os scripts executados com sucesso!"
    fi

    if [[ "$CS_RUN_NEED_REBOOT" == "true" ]]; then
        msg_warn "Reinicialização necessária."
        if _cs_is_interactive; then
            if cs_ui_yesno "Reboot" "Deseja reiniciar o sistema agora?"; then
                reboot
            fi
        fi
    fi
}

# ── Reset ────────────────────────────────────────────────────────────────────
cs_runner_reset() {
    CS_RUN_RESULTS=()
    CS_RUN_NEED_REBOOT=false
}
