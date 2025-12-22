#!/bin/bash

################################################################################
#                                                                              #
#        WAZUH AGENT 4.14.1 - PROXMOX VE 9.1 DEPLOYMENT                      #
#        Version: 3.1 - XML Structure Fix + Proper Nesting                    #
#        Resolve: "Extra content at the end of the document" error            #
#                                                                              #
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURAÇÕES EDITÁVEIS
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
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# FUNÇÕES DE LOG
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

log_debug() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}DEBUG:${NC} $1" | tee -a "${LOG_FILE}"
}

print_banner() {
    cat << "EOF"

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║        WAZUH AGENT 4.14.1 - PROXMOX VE 9.1 DEPLOYMENT                       ║
║        Version 3.1 - Complete XML Structure Fix                             ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF
}

# ============================================================================
# FUNÇÕES DE VALIDAÇÃO
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
    log_success "Permissões de root verificadas"
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
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
    if [[ -d /etc/pve ]] || [[ -f /usr/bin/pvesh ]]; then
        log_success "Proxmox VE detectado"
        PROXMOX_VERSION=$(pvesh get /version --output-format json 2>/dev/null | grep -oP '"version":\s*"\K[^"]+' || echo "desconhecida")
        log_info "Versão do Proxmox: ${PROXMOX_VERSION}"
        return 0
    else
        log_warning "Proxmox VE pode não estar corretamente detectado"
        return 0
    fi
}

check_disk_space() {
    AVAILABLE=$(df / | awk 'NR==2 {print $4}')
    if [[ ${AVAILABLE} -lt 102400 ]]; then
        log_error "Espaço em disco insuficiente (< 100MB)"
        exit 1
    fi
    log_success "Espaço em disco: ${AVAILABLE}KB disponível"
}

check_connectivity() {
    log_info "Testando conectividade com Wazuh Manager..."
    if timeout 5 bash -c ">/dev/tcp/${WAZUH_MANAGER_IP}/${WAZUH_MANAGER_PORT}" 2>/dev/null; then
        log_success "Conectividade com Wazuh Manager confirmada"
    else
        log_error "Impossível conectar ao Wazuh Manager em ${WAZUH_MANAGER_IP}:${WAZUH_MANAGER_PORT}"
        exit 1
    fi
}

check_commands() {
    local COMMANDS=("curl" "apt-get" "sed" "grep")
    for cmd in "${COMMANDS[@]}"; do
        if ! command -v "${cmd}" &>/dev/null; then
            log_error "Comando obrigatório não encontrado: ${cmd}"
            exit 1
        fi
    done
    log_success "Todos os comandos obrigatórios disponíveis"
}

# ============================================================================
# FASE 1: VALIDAÇÕES
# ============================================================================

validate_prerequisites() {
    log_info "=== FASE 1: VALIDANDO PRÉ-REQUISITOS ==="
    check_root
    detect_os
    detect_proxmox
    check_disk_space
    check_connectivity
    check_commands
    log_success "=== VALIDAÇÕES CONCLUÍDAS ==="
    echo ""
}

# ============================================================================
# FASE 2: ATUALIZAÇÃO DO SISTEMA
# ============================================================================

update_system() {
    log_info "=== FASE 2: ATUALIZANDO SISTEMA ==="
    
    log_info "Executando apt-get update..."
    apt-get update -qq 2>&1 | grep -v "^W:" || true
    
    log_info "Instalando dependências..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        gnupg \
        apt-transport-https \
        curl \
        lsb-release \
        libxml2-utils \
        software-properties-common \
        2>/dev/null || true
    
    log_success "=== SISTEMA ATUALIZADO ==="
    echo ""
}

# ============================================================================
# FASE 3: CONFIGURAÇÃO DO REPOSITÓRIO WAZUH
# ============================================================================

configure_wazuh_repo() {
    log_info "=== FASE 3: CONFIGURANDO REPOSITÓRIO WAZUH ==="

    # Limpar chaves antigas
    log_info "Limpando chaves GPG antigas..."
    rm -f /usr/share/keyrings/wazuh.gpg 2>/dev/null || true

    # Importar chave GPG
    log_info "Importando chave GPG Wazuh..."
    if curl -sSL https://packages.wazuh.com/key/GPG-KEY-WAZUH 2>/dev/null | \
         gpg --dearmor 2>/dev/null > /usr/share/keyrings/wazuh.gpg; then
        chmod 644 /usr/share/keyrings/wazuh.gpg
        log_success "Chave GPG importada"
    else
        log_error "Falha ao importar chave GPG"
        exit 1
    fi

    # Adicionar repositório
    log_info "Adicionando repositório Wazuh..."
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | \
        tee /etc/apt/sources.list.d/wazuh.list >/dev/null

    # Atualizar índices
    log_info "Atualizando índices de pacotes..."
    apt-get update -qq 2>&1 | grep -v "^W:" || true
    
    log_success "=== REPOSITÓRIO CONFIGURADO ==="
    echo ""
}

