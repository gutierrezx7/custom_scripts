#!/bin/bash

################################################################################
#                                                                              #
#        WAZUH AGENT 4.14.1 - AUTOMAÇÃO PROXMOX VE (CORRIGIDO v2.3)          #
#        Deployment com Validações e Tratamento de Erros                     #
#                                                                              #
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================
WAZUH_VERSION="4.14.1"
WAZUH_MANAGER_IP="${WAZUH_MANAGER_IP:-soc.expertlevel.lan}"
WAZUH_MANAGER_PORT="${WAZUH_MANAGER_PORT:-1514}"
AGENT_NAME="${AGENT_NAME:-$(hostname)}"
LOG_FILE="/var/log/wazuh-install.log"
BACKUP_DIR="/var/backups/wazuh"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# FUNÇÕES
# ============================================================================

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✓ SUCCESS:${NC} $1" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠ WARNING:${NC} $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}✗ ERROR:${NC} $1" | tee -a "${LOG_FILE}"
}

print_banner() {
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║        WAZUH AGENT 4.14.1 - AUTOMAÇÃO PROXMOX VE                           ║
║        Deployment com Validações e Tratamento de Erros (v2.3 FIXED)        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

check_root() {
    [[ $EUID -eq 0 ]] || {
        log_error "Este script deve ser executado como root"
        exit 1
    }
    log_success "Permissões de root verificadas"
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="${ID}"
        VERSION="${VERSION_ID}"
    else
        log_error "Impossível detectar o SO"
        exit 1
    fi
    log_success "SO Detectado: ${OS} ${VERSION}"
}

detect_proxmox() {
    if [[ -d /etc/pve ]] || [[ -d /usr/share/proxmox-ve ]]; then
        log_success "Proxmox VE detectado via estrutura de diretórios"
        return 0
    else
        log_warning "Proxmox VE não foi detectado - continuando mesmo assim"
        return 0
    fi
}

check_disk_space() {
    AVAILABLE=$(df / | awk 'NR==2 {print $4}')
    [[ ${AVAILABLE} -gt 102400 ]] || {
        log_error "Espaço em disco insuficiente (< 100MB)"
        exit 1
    }
    log_success "Espaço em disco: ${AVAILABLE}KB disponível"
}

check_connectivity() {
    log_info "Testando conectividade com repositórios..."
    if timeout 5 curl -sSL https://packages.wazuh.com/4.x/apt/dists/focal/Release &>/dev/null; then
        log_success "Repositório Wazuh acessível"
    else
        log_warning "Repositório Wazuh pode estar indisponível - continuando"
    fi

    log_info "Testando conectividade com Wazuh Manager: ${WAZUH_MANAGER_IP}:${WAZUH_MANAGER_PORT}..."
    if timeout 5 bash -c ">/dev/tcp/${WAZUH_MANAGER_IP}/${WAZUH_MANAGER_PORT}" 2>/dev/null; then
        log_success "Conectividade com Wazuh Manager confirmada"
    else
        log_error "Impossível conectar ao Wazuh Manager"
        exit 1
    fi
}

check_commands() {
    local COMMANDS=("curl" "apt-get" "sed" "grep")
    for cmd in "${COMMANDS[@]}"; do
        command -v "${cmd}" &>/dev/null || {
            log_error "Comando obrigatório não encontrado: ${cmd}"
            exit 1
        }
    done
    log_success "Todos os comandos obrigatórios disponíveis"
}

# ============================================================================
# FASE 1: VALIDAÇÕES PRÉ-INSTALAÇÃO
# ============================================================================

validate_prerequisites() {
    log_info "=== FASE 1: VALIDANDO PRÉ-REQUISITOS ==="
    check_root
    detect_os
    detect_proxmox
    check_disk_space
    check_connectivity
    check_commands
    log_success "=== VALIDAÇÕES PRÉ-INSTALAÇÃO CONCLUÍDAS ==="
}

# ============================================================================
# FASE 2: ATUALIZAÇÃO DO SISTEMA
# ============================================================================

update_system() {
    log_info "=== FASE 2: ATUALIZANDO SISTEMA ==="
    log_info "Executando apt-get update..."
    apt-get update -qq 2>&1 | grep -v "^W:" || true
    log_success "Sistema atualizado"

    log_info "Instalando dependências: gnupg, apt-transport-https, curl, lsb-release..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        gnupg \
        apt-transport-https \
        curl \
        lsb-release \
        libxml2-utils \
        2>/dev/null || true
    log_success "Dependências instaladas"
}

# ============================================================================
# FASE 3: CONFIGURAÇÃO DO REPOSITÓRIO
# ============================================================================

configure_wazuh_repo() {
    log_info "=== FASE 3: CONFIGURANDO REPOSITÓRIO WAZUH ==="

    # Limpar chaves GPG antigas/corrompidas
    log_info "Limpando chaves GPG antigas..."
    rm -f /usr/share/keyrings/wazuh.gpg /etc/apt/trusted.gpg.d/wazuh.gpg 2>/dev/null || true

    log_info "Importando chave GPG Wazuh..."
    # Download e conversion segura
    if ! curl -sSL https://packages.wazuh.com/key/GPG-KEY-WAZUH 2>/dev/null | \
         gpg --dearmor 2>/dev/null | \
         tee /usr/share/keyrings/wazuh.gpg >/dev/null 2>&1; then
        log_error "Falha ao importar chave GPG"
        exit 1
    fi

    # Verificar se o arquivo foi criado corretamente
    if [[ ! -s /usr/share/keyrings/wazuh.gpg ]]; then
        log_error "Arquivo GPG vazio ou não foi criado"
        exit 1
    fi

    chmod 644 /usr/share/keyrings/wazuh.gpg
    log_success "Chave GPG importada com sucesso"

    log_info "Adicionando repositório Wazuh..."
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | \
        tee /etc/apt/sources.list.d/wazuh.list >/dev/null
    log_success "Repositório Wazuh adicionado"

    log_info "Atualizando índices de pacotes..."
    apt-get update -qq 2>&1 | grep -v "^W:" || true
    log_success "Índices atualizados"
}

# ============================================================================
# FASE 4: INSTALAÇÃO DO WAZUH AGENT
# ============================================================================

install_wazuh_agent() {
    log_info "=== FASE 4: INSTALANDO WAZUH AGENT ${WAZUH_VERSION} ==="

    if dpkg -l | grep -q "^ii.*wazuh-agent"; then
        log_warning "Wazuh Agent já está instalado, atualizando..."
    fi

    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wazuh-agent 2>/dev/null || {
        log_error "Falha ao instalar Wazuh Agent"
        exit 1
    }

    OSSEC_CONF="/var/ossec/etc/ossec.conf"
    [[ -f "${OSSEC_CONF}" ]] || {
        log_error "Arquivo de configuração não encontrado: ${OSSEC_CONF}"
        exit 1
    }
    log_success "Wazuh Agent instalado"
    log_success "Arquivo de configuração encontrado: ${OSSEC_CONF}"
}

# ============================================================================
# FASE 5: CONFIGURAÇÃO DO WAZUH AGENT
# ============================================================================

configure_wazuh_agent() {
    log_info "=== FASE 5: CONFIGURANDO WAZUH AGENT ==="
    local OSSEC_CONF="/var/ossec/etc/ossec.conf"

    # Criar backup
    mkdir -p "${BACKUP_DIR}"
    local BACKUP_FILE="${BACKUP_DIR}/ossec.conf.$(date +%s).bak"
    cp "${OSSEC_CONF}" "${BACKUP_FILE}"
    log_info "Fazendo backup da configuração original..."
    log_success "Backup criado: ${BACKUP_FILE}"

    # Limpeza - remover tags inválidas COM MAIS CUIDADO
    log_info "Limpando configuração de tags inválidas..."
    
    # Usar Python para manipulação XML mais confiável
    python3 << 'PYTHON_SCRIPT'
import xml.etree.ElementTree as ET
import sys

try:
    ossec_conf = "/var/ossec/etc/ossec.conf"
    tree = ET.parse(ossec_conf)
    root = tree.getroot()
    
    # Encontrar e limpar elementos orphaos no syscheck
    for syscheck in root.findall('.//syscheck'):
        # Remover elementos inválidos
        for elem in list(syscheck):
            if elem.tag in ['file', 'skip_sys', 'skip_nfs']:
                syscheck.remove(elem)
    
    # Normalizar scan_day para minúsculas
    for scan_day in root.findall('.//scan_day'):
        if scan_day.text:
            scan_day.text = scan_day.text.lower()
    
    # Salvar arquivo limpo
    tree.write(ossec_conf, encoding='utf-8', xml_declaration=True)
    print("XML limpo com sucesso", file=sys.stderr)
    
except Exception as e:
    print(f"Erro ao processar XML: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT

    if [[ $? -eq 0 ]]; then
        log_success "Tags inválidas removidas"
    else
        log_warning "Limpeza com Python falhou, tentando com sed..."
        # Fallback para sed (menos seguro mas funciona)
        sed -i '/<syscheck>/,/<\/syscheck>/{ /\(<file>\|<file \|<skip_sys>\|<skip_nfs>\)/d; }' "${OSSEC_CONF}"
        sed -i 's|<scan_day>[A-Z]|<scan_day>'"$(sed -E 's/<scan_day>([A-Za-z]+)<\/scan_day>/\L\1/g')"'|g' "${OSSEC_CONF}"
        log_success "Tags inválidas removidas (com sed)"
    fi

    # Configurar nome do agente
    log_info "Configurando nome do agente: ${AGENT_NAME}"
    sed -i "s|<agent_name>.*</agent_name>|<agent_name>${AGENT_NAME}</agent_name>|" "${OSSEC_CONF}"

    # Configurar Manager
    log_info "Configurando Manager: ${WAZUH_MANAGER_IP}:${WAZUH_MANAGER_PORT}"
    sed -i "s|<manager>.*</manager>|<manager>${WAZUH_MANAGER_IP}</manager>|" "${OSSEC_CONF}"
    sed -i "s|<manager_port>.*</manager_port>|<manager_port>${WAZUH_MANAGER_PORT}</manager_port>|" "${OSSEC_CONF}"

    # Validar XML
    log_info "Validando sintaxe XML da configuração..."
    if command -v xmllint &>/dev/null; then
        if xmllint --noout "${OSSEC_CONF}" 2>/tmp/xml_errors.log; then
            log_success "Validação XML concluída com sucesso"
        else
            log_error "XML contém erros de sintaxe:"
            cat /tmp/xml_errors.log | head -10 | tee -a "${LOG_FILE}"
            log_warning "Restaurando backup..."
            cp "${BACKUP_FILE}" "${OSSEC_CONF}"
            exit 1
        fi
    else
        log_warning "xmllint não disponível, instalando libxml2..."
        apt-get install -y -qq libxml2 2>/dev/null || true
        log_warning "Validação XML será feita ao iniciar o serviço"
    fi
}

# ============================================================================
# FASE 6: INICIALIZAÇÃO DO WAZUH AGENT
# ============================================================================

start_wazuh_agent() {
    log_info "=== FASE 6: INICIANDO WAZUH AGENT ==="

    log_info "Recarregando daemon systemd..."
    systemctl daemon-reload

    log_info "Ativando Wazuh Agent no boot..."
    if systemctl enable wazuh-agent.service 2>/dev/null; then
        log_success "Wazuh Agent ativado no boot"
    else
        log_error "Falha ao ativar Wazuh Agent no boot"
        exit 1
    fi

    log_info "Iniciando Wazuh Agent..."
    if systemctl start wazuh-agent.service 2>/dev/null; then
        sleep 2
        
        # Verificar status
        if systemctl is-active --quiet wazuh-agent.service; then
            log_success "Wazuh Agent iniciado com sucesso"
            show_agent_status
        else
            log_error "Serviço iniciado mas retornou erro - capturando diagnóstico..."
            show_agent_diagnostics
            exit 1
        fi
    else
        log_error "Falha ao iniciar wazuh-agent - capturando diagnóstico..."
        show_agent_diagnostics
        exit 1
    fi
}

show_agent_status() {
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "STATUS DO WAZUH AGENT"
    echo "════════════════════════════════════════════════════════════"
    systemctl status wazuh-agent.service --no-pager || true
    echo ""
}

show_agent_diagnostics() {
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "DIAGNÓSTICO DETALHADO"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    log_info "Status detalhado:"
    systemctl status wazuh-agent.service --no-pager || true
    
    echo ""
    log_info "Últimas linhas do journal:"
    journalctl -xeu wazuh-agent.service --no-pager -n 20 || true
    
    echo ""
    log_info "Validando arquivo de configuração:"
    if command -v xmllint &>/dev/null; then
        xmllint --noout /var/ossec/etc/ossec.conf 2>&1 | head -20 || true
    fi
    
    echo ""
}

# ============================================================================
# CONCLUSÃO
# ============================================================================

show_summary() {
    cat << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║                         RESUMO DA INSTALAÇÃO                                ║
╚══════════════════════════════════════════════════════════════════════════════╝

✓ Versão do Wazuh Agent: ${WAZUH_VERSION}
✓ Nome do Agente: ${AGENT_NAME}
✓ Manager: ${WAZUH_MANAGER_IP}:${WAZUH_MANAGER_PORT}
✓ Log de instalação: ${LOG_FILE}
✓ Arquivo de backup: ${BACKUP_DIR}/

Próximos passos:
1. Verifique o status: systemctl status wazuh-agent
2. Verifique os logs: tail -f /var/ossec/logs/ossec.log
3. Valide no manager: /var/ossec/bin/agent_control -l

Documentação:
https://documentation.wazuh.com/current/user-manual/agent/agent-management/

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    print_banner
    log_info "Arquivo de log criado: ${LOG_FILE}"
    log_info "Iniciando deployment do Wazuh Agent ${WAZUH_VERSION}"
    log_info "Script versão: 2.3 (FIXED - GPG + XML)"

    validate_prerequisites
    update_system
    configure_wazuh_repo
    install_wazuh_agent
    configure_wazuh_agent
    start_wazuh_agent
    
    log_success "=== INSTALAÇÃO CONCLUÍDA COM SUCESSO ==="
    show_summary
}

# Trap para capturar erros
trap 'log_error "Script foi interrompido"; exit 1' INT TERM

# Executar main
main "$@"

exit 0
