#!/bin/bash

################################################################################
#                                                                              #
#        WAZUH AGENT 4.14.1 - AUTOMAÇÃO PROXMOX VE                           #
#        Deployment com Validações e Tratamento de Erros                     #
#        Versão: 2.0 - CORRIGIDA PARA PROXMOX 9.1                            #
#                                                                              #
#        Data: $(date '+%Y-%m-%d %H:%M:%S')                                  #
#        Autor: gutierrezx7 (Modificado)                                      #
#                                                                              #
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

WAZUH_MANAGER="${WAZUH_MANAGER:-soc.expertlevel.lan}"
WAZUH_MANAGER_PORT="${WAZUH_MANAGER_PORT:-1514}"
WAZUH_AGENT_NAME="${WAZUH_AGENT_NAME:-$(hostname)}"
WAZUH_AGENT_GROUP="${WAZUH_AGENT_GROUP:-proxmox}"
WAZUH_VERSION="4.14.1"
LOG_FILE="/var/log/wazuh-install.log"
BACKUP_DIR="/var/backups/wazuh"
AGENT_CONFIG="/var/ossec/etc/ossec.conf"
SCRIPT_VERSION="2.0"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] INFO: $@" | tee -a "$LOG_FILE"
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] ${GREEN}✓ SUCCESS:${NC} $@" | tee -a "$LOG_FILE"
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] ${YELLOW}⚠ WARNING:${NC} $@" | tee -a "$LOG_FILE"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] ${RED}✗ ERROR:${NC} $@" | tee -a "$LOG_FILE"
}

print_header() {
    cat << "EOF"

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║        WAZUH AGENT 4.14.1 - AUTOMAÇÃO PROXMOX VE                           ║
║        Deployment com Validações e Tratamento de Erros (v2.0)              ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF
}

cleanup_on_error() {
    local exit_code=$?
    log_error "Instalação falhou com código de erro: $exit_code"
    log_error "Verifique o arquivo de log em: $LOG_FILE"
    log_error "Para debug, execute: tail -f $LOG_FILE"
    exit $exit_code
}

trap cleanup_on_error EXIT

# ============================================================================
# FASE 1: VALIDAÇÕES PRÉ-REQUISITOS
# ============================================================================

validate_prerequisites() {
    log_info "=== FASE 1: VALIDANDO PRÉ-REQUISITOS ==="
    
    # Verificar permissões de root
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
    log_success "Permissões de root verificadas"
    
    # Detectar SO
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        log_success "SO Detectado: $OS $OS_VERSION"
    else
        log_error "Não foi possível detectar o SO"
        exit 1
    fi
    
    # Validar SO suportado
    if [[ ! "$OS" =~ ^(debian|ubuntu)$ ]]; then
        log_warning "SO detectado: $OS. Este script foi testado em Debian/Ubuntu"
    fi
    
    # Detectar Proxmox
    if [ -f /etc/pve/version ]; then
        PROXMOX_VERSION=$(cat /etc/pve/version)
        log_success "Proxmox VE detectado - Versão: $PROXMOX_VERSION"
    else
        log_warning "Proxmox VE não detectado. Este pode não ser um nó Proxmox VE válido."
        log_warning "Continuando mesmo assim..."
    fi
    
    # Verificar espaço em disco
    DISK_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [ "$DISK_SPACE" -lt 1048576 ]; then
        log_error "Espaço em disco insuficiente (mínimo 1GB)"
        exit 1
    fi
    log_success "Espaço em disco: ${DISK_SPACE}KB disponível"
    
    # Testar conectividade repositório
    log_info "Testando conectividade com repositórios..."
    if ! timeout 5 curl -s https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/ > /dev/null 2>&1; then
        log_warning "Possível problema ao acessar repositório Wazuh (conectividade pode estar limitada)"
    else
        log_success "Repositório Wazuh acessível"
    fi
    
    # Testar conectividade Wazuh Manager
    log_info "Testando conectividade com Wazuh Manager: ${WAZUH_MANAGER}:${WAZUH_MANAGER_PORT}..."
    if ! timeout 5 bash -c "</dev/tcp/${WAZUH_MANAGER}/${WAZUH_MANAGER_PORT}" 2>/dev/null; then
        log_warning "Não foi possível conectar ao Wazuh Manager (pode estar offline ou firewall bloqueando)"
        log_warning "Continuando a instalação mesmo assim..."
    else
        log_success "Conectividade com Wazuh Manager confirmada"
    fi
    
    # Verificar comandos obrigatórios
    local required_commands=("curl" "systemctl" "apt-get" "gpg")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Comando obrigatório não encontrado: $cmd"
            exit 1
        fi
    done
    log_success "Todos os comandos obrigatórios disponíveis"
    
    log_success "=== VALIDAÇÕES PRÉ-INSTALAÇÃO CONCLUÍDAS ==="
}

# ============================================================================
# FASE 2: ATUALIZAR SISTEMA
# ============================================================================