# ============================================================================
# FASE 4: INSTALAÇÃO WAZUH AGENT
# ============================================================================

install_wazuh_agent() {
    log_info "=== FASE 4: INSTALANDO WAZUH AGENT ${WAZUH_VERSION} ==="

    if dpkg -l 2>/dev/null | grep -q "^ii.*wazuh-agent"; then
        log_warning "Wazuh Agent já instalado - atualizando..."
    fi

    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wazuh-agent 2>/dev/null || {
        log_error "Falha ao instalar Wazuh Agent"
        exit 1
    }

    OSSEC_CONF="/var/ossec/etc/ossec.conf"
    if [[ ! -f "${OSSEC_CONF}" ]]; then
        log_error "Arquivo de configuração não encontrado: ${OSSEC_CONF}"
        exit 1
    fi
    
    log_success "Wazuh Agent ${WAZUH_VERSION} instalado"
    echo ""
}

# ============================================================================
# FASE 5: RESTAURAR CONFIGURAÇÃO PADRÃO LIMPA
# ============================================================================

restore_default_config() {
    log_info "=== FASE 5: RESTAURANDO CONFIGURAÇÃO PADRÃO ==="

    local OSSEC_CONF="/var/ossec/etc/ossec.conf"
    local BACKUP_DIR="/var/backups/wazuh"
    local BACKUP_FILE="${BACKUP_DIR}/ossec.conf.$(date +%s).bak"

    # Criar backup
    mkdir -p "${BACKUP_DIR}"
    cp "${OSSEC_CONF}" "${BACKUP_FILE}"
    log_info "Backup criado: ${BACKUP_FILE}"

    # Restaurar padrão do Wazuh (remove configurações corrompidas)
    log_info "Restaurando arquivo padrão do Wazuh..."
    
    # Copiar do template default se existir
    if [[ -f /var/ossec/etc/ossec.conf.default ]]; then
        cp /var/ossec/etc/ossec.conf.default "${OSSEC_CONF}"
        log_debug "Restaurado de /var/ossec/etc/ossec.conf.default"
    else
        # Gerar arquivo limpo manualmente
        cat > "${OSSEC_CONF}" << 'DEFAULT_CONFIG'
<!-- Default Wazuh Agent Configuration -->
<ossec_config>

  <!-- Agent configuration -->
  <agent>
    <agent_name>AGENT_NAME_PLACEHOLDER</agent_name>
    <ip_address>auto</ip_address>
    <client>
      <server>
        <address>MANAGER_IP_PLACEHOLDER</address>
        <port>MANAGER_PORT_PLACEHOLDER</port>
        <protocol>tcp</protocol>
      </server>
    </client>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
    <compression>yes</compression>
  </agent>

  <!-- System monitoring -->
  <syscheck>
    <frequency>3600</frequency>
    <scan_on_start>yes</scan_on_start>
    <disabled>no</disabled>

    <directories check_all="yes">/etc</directories>
    <directories check_all="yes">/usr/bin</directories>
    <directories check_all="yes">/usr/sbin</directories>
    <directories check_all="yes">/var/www</directories>

    <!-- Exclude patterns -->
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.allow</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/resolv.conf</ignore>
    <ignore>/etc/fstab</ignore>
    <ignore>/etc/ssl/private</ignore>
    <ignore>/proc</ignore>
    <ignore>/sys</ignore>
    <ignore>/dev</ignore>
  </syscheck>

  <!-- Log monitoring -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/kern.log</location>
  </localfile>

  <!-- Rootcheck -->
  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_dev>yes</check_dev>
    <check_sys>yes</check_sys>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>
    <frequency>3600</frequency>
    <rootkit_files>/var/ossec/etc/rootkit_files.txt</rootkit_files>
    <rootkit_trojans>/var/ossec/etc/rootkit_trojans.txt</rootkit_trojans>
  </rootcheck>

</ossec_config>
DEFAULT_CONFIG
        log_debug "Arquivo padrão gerado manualmente"
    fi

    log_success "Configuração padrão restaurada"
    echo ""
}

# ============================================================================
# FASE 6: APLICAR CONFIGURAÇÕES ESPECÍFICAS
# ============================================================================

