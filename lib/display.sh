#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - Display / UI Library (display.sh)
#
# Abstrai a interface com o usuário (TUI).
# Usa 'whiptail' se disponível e interativo, ou fallback para texto/CLI.
# =============================================================================

[[ -n "${_CS_DISPLAY_LOADED:-}" ]] && return 0
readonly _CS_DISPLAY_LOADED=1

# ── Configurações de Geometria ───────────────────────────────────────────────
_cs_get_term_size() {
    local h w
    h=$(tput lines 2>/dev/null || echo 24)
    w=$(tput cols 2>/dev/null || echo 80)

    # Defaults seguros
    CS_TERM_H=${h:-24}
    CS_TERM_W=${w:-80}

    # Box size (margem)
    CS_BOX_H=$((CS_TERM_H - 4))
    CS_BOX_W=$((CS_TERM_W - 4))

    # Limites mínimos
    [[ $CS_BOX_H -lt 10 ]] && CS_BOX_H=10
    [[ $CS_BOX_W -lt 40 ]] && CS_BOX_W=40
    [[ $CS_BOX_W -gt 100 ]] && CS_BOX_W=100 # Não ficar muito largo em telas grandes

    # List height (para checklist/menu)
    CS_LIST_H=$((CS_BOX_H - 8))
    [[ $CS_LIST_H -lt 4 ]] && CS_LIST_H=4
}

# ── Helpers Internos ─────────────────────────────────────────────────────────
_cs_is_interactive() {
    [[ "${CS_FORCE_INTERACTIVE:-}" == "true" ]] && return 0
    [[ -t 0 ]] && command -v whiptail &>/dev/null
}

# ── Componentes UI ───────────────────────────────────────────────────────────

# Exibe uma mensagem informativa (OK)
# Uso: cs_ui_msgbox "Título" "Mensagem detalhada..."
cs_ui_msgbox() {
    local title="$1"
    local msg="$2"

    _cs_get_term_size

    if _cs_is_interactive; then
        whiptail --title "$title" --msgbox "$msg" "$CS_BOX_H" "$CS_BOX_W"
    else
        msg_header "$title"
        echo -e "$msg"
        echo ""
        echo "Pressione ENTER para continuar..."
        read -r || true
    fi
}

# Pergunta Yes/No
# Uso: if cs_ui_yesno "Título" "Pergunta?"; then ... fi
cs_ui_yesno() {
    local title="$1"
    local msg="$2"

    _cs_get_term_size

    if _cs_is_interactive; then
        if whiptail --title "$title" --yesno "$msg" "$CS_BOX_H" "$CS_BOX_W"; then
            return 0
        else
            return 1
        fi
    else
        msg_header "$title"
        if confirm "$msg" "n"; then
            return 0
        else
            return 1
        fi
    fi
}

# Input de texto
# Uso: valor=$(cs_ui_inputbox "Título" "Prompt" "Valor Default")
cs_ui_inputbox() {
    local title="$1"
    local msg="$2"
    local default="$3"

    _cs_get_term_size

    if _cs_is_interactive; then
        local result
        result=$(whiptail --title "$title" --inputbox "$msg" "$CS_BOX_H" "$CS_BOX_W" "$default" 3>&1 1>&2 2>&3)
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            echo "$result"
        else
            return 1
        fi
    else
        msg_header "$title"
        local input
        read -rp "$msg [$default]: " input
        echo "${input:-$default}"
    fi
}

# Menu de Opções
# Uso: escolha=$(cs_ui_menu "Título" "Texto" "Tag1" "Item1" "Tag2" "Item2" ...)
cs_ui_menu() {
    local title="$1"; shift
    local msg="$1"; shift
    local options=("$@")

    _cs_get_term_size

    if _cs_is_interactive; then
        local result
        result=$(whiptail --title "$title" --menu "$msg" "$CS_BOX_H" "$CS_BOX_W" "$CS_LIST_H" "${options[@]}" 3>&1 1>&2 2>&3)
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            echo "$result"
        else
            return 1
        fi
    else
        # Fallback texto simples
        msg_header "$title"
        echo "$msg"
        echo "Opções:"
        local i=0
        local count=${#options[@]}
        while [[ $i -lt $count ]]; do
            echo "  ${options[$i]}) ${options[$((i+1))]}"
            i=$((i+2))
        done
        local choice
        read -rp "Escolha uma opção: " choice
        echo "$choice"
    fi
}

# Checklist (Múltipla escolha)
# Uso: cs_ui_checklist "Título" "Texto" "Tag1" "Item1" "OFF" "Tag2" "Item2" "ON" ...
# Retorna string com aspas: "Tag1" "Tag3"
cs_ui_checklist() {
    local title="$1"; shift
    local msg="$1"; shift
    local options=("$@")

    _cs_get_term_size

    if _cs_is_interactive; then
        local result
        result=$(whiptail --title "$title" --checklist "$msg" "$CS_BOX_H" "$CS_BOX_W" "$CS_LIST_H" "${options[@]}" 3>&1 1>&2 2>&3)
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            echo "$result"
        else
            return 1
        fi
    else
        msg_header "$title"
        msg_warn "Modo texto não suporta checklist complexo facilmente. Selecione 'Todos' ou 'Nenhum' ou digite IDs manualmente (não implementado no fallback simples)."
        return 1
    fi
}

# Gauge (Barra de Progresso)
# Uso: { echo 10; sleep 1; echo 50; } | cs_ui_gauge "Título" "Instalando..."
cs_ui_gauge() {
    local title="$1"
    local msg="$2"

    _cs_get_term_size

    if _cs_is_interactive; then
        whiptail --title "$title" --gauge "$msg" "$CS_BOX_H" "$CS_BOX_W" 0
    else
        msg_header "$title"
        echo "$msg"
        # Ler stdin e imprimir porcentagem
        while read -r percent; do
            echo -ne "\rProgresso: ${percent}%"
        done
        echo ""
    fi
}