update_system() {
    log_info "=== FASE 2: ATUALIZANDO SISTEMA ==="
    
    log_info "Executando apt-get update..."
    if apt-get update 2>&1 | grep -q "E:"; then
        log_warning "Alguns repositórios podem estar com problemas, continuando..."
    fi
    log_success "Sistema atualizado"
    
    log_info "Instalando dependências: gnupg, apt-transport-https, curl, lsb-release..."
    apt-get install -y gnupg apt-transport-https curl lsb-release 2>&1 | tail -5 >> "$LOG_FILE"
    log_success "Dependências instaladas"
}

# ============================================================================
# FASE 3: CONFIGURAR REPOSITÓRIO WAZUH
# ============================================================================

setup_wazuh_repo() {
    log_info "=== FASE 3: CONFIGURANDO REPOSITÓRIO WAZUH ==="
    
    # Importar chave GPG
    log_info "Importando chave GPG Wazuh..."
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring /etc/apt/trusted.gpg.d/wazuh.gpg --import - 2>&1 | tail -3 >> "$LOG_FILE"
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Chave GPG importada com sucesso"
    else
        log_error "Falha ao importar chave GPG"
        exit 1
    fi
    
    # Adicionar repositório
    log_info "Adicionando repositório Wazuh..."
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list > /dev/null
    log_success "Repositório Wazuh adicionado"
    
    # Atualizar índices
    log_info "Atualizando índices de pacotes..."
    apt-get update > /dev/null 2>&1
    log_success "Índices atualizados"
}

# ============================================================================
# FASE 4: INSTALAR WAZUH AGENT
# ============================================================================

install_wazuh_agent() {
    log_info "=== FASE 4: INSTALANDO WAZUH AGENT ${WAZUH_VERSION} ==="
    
    # Verificar se já está instalado
    if dpkg -l | grep -q wazuh-agent; then
        log_warning "Wazuh Agent já está instalado, atualizando..."
        apt-get install --only-upgrade wazuh-agent -y 2>&1 | tail -5 >> "$LOG_FILE"
    else
        log_info "Instalando pacote wazuh-agent=${WAZUH_VERSION}-1..."
        apt-get install -y wazuh-agent 2>&1 | tail -5 >> "$LOG_FILE"
    fi
    
    if dpkg -l | grep -q wazuh-agent; then
        log_success "Wazuh Agent instalado"
    else
        log_error "Falha ao instalar Wazuh Agent"
        exit 1
    fi
    
    # Verificar arquivo de configuração
    if [ ! -f "$AGENT_CONFIG" ]; then
        log_error "Arquivo de configuração não encontrado: $AGENT_CONFIG"
        exit 1
    fi
    log_success "Arquivo de configuração encontrado: $AGENT_CONFIG"
}

# ============================================================================
# FASE 5: CONFIGURAR WAZUH AGENT
# ============================================================================