configure_agent_basic() {
    log_info "=== FASE 6: APLICANDO CONFIGURAÇÕES BÁSICAS ==="

    local OSSEC_CONF="/var/ossec/etc/ossec.conf"

    # Substituir placeholders
    log_info "Configurando agente: ${AGENT_NAME}"
    sed -i "s|AGENT_NAME_PLACEHOLDER|${AGENT_NAME}|g" "${OSSEC_CONF}"

    log_info "Configurando Manager: ${WAZUH_MANAGER_IP}:${WAZUH_MANAGER_PORT}"
    sed -i "s|MANAGER_IP_PLACEHOLDER|${WAZUH_MANAGER_IP}|g" "${OSSEC_CONF}"
    sed -i "s|MANAGER_PORT_PLACEHOLDER|${WAZUH_MANAGER_PORT}|g" "${OSSEC_CONF}"

    log_success "Configurações básicas aplicadas"
    echo ""
}

# ============================================================================
# FASE 7: ADICIONAR MONITORAMENTO PROXMOX
# ============================================================================

add_proxmox_monitoring() {
    log_info "=== FASE 7: ADICIONANDO MONITORAMENTO PROXMOX ==="

    local OSSEC_CONF="/var/ossec/etc/ossec.conf"
    
    # Backup antes de modificar
    cp "${OSSEC_CONF}" "${OSSEC_CONF}.pre-proxmox"
    
    # CRÍTICO: Inserir ANTES de </ossec_config>
    log_info "Inserindo regras Proxmox-específicas..."

    # Usar awk para inserir antes da tag de fechamento
    awk '/<\/ossec_config>/{
        print "  <!-- Proxmox VE Configuration Monitoring -->";
        print "  <syscheck>";
        print "    <frequency>3600</frequency>";
        print "    <scan_on_start>yes</scan_on_start>";
        print "    ";
        print "    <!-- Monitor Proxmox core directories -->";
        print "    <directories check_all=\"yes\" report_changes=\"yes\" realtime=\"yes\">/etc/pve</directories>";
        print "    <directories check_all=\"yes\" report_changes=\"yes\">/etc/pve/qemu-server</directories>";
        print "    <directories check_all=\"yes\" report_changes=\"yes\">/etc/pve/lxc</directories>";
        print "    <directories check_all=\"yes\" report_changes=\"yes\">/etc/pve/nodes</directories>";
        print "    <directories check_all=\"yes\" report_changes=\"yes\">/etc/pve/firewall</directories>";
        print "    <directories check_all=\"yes\" report_changes=\"yes\">/etc/pve/storage</directories>";
        print "  </syscheck>";
        print "  ";
        print "  <!-- Proxmox Log Monitoring -->";
        print "  <localfile>";
        print "    <log_format>syslog</log_format>";
        print "    <location>/var/log/pveproxy/access.log</location>";
        print "  </localfile>";
        print "  ";
        print "  <localfile>";
        print "    <log_format>syslog</log_format>";
        print "    <location>/var/log/pvedaemon.log</location>";
        print "  </localfile>";
        print "  ";
        print "  <localfile>";
        print "    <log_format>syslog</log_format>";
        print "    <location>/var/log/pvestatd.log</location>";
        print "  </localfile>";
        print "  ";
        print "  <localfile>";
        print "    <log_format>syslog</log_format>";
        print "    <location>/var/log/pvecm.log</location>";
        print "  </localfile>";
        print "  ";
        print "";
    } 1' "${OSSEC_CONF}" > "${OSSEC_CONF}.tmp" && mv "${OSSEC_CONF}.tmp" "${OSSEC_CONF}"

    log_success "Monitoramento Proxmox adicionado"
    echo ""
}

# ============================================================================
# FASE 8: VALIDAÇÃO XML
# ============================================================================

validate_xml() {
    log_info "=== FASE 8: VALIDANDO SINTAXE XML ==="

    local OSSEC_CONF="/var/ossec/etc/ossec.conf"

    # Verificar tag de fechamento
    if ! grep -q "</ossec_config>" "${OSSEC_CONF}"; then
        log_error "Tag de fechamento </ossec_config> não encontrada!"
        exit 1
    fi

    # Validar com xmllint
    if command -v xmllint &>/dev/null; then
        log_info "Validando XML com xmllint..."
        if xmllint --noout "${OSSEC_CONF}" 2>/tmp/xml_errors.log; then
            log_success "✓ Arquivo XML válido"
        else
            log_error "Erros de XML encontrados:"
            cat /tmp/xml_errors.log | tee -a "${LOG_FILE}"
            log_error "Restaurando backup..."
            if [[ -f "${OSSEC_CONF}.pre-proxmox" ]]; then
                cp "${OSSEC_CONF}.pre-proxmox" "${OSSEC_CONF}"
                log_warning "Configuração restaurada. Tente novamente."
            fi
            exit 1
        fi
    else
        log_warning "xmllint não disponível - validação será feita ao iniciar"
    fi
    echo ""
}

