#!/usr/bin/env bash
# =============================================================================
# Custom Scripts - Registry / Auto-Discovery Engine (registry.sh)
# =============================================================================

[[ -n "${_CS_REGISTRY_LOADED:-}" ]] && return 0
readonly _CS_REGISTRY_LOADED=1

# ── Arrays globais do registro ───────────────────────────────────────────────
declare -a CS_REGISTRY_FILES=()
declare -A CS_REGISTRY_TITLE=()
declare -A CS_REGISTRY_DESC=()
declare -A CS_REGISTRY_SUPPORTED=()
declare -A CS_REGISTRY_INTERACTIVE=()
declare -A CS_REGISTRY_REBOOT=()
declare -A CS_REGISTRY_NETWORK=()
declare -A CS_REGISTRY_CATEGORY=()
declare -A CS_REGISTRY_VERSION=()
declare -A CS_REGISTRY_TAGS=()
declare -A CS_REGISTRY_DRYRUN=()

CS_REGISTRY_IGNORE_DIRS=("templates" "docs" "tests" "lib" ".git" ".github")
CS_REGISTRY_IGNORE_FILES=("setup.sh")

# ── Nomes amigáveis das categorias ──────────────────────────────────────────
declare -A CS_CATEGORY_LABELS=(
    ["system-admin"]="Sistema & Utilitários"
    ["docker"]="Docker & DevOps"
    ["network"]="Redes"
    ["security"]="Segurança"
    ["monitoring"]="Monitoramento"
    ["maintenance"]="Manutenção"
    ["backup"]="Backup"
    ["automation"]="Automação"
)

_cs_get_meta() {
    local file="$1"
    local key="$2"
    head -30 "$file" | grep -i "^# ${key}:" | head -1 | sed "s/^# ${key}:[ \t]*//" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || true
}

_cs_is_valid_script() {
    local file="$1"
    local title
    title=$(_cs_get_meta "$file" "Title")
    [[ -n "$title" ]]
}

