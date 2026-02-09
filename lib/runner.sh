#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - Runner / Execution Engine (runner.sh)
#
# Motor de execução inteligente com suporte a:
#   - Dry-run (simulação sem alterações)
#   - Execução em lote com filas priorizadas
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

# ── Executar um script individual ────────────────────────────────────────────
cs_run_script() {
    local file="$1"
    local title="${CS_REGISTRY_TITLE[$file]}"
    local category="${CS_REGISTRY_CATEGORY[$file]}"
    local reboot="${CS_REGISTRY_REBOOT[$file]}"
    local supports_dryrun="${CS_REGISTRY_DRYRUN[$file]}"

    msg_header "Executando (${category}): ${title}"

    if [[ "$reboot" == "yes" ]]; then
        msg_warn "Este script requer reinicialização (será agendada para o final)."
    fi

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
            # Mostrar os comandos principais do script (linhas não-comentário)
            _cs_preview_script "$file"
            echo ""
            msg_dry_run "─── Fim da simulação: $title ───"
            CS_RUN_SUCCESS+=("$title [simulado]")
            return 0
        fi
    fi

    # Executar
    # Exportar variáveis de ambiente para scripts filhos
    export CS_DRY_RUN CS_VERBOSE CS_ENV_TYPE CS_LOG_FILE

    if bash "$file" "${extra_args[@]}"; then
        msg_success "$title concluído com sucesso."
        CS_RUN_SUCCESS+=("$title")
        [[ "$reboot" == "yes" ]] && CS_RUN_NEED_REBOOT=true
    else
        local ret=$?
        msg_error "$title falhou (Código: $ret). Continuando..."
        CS_RUN_FAILED+=("$title (Exit: $ret)")
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
    done

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

    # Reboot
    if [[ "$CS_RUN_NEED_REBOOT" == "true" ]]; then
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
}
