#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - Registry / Auto-Discovery Engine (registry.sh)
#
# Responsável por escanear scripts, ler metadados e filtrar por compatibilidade.
# Suporta modo Local (sistema de arquivos) e Remoto (GitHub API).
# =============================================================================

[[ -n "${_CS_REGISTRY_LOADED:-}" ]] && return 0
readonly _CS_REGISTRY_LOADED=1

# ── Arrays globais do registro ───────────────────────────────────────────────
declare -a CS_REGISTRY_FILES=()
# shellcheck disable=SC2034
declare -A CS_REGISTRY_TITLE=()
# shellcheck disable=SC2034
declare -A CS_REGISTRY_DESC=()
# shellcheck disable=SC2034
declare -A CS_REGISTRY_SUPPORTED=()    # "lxc,vm" etc
# shellcheck disable=SC2034
declare -A CS_REGISTRY_INTERACTIVE=()  # "yes" or "no"
# shellcheck disable=SC2034
declare -A CS_REGISTRY_REBOOT=()       # "yes" or "no"
# shellcheck disable=SC2034
declare -A CS_REGISTRY_NETWORK=()      # "safe" or "risk"
# shellcheck disable=SC2034
declare -A CS_REGISTRY_CATEGORY=()
# shellcheck disable=SC2034
declare -A CS_REGISTRY_VERSION=()

# Diretórios e arquivos a ignorar
CS_REGISTRY_IGNORE_DIRS=("templates" "docs" "tests" "lib" ".git" ".github")
CS_REGISTRY_IGNORE_FILES=("setup.sh")

# ── Parser de Metadados (Single Pass) ────────────────────────────────────────
# Lê as primeiras 30 linhas e extrai variáveis
_cs_parse_metadata() {
    local content="$1"
    local file_path="$2"

    # Valores padrão
    local title="" desc="" supported="all" interactive="no" reboot="no" network="safe" version="1.0"

    # Extração via regex (case insensitive)
    # Nota: BASH_REMATCH funciona bem, mas grep/sed é mais portável para blocos de texto

    title=$(echo "$content" | grep -i "^# Title:" | head -1 | sed 's/^# Title:[[:space:]]*//I' | tr -d '\r')
    if [[ -z "$title" ]]; then return 1; fi # Script inválido se não tiver título

    desc=$(echo "$content" | grep -i "^# Description:" | head -1 | sed 's/^# Description:[[:space:]]*//I' | tr -d '\r')
    supported=$(echo "$content" | grep -i "^# Supported:" | head -1 | sed 's/^# Supported:[[:space:]]*//I' | tr -d '\r')
    interactive=$(echo "$content" | grep -i "^# Interactive:" | head -1 | sed 's/^# Interactive:[[:space:]]*//I' | tr -d '\r')
    reboot=$(echo "$content" | grep -i "^# Reboot:" | head -1 | sed 's/^# Reboot:[[:space:]]*//I' | tr -d '\r')
    network=$(echo "$content" | grep -i "^# Network:" | head -1 | sed 's/^# Network:[[:space:]]*//I' | tr -d '\r')
    version=$(echo "$content" | grep -i "^# Version:" | head -1 | sed 's/^# Version:[[:space:]]*//I' | tr -d '\r')

    # Defaults se vazio
    [[ -z "$supported" ]]   && supported="all"
    [[ -z "$interactive" ]] && interactive="no"
    [[ -z "$reboot" ]]      && reboot="no"
    [[ -z "$network" ]]     && network="safe"
    [[ -z "$version" ]]     && version="1.0"
    [[ -z "$desc" ]]        && desc="$title"

    # Normalização
    supported="${supported,,}"     # lowercase
    interactive="${interactive,,}"
    reboot="${reboot,,}"
    network="${network,,}"

    # Salvar no registro
    CS_REGISTRY_FILES+=("$file_path")
    # shellcheck disable=SC2034
    CS_REGISTRY_TITLE["$file_path"]="$title"
    # shellcheck disable=SC2034
    CS_REGISTRY_DESC["$file_path"]="$desc"
    # shellcheck disable=SC2034
    CS_REGISTRY_SUPPORTED["$file_path"]="$supported"
    # shellcheck disable=SC2034
    CS_REGISTRY_INTERACTIVE["$file_path"]="$interactive"
    # shellcheck disable=SC2034
    CS_REGISTRY_REBOOT["$file_path"]="$reboot"
    # shellcheck disable=SC2034
    CS_REGISTRY_NETWORK["$file_path"]="$network"
    # shellcheck disable=SC2034
    CS_REGISTRY_VERSION["$file_path"]="$version"

    # Categoria baseada no diretório pai
    local cat
    cat=$(dirname "$file_path" | xargs basename)
    [[ "$cat" == "." ]] && cat="root"
    CS_REGISTRY_CATEGORY["$file_path"]="$cat"

    return 0
}

# ── Scan Local ───────────────────────────────────────────────────────────────
_cs_scan_local() {
    local base_dir="$1"

    # Encontrar categorias (subdiretórios)
    while IFS= read -r -d '' cat_dir; do
        local cat_name
        cat_name=$(basename "$cat_dir")

        # Ignorar pastas proibidas
        local skip=false
        for ignore in "${CS_REGISTRY_IGNORE_DIRS[@]}"; do
            [[ "$cat_name" == "$ignore" ]] && skip=true && break
        done
        [[ "$skip" == "true" ]] && continue

        # Escanear arquivos .sh na categoria
        for file in "$cat_dir"/*.sh; do
            [[ -e "$file" ]] || continue

            # Ignorar arquivos proibidos
            local filename
            filename=$(basename "$file")
            local skip_file=false
            for ignore_f in "${CS_REGISTRY_IGNORE_FILES[@]}"; do
                [[ "$filename" == "$ignore_f" ]] && skip_file=true && break
            done
            [[ "$skip_file" == "true" ]] && continue

            # Ler cabeçalho (primeiras 30 linhas)
            local header
            header=$(head -n 30 "$file")

            # Parse
            _cs_parse_metadata "$header" "$file"
        done
    done < <(find "$base_dir" -maxdepth 1 -type d -not -path '*/.*' -not -path "$base_dir" -print0)
}