_cs_scan_directory() {
    local dir="$1"
    local category
    category=$(basename "$dir")

    for file in "$dir"/*.sh; do
        [[ -e "$file" ]] || continue

        local basename_file
        basename_file=$(basename "$file")
        local skip=false
        for ignore in "${CS_REGISTRY_IGNORE_FILES[@]}"; do
            [[ "$basename_file" == "$ignore" ]] && skip=true && break
        done
        [[ "$skip" == "true" ]] && continue

        if ! _cs_is_valid_script "$file"; then
            msg_debug "Ignorando $file (metadados incompletos - falta 'Title:')"
            continue
        fi

        local title desc supported interactive reboot network version tags dryrun
        title=$(_cs_get_meta "$file" "Title")
        desc=$(_cs_get_meta "$file" "Description")
        supported=$(_cs_get_meta "$file" "Supported")
        interactive=$(_cs_get_meta "$file" "Interactive")
        reboot=$(_cs_get_meta "$file" "Reboot")
        network=$(_cs_get_meta "$file" "Network")
        version=$(_cs_get_meta "$file" "Version")
        tags=$(_cs_get_meta "$file" "Tags")
        dryrun=$(_cs_get_meta "$file" "DryRun")

        [[ -z "$supported" ]]   && supported="ALL"
        [[ -z "$interactive" ]] && interactive="no"
        [[ -z "$reboot" ]]     && reboot="no"
        [[ -z "$network" ]]    && network="safe"
        [[ -z "$version" ]]    && version="1.0"
        [[ -z "$dryrun" ]]     && dryrun="no"

        CS_REGISTRY_FILES+=("$file")
        CS_REGISTRY_TITLE["$file"]="$title"
        CS_REGISTRY_DESC["$file"]="${desc:-$title}"
        CS_REGISTRY_SUPPORTED["$file"]="$supported"
        CS_REGISTRY_INTERACTIVE["$file"]="$interactive"
        CS_REGISTRY_REBOOT["$file"]="$reboot"
        CS_REGISTRY_NETWORK["$file"]="$network"
        CS_REGISTRY_CATEGORY["$file"]="$category"
        CS_REGISTRY_VERSION["$file"]="$version"
        CS_REGISTRY_TAGS["$file"]="$tags"
        CS_REGISTRY_DRYRUN["$file"]="$dryrun"
    done
}

cs_registry_scan() {
    local base_dir="${1:-.}"

    if [[ "${REMOTE_MODE:-}" != "1" ]]; then
        if [[ -z "$base_dir" || ! -d "$base_dir" ]]; then
            msg_warn "Diretório base inválido para registry: '${base_dir:-<vazio>}'"
            return 0
        fi
    fi

    if [[ "${REMOTE_MODE:-}" == "1" ]]; then
        msg_debug "Registry em modo remoto — consultando GitHub API..."
        CS_REGISTRY_FILES=()

        if ! check_command curl; then
            msg_warn "curl não encontrado; registry remoto indisponível."
            return 0
        fi

        local api_url="${REMOTE_API_BASE:-https://api.github.com/repos/gutierrezx7/custom_scripts/git/trees/main?recursive=1}"
        local tmp
        if ! tmp=$(mktemp 2>/dev/null); then
            msg_warn "Falha ao criar arquivo temporário; registry remoto indisponível."
            return 0
        fi
        if ! curl -fsS "$api_url" -o "$tmp"; then
            msg_warn "Falha ao consultar GitHub API; registry remoto não disponível."
            rm -f "$tmp"
            return 0
        fi

        grep -o '"path": *"[^"]*\.sh"' "$tmp" | sed 's/"path": *"//;s/"$//' || true | while IFS= read -r path; do
            local skip=false
            for ignore in "${CS_REGISTRY_IGNORE_DIRS[@]}"; do
                if [[ "$path" == "$ignore/*" || "$path" == "$ignore" ]]; then
                    skip=true; break
                fi
            done
            [[ "$skip" == "true" ]] && continue

            if [[ "$(basename "$path")" == "setup.sh" ]]; then continue; fi

            local raw_url="${REMOTE_RAW_BASE:-https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main}/$path"
            local header
            header=$( (curl -fsS --max-time 10 "$raw_url" 2>/dev/null | sed -n '1,30p') || true )

            local title desc supported interactive reboot network version tags dryrun category
            title=$(echo "$header" | grep -i '^# Title:' | sed 's/^# Title:[[:space:]]*//I' | head -1)
            [[ -z "$title" ]] && continue
            desc=$(echo "$header" | grep -i '^# Description:' | sed 's/^# Description:[[:space:]]*//I' | head -1)
            supported=$(echo "$header" | grep -i '^# Supported:' | sed 's/^# Supported:[[:space:]]*//I' | head -1)
            interactive=$(echo "$header" | grep -i '^# Interactive:' | sed 's/^# Interactive:[[:space:]]*//I' | head -1)
            reboot=$(echo "$header" | grep -i '^# Reboot:' | sed 's/^# Reboot:[[:space:]]*//I' | head -1)
            network=$(echo "$header" | grep -i '^# Network:' | sed 's/^# Network:[[:space:]]*//I' | head -1)
            version=$(echo "$header" | grep -i '^# Version:' | sed 's/^# Version:[[:space:]]*//I' | head -1)
            tags=$(echo "$header" | grep -i '^# Tags:' | sed 's/^# Tags:[[:space:]]*//I' | head -1)
            dryrun=$(echo "$header" | grep -i '^# DryRun:' | sed 's/^# DryRun:[[:space:]]*//I' | head -1)

            category=$(dirname "$path")

            [[ -z "$supported" ]] && supported="ALL"
            [[ -z "$interactive" ]] && interactive="no"
            [[ -z "$reboot" ]] && reboot="no"
            [[ -z "$network" ]] && network="safe"
            [[ -z "$version" ]] && version="1.0"
            [[ -z "$dryrun" ]] && dryrun="no"

            CS_REGISTRY_FILES+=("$path")
            CS_REGISTRY_TITLE["$path"]="$title"
            CS_REGISTRY_DESC["$path"]="${desc:-$title}"
            CS_REGISTRY_SUPPORTED["$path"]="$supported"
            CS_REGISTRY_INTERACTIVE["$path"]="$interactive"
            CS_REGISTRY_REBOOT["$path"]="$reboot"
            CS_REGISTRY_NETWORK["$path"]="$network"
            CS_REGISTRY_CATEGORY["$path"]="$category"
            CS_REGISTRY_VERSION["$path"]="$version"
            CS_REGISTRY_TAGS["$path"]="$tags"
            CS_REGISTRY_DRYRUN["$path"]="$dryrun"
        done

        rm -f "$tmp"
        msg_debug "Registry remoto: ${#CS_REGISTRY_FILES[@]} scripts encontrados."
        return 0
    fi

    CS_REGISTRY_FILES=()
    while IFS= read -r -d '' dir; do
        local dirname
        dirname=$(basename "$dir")

        local skip=false
        for ignore in "${CS_REGISTRY_IGNORE_DIRS[@]}"; do
            [[ "$dirname" == "$ignore" ]] && skip=true && break
        done
        [[ "$skip" == "true" ]] && continue

        _cs_scan_directory "$dir"
    done < <(find "$base_dir" -maxdepth 1 -type d -not -path '*/.*' -not -path "$base_dir" -print0 | sort -z)

    msg_debug "Registry: ${#CS_REGISTRY_FILES[@]} scripts encontrados."
}

