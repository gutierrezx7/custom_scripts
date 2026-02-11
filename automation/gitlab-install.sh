#!/usr/bin/env bash
# Title: Instalação do GitLab CE
# Description: Instala o GitLab Community Edition (versão mais recente) em LXC
# Supported: LXC
# Interactive: yes
# Reboot: no
# Network: safe
# License: GPL v3

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
    msg_success() { echo -e "${GREEN}[✔]${NC} $1"; }
    cs_run() {
        if [[ "${CS_DRY_RUN}" == "true" ]]; then
            msg_dry_run "$ $*"; return 0
        fi
        "$@"
    }
    check_root() {
        [[ $EUID -ne 0 ]] && { msg_error "Execute como root."; exit 1; }
    }
    cs_parse_common_args() {
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --dry-run)  CS_DRY_RUN=true; shift ;;
                --verbose)
                    # shellcheck disable=SC2034
                    CS_VERBOSE=true; shift ;;
                *)          shift ;;
            esac
        done
    }
fi

# Parse args
cs_parse_common_args "$@"

msg_header "Instalação do GitLab CE"

# Verificar root
check_root

# Verificação de Recursos
msg_step "Verificando recursos do sistema..."
MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
# 4GB = 4194304 KB
if [ "$MEM_KB" -lt 4000000 ]; then
    msg_warn "O GitLab requer pelo menos 4GB de RAM. Detectado: $(($MEM_KB / 1024))MB."
    msg_warn "A instalação pode falhar ou o sistema ficar instável."

    # Se dry-run ou não interativo, apenas avisa e continua (para testes/CI)
    if [[ "${CS_DRY_RUN}" == "true" || ! -t 0 ]]; then
        msg_warn "Modo não-interativo ou Dry-Run: Continuando apesar do aviso de memória."
    else
        read -p "Deseja continuar mesmo assim? (s/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            msg_error "Instalação cancelada pelo usuário."
            exit 1
        fi
    fi
fi

msg_step "Atualizando listas de pacotes..."
cs_run apt-get update -qq 2>/dev/null || true

msg_step "Instalando dependências..."
# Dependências essenciais conforme documentação oficial
cs_run apt-get install -y curl openssh-server ca-certificates tzdata perl

# Instalação do Postfix (Se não existir)
if ! command -v postfix &> /dev/null; then
    msg_step "Instalando Postfix para envio de e-mails..."
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_dry_run "Configuração debconf postfix e instalação"
    else
        # Configuração automática para evitar prompts interativos
        echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
        echo "postfix postfix/mailname string $(hostname -f)" | debconf-set-selections
        DEBIAN_FRONTEND=noninteractive cs_run apt-get install -y postfix
    fi
else
    msg_info "Postfix já instalado."
fi

msg_step "Adicionando repositório oficial do GitLab..."
if [[ "${CS_DRY_RUN}" == "true" ]]; then
    msg_dry_run "curl -fsSL https://packages.gitlab.com/... | bash"
else
    curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
fi

# Configuração da URL Externa
# hostname -I pode retornar vários IPs, pegamos o primeiro. Se falhar, usa localhost.
CURRENT_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
DEFAULT_URL="http://$CURRENT_IP"
EXTERNAL_URL="$DEFAULT_URL"

# Se o script estiver rodando interativamente (detectado pelo setup.sh ou terminal) e NÃO for dry-run
if [[ -t 0 && "${CS_DRY_RUN}" != "true" ]]; then
    msg_header "Configuração de URL Externa"
    echo -e "O endereço padrão será: ${GREEN}$DEFAULT_URL${NC}"
    read -p "Deseja alterar o endereço (ex: http://gitlab.meudominio.com)? [s/N] " -r
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        read -p "Digite a URL completa (com http:// ou https://): " USER_URL
        if [[ -n "$USER_URL" ]]; then
            EXTERNAL_URL="$USER_URL"
        fi
    fi
else
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_dry_run "Usando URL padrão: $DEFAULT_URL (Skipping interactive prompt)"
    else
        msg_info "Modo não interativo: usando URL padrão $DEFAULT_URL"
    fi
fi

msg_step "Instalando GitLab CE (EXTERNAL_URL=$EXTERNAL_URL)..."
msg_warn "Isso pode demorar alguns minutos dependendo da sua conexão e hardware."

# Instalação propriamente dita
if [[ "${CS_DRY_RUN}" == "true" ]]; then
    msg_dry_run "EXTERNAL_URL=\"$EXTERNAL_URL\" apt-get install -y gitlab-ce"
else
    EXTERNAL_URL="$EXTERNAL_URL" cs_run apt-get install -y gitlab-ce
fi

msg_success "Instalação do GitLab CE concluída (simulada ou real)!"
if [[ "${CS_DRY_RUN}" != "true" ]]; then
    echo -e "Acesse via navegador em: ${GREEN}$EXTERNAL_URL${NC}"
    echo -e "\nA senha inicial do usuário 'root' foi gerada automaticamente em:"
    echo -e "${YELLOW}/etc/gitlab/initial_root_password${NC}"
    echo -e "(Este arquivo será excluído automaticamente após 24 horas)"
    echo -e "\nPara reconfigurar no futuro, edite /etc/gitlab/gitlab.rb e execute 'gitlab-ctl reconfigure'."
fi