# ============================================================================
# FASE 9: INICIALIZAÇÃO WAZUH AGENT
# ============================================================================

start_wazuh_agent() {
    log_info "=== FASE 9: INICIANDO WAZUH AGENT ==="

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
        sleep 3
        
        if systemctl is-active --quiet wazuh-agent.service; then
            log_success "✓ Wazuh Agent iniciado com sucesso"
        else
            log_error "Serviço com status de erro"
            show_diagnostics
            exit 1
        fi
    else
        log_error "Falha ao iniciar Wazuh Agent"
        show_diagnostics
        exit 1
    fi
    echo ""
}

# ============================================================================
# DIAGNÓSTICOS
# ============================================================================

show_diagnostics() {
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "DIAGNÓSTICO DETALHADO"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    log_info "Status do serviço:"
    systemctl status wazuh-agent.service --no-pager 2>/dev/null || true
    
    echo ""
    log_info "Últimas linhas do journal:"
    journalctl -xeu wazuh-agent.service --no-pager -n 15 2>/dev/null || true
    
    echo ""
    log_info "Validação XML:"
    if command -v xmllint &>/dev/null; then
        xmllint --noout /var/ossec/etc/ossec.conf 2>&1 | head -20 || true
    fi
    
    echo ""
}

show_status() {
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "STATUS DO WAZUH AGENT"
    echo "════════════════════════════════════════════════════════════"
    systemctl status wazuh-agent.service --no-pager || true
    echo ""
}

# ============================================================================
# RESUMO FINAL
# ============================================================================

show_summary() {
    echo ""
    cat << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║                    INSTALAÇÃO CONCLUÍDA COM SUCESSO!                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

📋 DETALHES DA INSTALAÇÃO:
   • Versão Wazuh Agent: ${WAZUH_VERSION}
   • Nome do Agente: ${AGENT_NAME}
   • Manager: ${WAZUH_MANAGER_IP}:${WAZUH_MANAGER_PORT}
   • SO: ${OS} ${VERSION}
   • Log: ${LOG_FILE}
   • Backup: ${BACKUP_DIR}/

📝 MONITORAMENTO ATIVO:
   ✓ Proxmox Core (/etc/pve)
   ✓ Máquinas Virtuais (/etc/pve/qemu-server)
   ✓ Containers LXC (/etc/pve/lxc)
   ✓ Configurações de Nodes (/etc/pve/nodes)
   ✓ Firewall Rules (/etc/pve/firewall)
   ✓ Storage Config (/etc/pve/storage)
   ✓ Logs PVE (proxy, daemon, statd, cluster)
   ✓ Rootkit Detection
   ✓ System Audit

🔍 COMANDOS ÚTEIS:
   Status:          systemctl status wazuh-agent
   Logs:            tail -f /var/ossec/logs/ossec.log
   Configuração:    cat /var/ossec/etc/ossec.conf
   Teste conexão:   nc -zv ${WAZUH_MANAGER_IP} ${WAZUH_MANAGER_PORT}
   Agent info:      /var/ossec/bin/wazuh-control info

📚 DOCUMENTAÇÃO:
   https://documentation.wazuh.com/current/installation-guide/wazuh-agent/

═════════════════════════════════════════════════════════════════════════════════

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    print_banner
    mkdir -p "$(dirname "${LOG_FILE}")"
    touch "${LOG_FILE}"
    
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "Iniciando Wazuh Agent v${WAZUH_VERSION} para Proxmox VE"
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""

    validate_prerequisites
    update_system
    configure_wazuh_repo
    install_wazuh_agent
    restore_default_config
    configure_agent_basic
    add_proxmox_monitoring
    validate_xml
    start_wazuh_agent
    show_status

    log_success "═══════════════════════════════════════════════════════════════"
    log_success "INSTALAÇÃO FINALIZADA COM SUCESSO"
    log_success "═══════════════════════════════════════════════════════════════"
    
    show_summary
}

# Tratamento de erros
trap 'log_error "Script foi interrompido"; exit 1' INT TERM

# Executar
main "$@"

exit 0
