#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - Runner / Execution Engine (runner.sh)
#
# Motor de execução inteligente com suporte a:
#   - Dry-run (simulação sem alterações)
#   - Execução em lote com filas priorizadas
#   - Persistência de estado (retomar após reboot)
#   - Logging e relatório final
#   - Propagação de --dry-run para scripts filhos
# =============================================================================

[[ -n "${_CS_RUNNER_LOADED:-}" ]] && return 0
readonly _CS_RUNNER_LOADED=1

# ── Estado do Runner ─────────────────────────────────────────────────────────
declare -a CS_RUN_SUCCESS=()
declare -a CS_RUN_FAILED=()
CS_RUN_NEED_REBOOT=false
CS_RUN_LOG="/var/log/custom_scripts_summary.log"
CS_RUN_REBOOT_NOW=false   # Indica que um reboot imediato é necessário

# ── Executar um script individual ────────────────────────────────────────────
cs_run_script() {
    local file="$1"
    local title="${CS_REGISTRY_TITLE[$file]}"
    local category="${CS_REGISTRY_CATEGORY[$file]}"
    local reboot="${CS_REGISTRY_REBOOT[$file]}"
    local supports_dryrun="${CS_REGISTRY_DRYRUN[$file]}"

    msg_header "Executando (${category}): ${title}"

    if [[ "$reboot" == "yes" ]]; then
        msg_warn "Este script requer reinicialização (será agendada quando necessário)."
    fi

    # Marcar como em execução no estado
    cs_state_mark_running "$file" 2>/dev/null || true

    # Preparar argumentos
    local extra_args=()
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        if [[ "$supports_dryrun" == "yes" ]]; then
            extra_args+=("--dry-run")
            msg_dry_run "Script suporta dry-run. Propagando flag."
        else
            msg_dry_run "Script NÃO suporta dry-run. Simulando execução..."
            msg_dry_run "Comandos que seriam executados em: $file"
            echo ""
            _cs_preview_script "$file"
            echo ""
            msg_dry_run "─── Fim da simulação: $title ───"
            CS_RUN_SUCCESS+=("$title [simulado]")
            cs_state_mark_done "$file" 2>/dev/null || true
            return 0
        fi
    fi

    # Exportar variáveis de ambiente para scripts filhos
    export CS_DRY_RUN CS_VERBOSE CS_ENV_TYPE CS_LOG_FILE

    if bash "$file" "${extra_args[@]}"; then
        msg_success "$title concluído com sucesso."
        CS_RUN_SUCCESS+=("$title")
        cs_state_mark_done "$file" 2>/dev/null || true

        # Se precisa de reboot e ainda há scripts pendentes, pausar para reboot
        if [[ "$reboot" == "yes" ]]; then
            CS_RUN_NEED_REBOOT=true
            # Verificar se há mais scripts pendentes
            local pending_count
            pending_count=$(cs_state_get_pending 2>/dev/null | wc -l || echo 0)
            if [[ $pending_count -gt 0 ]]; then
                msg_warn "Reboot necessário. Há mais $pending_count script(s) pendente(s)."
                msg_info "A execução continuará automaticamente após o reboot."
                CS_RUN_REBOOT_NOW=true
                return 0
            fi
        fi
    else
        local ret=$?
        msg_error "$title falhou (Código: $ret). Continuando..."
        CS_RUN_FAILED+=("$title (Exit: $ret)")
        cs_state_mark_failed "$file" 2>/dev/null || true
        sleep 2
    fi

    echo ""
}

# ── Preview de script (dry-run para scripts sem suporte) ────────────────────
_cs_preview_script() {
    local file="$1"
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        # Pular cabeçalho (primeiras linhas de metadados)
        [[ $line_num -le 15 ]] && continue

        # Pular linhas vazias e comentários
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Pular definições de função utilitárias comuns
        [[ "$line" =~ ^(msg_|readonly|RED=|GREEN=|YELLOW=|BLUE=|NC=|set\ -) ]] && continue

        # Mostrar comandos relevantes
        echo -e "  ${CS_DIM}│${CS_NC} $line"

    done < "$file" | head -40

    local total_lines
    total_lines=$(wc -l < "$file")
    if [[ $total_lines -gt 55 ]]; then
        echo -e "  ${CS_DIM}│ ... (mais ${total_lines} linhas no script original)${CS_NC}"
    fi
}