# ── Scan Remoto (GitHub) ─────────────────────────────────────────────────────
_cs_scan_remote() {
    msg_debug "Iniciando scan remoto..."

    if ! command -v curl &>/dev/null; then
        msg_error "curl necessário para scan remoto."
        return 1
    fi

    local api_url="${REMOTE_API_BASE:-https://api.github.com/repos/gutierrezx7/custom_scripts/git/trees/main?recursive=1}"
    local json_tmp
    json_tmp=$(mktemp)

    if ! curl -fsSL "$api_url" -o "$json_tmp"; then
        msg_error "Falha ao acessar API do GitHub."
        rm -f "$json_tmp"
        return 1
    fi

    local raw_base="${REMOTE_RAW_BASE:-https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main}"
    local count=0

    # Extrair caminhos de arquivos .sh (ignorando setup.sh e pastas ignoradas)
    # Nota: grep simples para evitar dependência de jq
    local files
    files=$(grep -o '"path": *"[^"]*\.sh"' "$json_tmp" | sed 's/"path": *"//;s/"$//')

    while IFS= read -r path; do
        # Verificar ignore list
        local skip=false
        for ignore in "${CS_REGISTRY_IGNORE_DIRS[@]}"; do
            if [[ "$path" == "$ignore/"* || "$path" == "$ignore" ]]; then
                skip=true; break
            fi
        done
        [[ "$skip" == "true" ]] && continue
        [[ "$(basename "$path")" == "setup.sh" ]] && continue

        # Feedback de progresso
        ((count++))
        if [[ $((count % 5)) -eq 0 ]]; then
            # Se tivermos função de spinner/progresso, usar aqui.
            # Por enquanto, apenas debug ou nada para não sujar TUI se não for wizard.
            msg_debug "Analisando remoto ($count): $path"
        fi

        # Download do cabeçalho apenas (Range header seria ideal, mas GitHub raw pode não suportar bem partial.
        # Vamos baixar primeiras linhas com curl piped to head se possível, ou full file se pequeno)
        # O GitHub Raw suporta range? Geralmente sim.
        local header
        header=$(curl -fsSL -r 0-2000 "$raw_base/$path" 2>/dev/null || true)

        _cs_parse_metadata "$header" "$path"

    done <<< "$files"

    rm -f "$json_tmp"
}

# ── Função Principal de Scan ─────────────────────────────────────────────────
cs_registry_scan() {
    local base_dir="${1:-.}"

    # Resetar registro
    CS_REGISTRY_FILES=()

    if [[ "${REMOTE_MODE:-}" == "1" ]]; then
        _cs_scan_remote
    else
        _cs_scan_local "$base_dir"
    fi

    msg_debug "Registry carregado: ${#CS_REGISTRY_FILES[@]} scripts."
}

# ── Filtrar por Compatibilidade ──────────────────────────────────────────────
# Remove do array CS_REGISTRY_FILES os scripts incompatíveis
cs_registry_filter_env() {
    # shellcheck disable=SC2034
    local env_type="${1:-$CS_ENV_TYPE}" # (Legado, agora usamos lib/system.sh)

    # Garantir que system.sh detectou algo
    if [[ -z "${CS_VIRT_TYPE:-}" ]]; then
        if command -v cs_system_detect &>/dev/null; then
            cs_system_detect
        else
            msg_warn "lib/system.sh não carregado ou falhou. Assumindo VM/Debian genérico."
            CS_VIRT_TYPE="vm"
            # shellcheck disable=SC2034
            CS_OS="debian"
        fi
    fi

    local filtered=()

    for file in "${CS_REGISTRY_FILES[@]}"; do
        local supported="${CS_REGISTRY_SUPPORTED[$file]}"

        # Usar a função robusta de system.sh
        # supported format: "lxc,vm" (virt)
        # Se tivéssemos OS supported também (ex: "# SupportedOS: debian"), passaríamos aqui.
        # Por enquanto, assumimos que 'Supported' refere-se à virtualização.

        if cs_system_check_compatibility "$supported" "all"; then
            filtered+=("$file")
        else
            msg_debug "Filtrado (Incompatível): $(basename "$file") [Req: $supported vs Sys: $CS_VIRT_TYPE]"
        fi
    done

    CS_REGISTRY_FILES=("${filtered[@]}")
    msg_debug "Scripts compatíveis após filtro: ${#CS_REGISTRY_FILES[@]}"
}

# ── Helpers de Acesso ────────────────────────────────────────────────────────

cs_registry_get_categories() {
    local -A seen
    local categories=()
    for file in "${CS_REGISTRY_FILES[@]}"; do
        local cat="${CS_REGISTRY_CATEGORY[$file]}"
        if [[ -z "${seen[$cat]:-}" ]]; then
            categories+=("$cat")
            seen["$cat"]=1
        fi
    done
    # Sort
    printf "%s\n" "${categories[@]}" | sort
}

cs_registry_get_by_category() {
    local target_cat="$1"
    for file in "${CS_REGISTRY_FILES[@]}"; do
        if [[ "${CS_REGISTRY_CATEGORY[$file]}" == "$target_cat" ]]; then
            echo "$file"
        fi
    done
}
