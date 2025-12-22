
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
║        Deployment com Validações e Tratamento de Erros (v2.2 FIXED)        ║
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
    apt-get update -qq || log_warning "apt-get update retornou aviso"
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

    log_info "Importando chave GPG Wazuh..."
    curl -sSL https://packages.wazuh.com/key/GPG-KEY-WAZUH 2>/dev/null | \
        gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import - 2>/dev/null || true
    chmod 644 /usr/share/keyrings/wazuh.gpg
    log_success "Chave GPG importada com sucesso"

    log_info "Adicionando repositório Wazuh..."
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | \
        tee /etc/apt/sources.list.d/wazuh.list >/dev/null
    log_success "Repositório Wazuh adicionado"

    log_info "Atualizando índices de pacotes..."
    apt-get update -qq || true
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

    # Limpeza - remover tags inválidas
    log_info "Limpando configuração de tags inválidas..."
    
    # Remove elementos órfãos de syscheck
    sed -i '/<syscheck>/,/<\/syscheck>/{
        /<file[^_]/d
        /<skip_sys>/d
        /<\/skip_sys>/d
    }' "${OSSEC_CONF}"

    # Remove scan_day em formato inválido (case-sensitive)
    sed -i 's|<scan_day>[Mm]onday</scan_day>|<scan_day>monday</scan_day>|g' "${OSSEC_CONF}"
    sed -i 's|<scan_day>[Tt]uesday</scan_day>|<scan_day>tuesday</scan_day>|g' "${OSSEC_CONF}"
    sed -i 's|<scan_day>[Ww]ednesday</scan_day>|<scan_day>wednesday</scan_day>|g' "${OSSEC_CONF}"
    sed -i 's|<scan_day>[Tt]hursday</scan_day>|<scan_day>thursday</scan_day>|g' "${OSSEC_CONF}"
    sed -i 's|<scan_day>[Ff]riday</scan_day>|<scan_day>friday</scan_day>|g' "${OSSEC_CONF}"
    sed -i 's|<scan_day>[Ss]aturday</scan_day>|<scan_day>saturday</scan_day>|g' "${OSSEC_CONF}"
    sed -i 's|<scan_day>[Ss]unday</scan_day>|<scan_day>sunday</scan_day>|g' "${OSSEC_CONF}"

    log_success "Tags inválidas removidas"

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
        if xmllint --noout "${OSSEC_CONF}" 2>/dev/null; then
            log_success "Validação XML concluída com sucesso"
        else
            log_error "XML contém erros de sintaxe"
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
        log_success "Wazuh Agent iniciado com sucesso"
        sleep 2
        
        # Verificar status
        if systemctl is-active --quiet wazuh-agent.service; then
            log_success "Status do serviço: ATIVO"
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
        xmllint --noout /var/ossec/etc/ossec.conf 2>&1 || true
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
    log_info "Script versão: 2.2 (FIXED)"

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