# ── Execução em lote com filas priorizadas ───────────────────────────────────
cs_run_batch() {
    local files=("$@")

    # Separar em filas por prioridade
    local interactive_queue=()
    local safe_queue=()
    local risk_queue=()

    for file in "${files[@]}"; do
        local interactive="${CS_REGISTRY_INTERACTIVE[$file]}"
        local network="${CS_REGISTRY_NETWORK[$file]}"

        if [[ "$network" == "risk" ]]; then
            risk_queue+=("$file")
        elif [[ "$interactive" == "yes" ]]; then
            interactive_queue+=("$file")
        else
            safe_queue+=("$file")
        fi
    done

    # Ordem: Interativos → Seguros → Risco de Rede
    local final_queue=("${interactive_queue[@]}" "${safe_queue[@]}" "${risk_queue[@]}")

    # Salvar estado da fila ANTES de começar
    cs_state_save_queue "${final_queue[@]}" 2>/dev/null || true

    clear
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_header "🔍 Modo DRY-RUN - Simulação (nada será instalado)"
    else
        msg_header "🚀 Iniciando Execução em Lote"
    fi
    echo "  Scripts selecionados: ${#final_queue[@]}"
    echo ""
    sleep 1

    # Iniciar log
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Execução iniciada em $(date)"
        echo "Modo: $(if [[ "${CS_DRY_RUN}" == "true" ]]; then echo 'DRY-RUN'; else echo 'PRODUÇÃO'; fi)"
        echo "Ambiente: ${CS_ENV_TYPE}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } > "${CS_RUN_LOG}" 2>/dev/null || true

    # Executar cada script
    for file in "${final_queue[@]}"; do
        cs_run_script "$file"

        # Se um reboot imediato foi sinalizado, pausar o loop
        if [[ "$CS_RUN_REBOOT_NOW" == "true" ]]; then
            break
        fi
    done

    # Se precisa reiniciar com scripts pendentes, faz reboot com resume
    if [[ "$CS_RUN_REBOOT_NOW" == "true" && "${CS_DRY_RUN}" != "true" ]]; then
        local install_dir="${SCRIPT_DIR:-/opt/custom_scripts}"
        cs_state_reboot_and_resume "$install_dir"
        # Nunca chega aqui (reboot)
        exit 0
    fi

    cs_finalize
}

# ── Retomar execução a partir do estado salvo ────────────────────────────────
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

    # Recuperar contagens anteriores
    while IFS= read -r file; do
        local title="${CS_REGISTRY_TITLE[$file]:-$(basename "$file")}"
        CS_RUN_SUCCESS+=("$title [pré-reboot]")
    done < <(cs_state_get_done)

    if ! confirm "Continuar a execução dos ${#pending_files[@]} scripts pendentes?" "y"; then
        msg_warn "Execução cancelada. Estado mantido. Use --resume para continuar depois."
        return 0
    fi

    # Executar pendentes (já estão na ordem correta no state file)
    for file in "${pending_files[@]}"; do
        # Precisa ter metadados carregados
        if [[ -z "${CS_REGISTRY_TITLE[$file]:-}" ]]; then
            msg_warn "Script não encontrado no registry: $file (pulando)"
            cs_state_mark_failed "$file" 2>/dev/null || true
            continue
        fi

        cs_run_script "$file"

        if [[ "$CS_RUN_REBOOT_NOW" == "true" ]]; then
            break
        fi
    done

    # Outro reboot necessário?
    if [[ "$CS_RUN_REBOOT_NOW" == "true" && "${CS_DRY_RUN}" != "true" ]]; then
        local install_dir="${SCRIPT_DIR:-/opt/custom_scripts}"
        cs_state_reboot_and_resume "$install_dir"
        exit 0
    fi

    # Tudo concluído — limpar
    cs_state_cleanup
    cs_finalize
}

# ── Relatório final ──────────────────────────────────────────────────────────
cs_finalize() {
    local summary=""

    msg_header "📋 Relatório de Execução"

    if [[ ${#CS_RUN_SUCCESS[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${CS_GREEN}${CS_BOLD}✔ Sucesso (${#CS_RUN_SUCCESS[@]}):${CS_NC}"
        for s in "${CS_RUN_SUCCESS[@]}"; do
            echo -e "    ${CS_GREEN}•${CS_NC} $s"
        done
        summary+="SUCESSO:\n"
        for s in "${CS_RUN_SUCCESS[@]}"; do
            summary+="  - $s\n"
        done
    fi

    if [[ ${#CS_RUN_FAILED[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${CS_RED}${CS_BOLD}✗ Falhas (${#CS_RUN_FAILED[@]}):${CS_NC}"
        for f in "${CS_RUN_FAILED[@]}"; do
            echo -e "    ${CS_RED}•${CS_NC} $f"
        done
        summary+="\nFALHAS:\n"
        for f in "${CS_RUN_FAILED[@]}"; do
            summary+="  - $f\n"
        done
    fi

    if [[ ${#CS_RUN_FAILED[@]} -eq 0 ]]; then
        echo ""
        echo -e "  ${CS_GREEN}🎉 Todos os scripts executados com sucesso!${CS_NC}"
    fi

    # Salvar log
    echo -e "$summary" >> "${CS_RUN_LOG}" 2>/dev/null || true

    # Reboot final (sem mais scripts pendentes)
    if [[ "$CS_RUN_NEED_REBOOT" == "true" && "$CS_RUN_REBOOT_NOW" != "true" ]]; then
        echo ""
        msg_warn "Um ou mais scripts solicitam reinicialização."
        if confirm "Deseja reiniciar agora?" "n"; then
            msg_info "Reiniciando sistema..."
            reboot
        else
            msg_warn "Por favor, reinicie manualmente quando possível."
        fi
    fi
}

# ── Reset do estado do runner ────────────────────────────────────────────────
cs_runner_reset() {
    CS_RUN_SUCCESS=()
    CS_RUN_FAILED=()
    CS_RUN_NEED_REBOOT=false
    CS_RUN_REBOOT_NOW=false
}