cs_fetch_script_to_temp() {
    local path="$1"
    local tmp
    tmp=$(mktemp /tmp/custom_scripts.XXXXXX.sh)
    local raw_url="${REMOTE_RAW_BASE:-https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main}/$path"
    if curl -fsS "$raw_url" -o "$tmp"; then
        chmod +x "$tmp"
        echo "$tmp"
        return 0
    else
        rm -f "$tmp"
        return 1
    fi
}

# ── Filtro por ambiente ──────────────────────────────────────────────────────
# Retorna apenas scripts compatíveis com o ambiente detectado.
cs_registry_filter_env() {
    local env_type="${1:-$CS_ENV_TYPE}"
    local filtered=()

    for file in "${CS_REGISTRY_FILES[@]}"; do
        local supported="${CS_REGISTRY_SUPPORTED[$file]}"

        # ALL é sempre compatível
        if [[ "$supported" == "ALL" ]]; then
            filtered+=("$file")
            continue
        fi

        # Verificar se o ambiente está na lista
        case "$env_type" in
            LXC)
                [[ "$supported" == *"LXC"* ]] && filtered+=("$file")
                ;;
            VM|Bare-Metal)
                [[ "$supported" == *"VM"* || "$supported" == *"ALL"* ]] && filtered+=("$file")
                ;;
            *)
                filtered+=("$file") # Se desconhecido, mostra tudo
                ;;
        esac
    done

    CS_REGISTRY_FILES=("${filtered[@]}")
    msg_debug "Registry filtrado: ${#CS_REGISTRY_FILES[@]} scripts para $env_type."
}

# ── Listar categorias disponíveis ────────────────────────────────────────────
cs_registry_categories() {
    local -A seen
    for file in "${CS_REGISTRY_FILES[@]}"; do
        local cat="${CS_REGISTRY_CATEGORY[$file]}"
        if [[ -z "${seen[$cat]:-}" ]]; then
            echo "$cat"
            seen["$cat"]=1
        fi
    done
}

# ── Listar scripts por categoria ────────────────────────────────────────────
cs_registry_by_category() {
    local category="$1"
    for file in "${CS_REGISTRY_FILES[@]}"; do
        [[ "${CS_REGISTRY_CATEGORY[$file]}" == "$category" ]] && echo "$file"
    done
}

# ── Obter label amigável da categoria ───────────────────────────────────────
cs_category_label() {
    local cat="$1"
    echo "${CS_CATEGORY_LABELS[$cat]:-${cat}}"
}

# ── Listar scripts (formato texto para --list) ──────────────────────────────
cs_registry_print() {
    local current_cat=""
    local sorted_files=()

    # Ordenar por categoria
    while IFS= read -r cat; do
        while IFS= read -r file; do
            sorted_files+=("$file")
        done < <(cs_registry_by_category "$cat")
    done < <(cs_registry_categories)

    for file in "${sorted_files[@]}"; do
        local cat="${CS_REGISTRY_CATEGORY[$file]}"
        local title="${CS_REGISTRY_TITLE[$file]}"
        local desc="${CS_REGISTRY_DESC[$file]}"
        local version="${CS_REGISTRY_VERSION[$file]}"
        local supported="${CS_REGISTRY_SUPPORTED[$file]}"

        if [[ "$cat" != "$current_cat" ]]; then
            current_cat="$cat"
            echo ""
            echo -e "${CS_BOLD}$(cs_category_label "$cat")${CS_NC}"
            printf "  %-30s %-40s %-6s %s\n" "SCRIPT" "DESCRIÇÃO" "VER" "AMBIENTE"
            printf "  %-30s %-40s %-6s %s\n" "──────" "─────────" "───" "────────"
        fi

        local basename_file
        basename_file=$(basename "$file")
        printf "  %-30s %-40s %-6s %s\n" \
            "$basename_file" \
            "${desc:0:38}" \
            "v${version}" \
            "$supported"
    done
    echo ""
}