configure_wazuh_agent() {
    log_info "=== FASE 5: CONFIGURANDO WAZUH AGENT ==="
    
    # Criar diretório de backup
    mkdir -p "$BACKUP_DIR"
    
    # Fazer backup da configuração original
    log_info "Fazendo backup da configuração original..."
    BACKUP_FILE="$BACKUP_DIR/ossec.conf.$(date +%s).bak"
    cp "$AGENT_CONFIG" "$BACKUP_FILE"
    log_success "Backup criado: $BACKUP_FILE"
    
    # Injetar configuração para Proxmox
    log_info "Injetando configuração para monitoramento Proxmox..."
    
    # Localizar a linha </agent> para inserir antes dela
    if grep -q "</agent>" "$AGENT_CONFIG"; then
        # Criar arquivo de configuração temporário
        cat > /tmp/proxmox_config.xml << 'PROXMOX_CONFIG'
    
    <!-- Monitoramento Proxmox VE -->
    <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/syslog</location>
    </localfile>
    
    <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/auth.log</location>
    </localfile>
    
    <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/kern.log</location>
    </localfile>
    
    <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/pve/firewall</location>
        <exclude>/var/log/pve/firewall/*.1.gz</exclude>
        <exclude>/var/log/pve/firewall/*.2.gz</exclude>
    </localfile>
    
    <!-- Monitoramento de Integridade de Arquivo -->
    <syscheck>
        <frequency>43200</frequency>
        <directories realtime="yes" report_changes="yes" restrict="/etc/pve">/etc/pve</directories>
        <directories realtime="yes" report_changes="yes">/etc/pam.d</directories>
        <directories realtime="yes" report_changes="yes">/etc/ssh/sshd_config</directories>
    </syscheck>

PROXMOX_CONFIG
        
        # Inserir configuração antes de </agent>
        sed -i '/<\/agent>/e cat /tmp/proxmox_config.xml' "$AGENT_CONFIG"
        log_success "Configuração Proxmox injetada"
    else
        log_warning "Tag </agent> não encontrada, configuração básica será mantida"
    fi
    
    # Configurar agente name e grupo
    log_info "Configurando nome do agente: $WAZUH_AGENT_NAME"
    sed -i "s/<agent_name>.*<\/agent_name>/<agent_name>$WAZUH_AGENT_NAME<\/agent_name>/g" "$AGENT_CONFIG"
    
    # Validar sintaxe XML (ANTES de iniciar o serviço)
    log_info "Validando sintaxe XML da configuração..."
    if command -v xmllint &> /dev/null; then
        if xmllint --noout "$AGENT_CONFIG" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Sintaxe XML válida"
        else
            log_error "Erro na sintaxe XML do arquivo de configuração"
            log_error "Restaurando backup..."
            cp "$BACKUP_FILE" "$AGENT_CONFIG"
            exit 1
        fi
    else
        log_warning "xmllint não disponível, pulando validação XML (será validado ao iniciar serviço)"
    fi
}

# ============================================================================
# FASE 6: INICIAR WAZUH AGENT
# ============================================================================

start_wazuh_agent() {
    log_info "=== FASE 6: INICIANDO WAZUH AGENT ==="
    
    # Recarregar daemon systemd
    log_info "Recarregando daemon systemd..."
    systemctl daemon-reload
    
    # Ativar no boot
    log_info "Ativando Wazuh Agent no boot..."
    systemctl enable wazuh-agent 2>&1 | tee -a "$LOG_FILE"
    log_success "Wazuh Agent ativado no boot"
    
    # Iniciar o serviço
    log_info "Iniciando Wazuh Agent..."
    
    if systemctl start wazuh-agent 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Wazuh Agent iniciado"
    else
        log_error "Falha ao iniciar wazuh-agent"
        log_info "Verificando status detalhado..."
        systemctl status wazuh-agent 2>&1 | tee -a "$LOG_FILE"
        log_info "Tentando diagnóstico..."
        
        # Tentar iniciar manualmente para ver erro
        /var/ossec/bin/wazuh-control start 2>&1 | tee -a "$LOG_FILE" || true
        
        exit 1
    fi
    
    # Aguardar serviço estar pronto
    sleep 3
    
    # Verificar status
    if systemctl is-active --quiet wazuh-agent; then
        log_success "Wazuh Agent está rodando"
    else
        log_error "Wazuh Agent não está rodando após inicialização"
        systemctl status wazuh-agent 2>&1 | tee -a "$LOG_FILE"
        exit 1
    fi
}

# ============================================================================
# FASE 7: VERIFICAÇÕES FINAIS
# ============================================================================

verify_installation() {
    log_info "=== FASE 7: VERIFICAÇÕES FINAIS ==="
    
    # Verificar se o agente está registrado
    sleep 2
    if /var/ossec/bin/wazuh-control status 2>&1 | tee -a "$LOG_FILE" | grep -q "is running"; then
        log_success "Wazuh Agent está rodando corretamente"
    else
        log_warning "Wazuh Agent pode não estar completamente inicializado"
    fi
    
    # Verificar versão instalada
    if [ -f /var/ossec/VERSION ]; then
        INSTALLED_VERSION=$(cat /var/ossec/VERSION)
        log_success "Versão instalada: $INSTALLED_VERSION"
    fi
    
    # Verificar conectividade com manager
    log_info "Verificando conectividade com Wazuh Manager..."
    if /var/ossec/bin/agent-control -l 2>&1 | grep -q "not.*connected\|Connection"; then
        log_warning "Agente pode não estar conectado ao Manager ainda (pode levar alguns minutos)"
    else
        log_success "Agente aparentemente conectado ao Manager"
    fi
}

# ============================================================================
# RESUMO FINAL
# ============================================================================

print_summary() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                  ✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO                        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

[${timestamp}] SUCCESS: === INSTALAÇÃO FINALIZADA ===

Informações da Instalação:
  • Versão do Wazuh Agent: ${WAZUH_VERSION}
  • Nome do Agente: ${WAZUH_AGENT_NAME}
  • Grupo do Agente: ${WAZUH_AGENT_GROUP}
  • Manager: ${WAZUH_MANAGER}:${WAZUH_MANAGER_PORT}
  • Arquivo de Log: ${LOG_FILE}
  • Backup: ${BACKUP_FILE}

Próximas Etapas:
  1. Aguarde 2-5 minutos para o agente registrar no Manager
  2. Verifique a conectividade com: systemctl status wazuh-agent
  3. Para logs em tempo real: tail -f /var/ossec/logs/ossec.log
  4. Registre o agente no Proxmox (se necessário)

Comandos Úteis:
  • Status: systemctl status wazuh-agent
  • Reiniciar: systemctl restart wazuh-agent
  • Logs: tail -f /var/ossec/logs/ossec.log
  • Controle: /var/ossec/bin/wazuh-control status

EOF
}

# ============================================================================
# EXECUÇÃO PRINCIPAL
# ============================================================================

main() {
    print_header
    
    # Criar arquivo de log
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    log_info "Arquivo de log criado: $LOG_FILE"
    
    log_info "Iniciando deployment do Wazuh Agent ${WAZUH_VERSION}"
    log_info "Script versão: ${SCRIPT_VERSION}"
    
    validate_prerequisites
    update_system
    setup_wazuh_repo
    install_wazuh_agent
    configure_wazuh_agent
    start_wazuh_agent
    verify_installation
    
    trap - EXIT
    print_summary
    log_success "Script finalizado com sucesso!"
    exit 0
}

# Executar main
main "$@"
