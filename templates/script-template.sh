#!/usr/bin/env bash
# =============================================================================
# ── METADADOS (obrigatórios para auto-discovery) ────────────────────────────
# Title:       Nome Amigável do Script
# Description: Breve descrição do que o script faz (uma linha)
# Supported:   ALL                  # ALL | VM | LXC | VM, LXC
# Interactive:  no                  # yes | no - precisa de input do usuário?
# Reboot:      no                  # yes | no - requer reboot após execução?
# Network:     safe                # safe | risk - altera config de rede?
# DryRun:      yes                 # yes | no - suporta --dry-run nativo?
# Version:     1.0
# Tags:        exemplo, template   # Tags para busca (separadas por vírgula)
# Author:      Seu Nome
# =============================================================================
#
# Descrição detalhada:
#   Este é o template padrão para novos scripts do projeto Custom Scripts.
#   Todos os novos scripts DEVEM seguir este formato para serem detectados
#   automaticamente pelo menu principal (setup.sh).
#
# Uso:
#   bash script-template.sh [--dry-run] [--verbose] [--help]
#
# =============================================================================

set -euo pipefail

# ── Carregar biblioteca compartilhada (se disponível) ────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_FILE="${SCRIPT_DIR}/../lib/common.sh"

if [[ -f "$LIB_FILE" ]]; then
    # shellcheck source=../lib/common.sh
    source "$LIB_FILE"
else
    # Fallback: funções mínimas para execução standalone
    CS_DRY_RUN="${CS_DRY_RUN:-false}"
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; NC='\033[0m'
    msg_info()    { echo -e "${GREEN}[INFO]${NC}    $1"; }
    msg_warn()    { echo -e "${YELLOW}[AVISO]${NC}   $1"; }
    msg_error()   { echo -e "${RED}[ERRO]${NC}    $1" >&2; }
    msg_header()  { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
    msg_step()    { echo -e "  ➜ $1"; }
    msg_dry_run() { echo -e "${MAGENTA}[DRY-RUN]${NC} $1"; }
    cs_run() {
        if [[ "${CS_DRY_RUN}" == "true" ]]; then
            msg_dry_run "$ $*"; return 0
        fi
        "$@"
    }
    check_root() {
        [[ $EUID -ne 0 ]] && { msg_error "Execute como root."; exit 1; }
    }
fi

# ── Parse de argumentos ─────────────────────────────────────────────────────
show_help() {
    cat << 'EOF'
Uso: script-template.sh [opções]

Opções:
  --dry-run     Simular execução sem fazer alterações
  --verbose     Modo detalhado
  --help, -h    Mostrar esta ajuda

Exemplos:
  sudo bash script-template.sh
  sudo bash script-template.sh --dry-run
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  CS_DRY_RUN=true; shift ;;
        --verbose)
            # shellcheck disable=SC2034
            CS_VERBOSE=true; shift ;;
        --help|-h)  show_help ;;
        *)          msg_error "Opção desconhecida: $1"; show_help ;;
    esac
done

# ── Constantes do script ────────────────────────────────────────────────────
readonly APP_NAME="nome-do-app"
readonly APP_VERSION="1.0"

# ── Verificações ─────────────────────────────────────────────────────────────
preflight() {
    msg_header "Verificações Iniciais"

    check_root
    msg_step "Verificando dependências..."

    # Exemplo: verificar comandos necessários
    local deps=(curl wget)
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        msg_warn "Instalando dependências: ${missing[*]}"
        cs_run apt-get update -qq
        cs_run apt-get install -y "${missing[@]}"
    fi

    msg_step "Verificações concluídas."
}

# ── Instalação / Lógica principal ────────────────────────────────────────────
install() {
    msg_header "Instalando ${APP_NAME} v${APP_VERSION}"

    # Exemplo de comandos com dry-run:
    msg_step "Adicionando repositório..."
    cs_run apt-get update -qq

    msg_step "Instalando pacotes..."
    cs_run apt-get install -y "${APP_NAME}"

    # Exemplo de configuração:
    msg_step "Configurando ${APP_NAME}..."
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_dry_run "Criaria arquivo /etc/${APP_NAME}/config"
    else
        # Criar configuração real aqui
        :
    fi
}

# ── Pós-instalação ──────────────────────────────────────────────────────────
post_install() {
    msg_header "Pós-instalação"

    msg_step "Habilitando serviço..."
    cs_run systemctl enable "${APP_NAME}" 2>/dev/null || true
    cs_run systemctl start "${APP_NAME}" 2>/dev/null || true

    msg_step "Verificando status..."
    if [[ "${CS_DRY_RUN}" != "true" ]]; then
        if systemctl is-active --quiet "${APP_NAME}" 2>/dev/null; then
            msg_info "${APP_NAME} está rodando! ✔"
        else
            msg_warn "${APP_NAME} instalado, mas serviço não está ativo."
        fi
    fi
}

# ── Cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
    msg_step "Limpando arquivos temporários..."
    # Adicionar limpeza aqui
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_header "🔍 MODO DRY-RUN - Simulação de: ${APP_NAME}"
    fi

    preflight
    install
    post_install
    cleanup

    echo ""
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_info "Simulação concluída. Nenhuma alteração foi feita."
    else
        msg_info "${APP_NAME} instalado com sucesso! 🎉"
    fi
}

main
