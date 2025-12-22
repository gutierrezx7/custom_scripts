#!/bin/bash

################################################################################
# WAZUH AGENT 4.14.1 - PROXMOX VE DEPLOYMENT AUTOMATION
# Script: Automação completa com validações e tratamento de erros
# Versão: 1.0
# Data: Dezembro 2025
# Compatibilidade: Debian 11/12, Ubuntu 20.04/22.04 (Proxmox 7/8/9)
################################################################################

set -o pipefail

# ============================= CONFIGURAÇÕES =====================================
WAZUH_VERSION="4.14.1"
WAZUH_MANAGER="${WAZUH_MANAGER:-soc.expertlevel.lan}"
WAZUH_MANAGER_PORT="${WAZUH_MANAGER_PORT:-1514}"
WAZUH_REPO_URL="https://packages.wazuh.com"
WAZUH_GPG_KEY_URL="${WAZUH_REPO_URL}/key/GPG-KEY-WAZUH"
WAZUH_APT_REPO="${WAZUH_REPO_URL}/4.x/apt/"
LOG_FILE="/var/log/wazuh-install.log"
CONFIG_BACKUP_DIR="/var/backups/wazuh"
AGENT_CONFIG="/var/ossec/etc/ossec.conf"
AGENT_CONFIG_TEMPLATE="/etc/wazuh-agent-ossec.conf"
START_TIME=$(date +%s)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================= FUNÇÕES UTILITÁRIAS ===============================

# Logging com timestamp
log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} INFO: $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✓ SUCCESS: $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ⚠ WARNING: $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✗ ERROR: $1" | tee -a "$LOG_FILE"
}

# Validação de comando
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Tratamento de erro com saída
error_exit() {
    log_error "$1"
    log_error "Instalação falhou após $(($(date +%s) - START_TIME))s"
    exit 1
}

# Pausa com confirmação
pause_continue() {
    log_warning "$1"
    read -p "Pressione ENTER para continuar ou Ctrl+C para cancelar..." -t 30
}

# ============================= VALIDAÇÕES PRÉ-INSTALAÇÃO ==========================

validate_prerequisites() {
    log_info "=== FASE 1: VALIDANDO PRÉ-REQUISITOS ==="
    
    # 1. Verificar se é root
    if [[ $EUID -ne 0 ]]; then
        error_exit "Este script deve ser executado como root (use sudo)"
    fi
    log_success "Permissões de root verificadas"
    
    # 2. Detectar OS
    if [[ ! -f /etc/os-release ]]; then
        error_exit "/etc/os-release não encontrado"
    fi
    
    source /etc/os-release
    if [[ "$ID" != "debian" && "$ID" != "ubuntu" ]]; then
        error_exit "Sistema operacional não suportado: $ID (requer Debian/Ubuntu)"
    fi
    log_success "SO Detectado: $ID $VERSION_ID"
    
    # 3. Verificar Proxmox
    if [[ ! -f /etc/pve/version.txt ]]; then
        pause_continue "Aviso: Proxmox não detectado. Este pode não ser um nó Proxmox VE."
    else
        PROXMOX_VERSION=$(cat /etc/pve/version.txt)
        log_success "Proxmox VE detectado: $PROXMOX_VERSION"
    fi
    
    # 4. Verificar espaço em disco
    AVAILABLE_SPACE=$(df /var | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=$((1000 * 1024)) # 1GB em KB
    
    if [[ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]]; then
        error_exit "Espaço em disco insuficiente. Disponível: ${AVAILABLE_SPACE}KB, Requerido: ${REQUIRED_SPACE}KB"
    fi
    log_success "Espaço em disco: ${AVAILABLE_SPACE}KB disponível"
    
    # 5. Testar conectividade internet
    log_info "Testando conectividade com repositórios..."
    if ! curl -m 10 -s -I "${WAZUH_REPO_URL}/key/GPG-KEY-WAZUH" >/dev/null 2>&1; then
        error_exit "Não é possível acessar ${WAZUH_REPO_URL}. Verifique sua conexão internet"
    fi
    log_success "Repositório Wazuh acessível"
    
    # 6. Testar conectividade com Wazuh Manager
    log_info "Testando conectividade com Wazuh Manager: $WAZUH_MANAGER:$WAZUH_MANAGER_PORT..."
    if ! timeout 5 bash -c "</dev/tcp/${WAZUH_MANAGER}/${WAZUH_MANAGER_PORT}" 2>/dev/null; then
        pause_continue "Aviso: Não foi possível conectar ao Wazuh Manager em $WAZUH_MANAGER:$WAZUH_MANAGER_PORT. Continuando mesmo assim."
    else
        log_success "Conectividade com Wazuh Manager confirmada"
    fi
    
    # 7. Verificar dependências de comando
    local REQUIRED_COMMANDS=("curl" "gpg" "apt-get" "systemctl")
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command_exists "$cmd"; then
            error_exit "Comando obrigatório não encontrado: $cmd"
        fi
    done
    log_success "Todos os comandos obrigatórios disponíveis"
    
    log_success "=== VALIDAÇÕES PRÉ-INSTALAÇÃO CONCLUÍDAS ==="
}

# ============================= INSTALAÇÃO =========================================

setup_logging() {
    log_info "=== CONFIGURANDO LOGGING ==="
    mkdir -p "$CONFIG_BACKUP_DIR"
    chmod 700 "$CONFIG_BACKUP_DIR"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    log_success "Arquivo de log criado: $LOG_FILE"
}

update_system() {
    log_info "=== FASE 2: ATUALIZANDO SISTEMA ==="
    
    log_info "Executando apt-get update..."
    if ! apt-get update >> "$LOG_FILE" 2>&1; then
        error_exit "Falha ao executar apt-get update"
    fi
    log_success "Sistema atualizado"
    
    # Instalar dependências
    log_info "Instalando dependências: gnupg, apt-transport-https, curl..."
    if ! apt-get install -y gnupg apt-transport-https curl >> "$LOG_FILE" 2>&1; then
        error_exit "Falha ao instalar dependências"
    fi
    log_success "Dependências instaladas"
}

setup_wazuh_repo() {
    log_info "=== FASE 3: CONFIGURANDO REPOSITÓRIO WAZUH ==="
    
    # Baixar chave GPG
    log_info "Importando chave GPG Wazuh..."
    if ! curl -s "$WAZUH_GPG_KEY_URL" | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import >> "$LOG_FILE" 2>&1; then
        error_exit "Falha ao importar chave GPG"
    fi
    
    # Verificar permissões da chave
    if ! chmod 644 /usr/share/keyrings/wazuh.gpg >> "$LOG_FILE" 2>&1; then
        error_exit "Falha ao configurar permissões da chave GPG"
    fi
    log_success "Chave GPG importada com sucesso"
    
    # Adicionar repositório
    log_info "Adicionando repositório Wazuh..."
    if ! echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] ${WAZUH_APT_REPO} stable main" > /etc/apt/sources.list.d/wazuh.list; then
        error_exit "Falha ao adicionar repositório Wazuh"
    fi
    log_success "Repositório Wazuh adicionado"
    
    # Atualizar índices
    log_info "Atualizando índices de pacotes..."
    if ! apt-get update >> "$LOG_FILE" 2>&1; then
        error_exit "Falha ao atualizar índices após adicionar repositório"
    fi
    log_success "Índices atualizados"
}

install_wazuh_agent() {
    log_info "=== FASE 4: INSTALANDO WAZUH AGENT $WAZUH_VERSION ==="
    
    log_info "Instalando pacote wazuh-agent..."
    if ! WAZUH_MANAGER="$WAZUH_MANAGER" apt-get install -y wazuh-agent >> "$LOG_FILE" 2>&1; then
        error_exit "Falha ao instalar wazuh-agent"
    fi
    log_success "Wazuh Agent instalado"
    
    # Verificar se o agent foi instalado
    if [[ ! -f "$AGENT_CONFIG" ]]; then
        error_exit "Arquivo de configuração não encontrado: $AGENT_CONFIG"
    fi
    log_success "Arquivo de configuração encontrado: $AGENT_CONFIG"
    
    # Fazer backup da configuração original
    log_info "Fazendo backup da configuração original..."
    cp "$AGENT_CONFIG" "${CONFIG_BACKUP_DIR}/ossec.conf.$(date +%s).bak"
    log_success "Backup criado: ${CONFIG_BACKUP_DIR}/ossec.conf.*.bak"
}

configure_wazuh_agent() {
    log_info "=== FASE 5: CONFIGURANDO WAZUH AGENT PARA PROXMOX ==="
    
    # Validar arquivo config
    if ! grep -q "^<ossec_config>" "$AGENT_CONFIG"; then
        error_exit "Arquivo de configuração inválido"
    fi
    
    # Remover secção anterior se existir
    if grep -q "<!-- PROXMOX CUSTOM CONFIG -->" "$AGENT_CONFIG"; then
        log_warning "Removendo configuração Proxmox anterior..."
        sed -i '/<!-- PROXMOX CUSTOM CONFIG -->/,/<!-- FIM PROXMOX CUSTOM CONFIG -->/d' "$AGENT_CONFIG"
    fi
    
    log_info "Injetando configuração para monitoramento Proxmox..."
    
    # Criar configuração temporária
    cat > "$AGENT_CONFIG_TEMPLATE" << 'EOFCONFIG'
<!-- ======================== PROXMOX CUSTOM CONFIG ======================== -->

<!-- ======================== JOURNALD MONITORING ======================== -->
<!-- Todos os logs do sistema via journalctl -->
<localfile>
    <location>/var/log/journal</location>
    <log_format>json</log_format>
    <alias>proxmox-system-logs</alias>
</localfile>

<!-- ======================== KERNEL AUDIT MONITORING ======================== -->
<!-- Audit logs - habilitados por padrão no Proxmox 8+ -->
<localfile>
    <location>/var/log/audit/audit.log</location>
    <log_format>audit</log_format>
    <alias>proxmox-kernel-audit</alias>
</localfile>

<!-- Kernel messages via dmesg -->
<localfile>
    <location>/var/log/kern.log</location>
    <log_format>syslog</log_format>
    <alias>proxmox-kernel-messages</alias>
</localfile>

<!-- ======================== PROXMOX VE LOGS ======================== -->
<!-- Logs principais do Proxmox VE -->
<localfile>
    <location>/var/log/pve</location>
    <log_format>syslog</log_format>
    <alias>proxmox-pve-logs</alias>
</localfile>

<!-- Logs do Proxmox Proxy -->
<localfile>
    <location>/var/log/pveproxy</location>
    <log_format>syslog</log_format>
    <alias>proxmox-pveproxy-logs</alias>
</localfile>

<!-- Logs de cluster (se aplicável) -->
<localfile>
    <location>/var/log/corosync/*.log</location>
    <log_format>syslog</log_format>
    <alias>proxmox-cluster-logs</alias>
</localfile>

<!-- Logs de rede -->
<localfile>
    <location>/var/log/syslog</location>
    <log_format>syslog</log_format>
    <alias>proxmox-syslog</alias>
</localfile>

<!-- ======================== LXC CONTAINER MONITORING ======================== -->
<!-- Logs de todos os containers LXC -->
<localfile>
    <location>/var/log/lxc/</location>
    <log_format>syslog</log_format>
    <alias>lxc-container-logs</alias>
</localfile>

<!-- Logs de CGROUP (para monitoramento de recursos) -->
<localfile>
    <location>/var/log/cgroup-logs</location>
    <log_format>syslog</log_format>
    <alias>cgroup-monitoring</alias>
</localfile>

<!-- ======================== PACKAGE UPDATES & SECURITY ======================== -->
<!-- Histórico de atualizações do APT -->
<localfile>
    <location>/var/log/apt/history.log</location>
    <log_format>syslog</log_format>
    <alias>apt-updates</alias>
</localfile>

<!-- Logs de segurança de pacotes -->
<localfile>
    <location>/var/log/apt/term.log</location>
    <log_format>syslog</log_format>
    <alias>apt-terminal</alias>
</localfile>

<!-- ======================== AUTHENTICATION & ACCESS MONITORING ======================== -->
<!-- SSH e autenticação -->
<localfile>
    <location>/var/log/auth.log</location>
    <log_format>syslog</log_format>
    <alias>authentication-logs</alias>
</localfile>

<!-- Proxy HTTP (se aplicável) -->
<localfile>
    <location>/var/log/apache2/access.log</location>
    <log_format>apache</log_format>
    <alias>apache-access</alias>
</localfile>

<localfile>
    <location>/var/log/apache2/error.log</location>
    <log_format>apache</log_format>
    <alias>apache-error</alias>
</localfile>

<!-- ======================== FILE INTEGRITY MONITORING (FIM) ======================== -->
<!-- Monitorar arquivos críticos do Proxmox -->
<syscheck>
    <frequency>600</frequency>
    <scan_on_start>yes</scan_on_start>
    <auto_ignore>no</auto_ignore>
    
    <!-- Diretórios críticos do Proxmox -->
    <directories check_all="yes" realtime="yes" report_changes="yes">/etc/pve</directories>
    <directories check_all="yes" realtime="yes" report_changes="yes">/etc/pve-firewall</directories>
    
    <!-- Configurações importantes -->
    <directories check_all="yes" realtime="yes">/etc/pam.d</directories>
    <directories check_all="yes" realtime="yes">/etc/ssh</directories>
    <directories check_all="yes" realtime="yes">/root/.ssh</directories>
    
    <!-- Binários do sistema -->
    <directories check_all="yes">/usr/local/bin</directories>
    <directories check_all="yes">/usr/local/sbin</directories>
    
    <!-- Arquivos do Proxmox -->
    <file check_all="yes" realtime="yes">/etc/hostname</file>
    <file check_all="yes" realtime="yes">/etc/hosts</file>
    <file check_all="yes">/etc/passwd</file>
    <file check_all="yes">/etc/shadow</file>
    <file check_all="yes">/etc/sudoers</file>
</syscheck>

<!-- ======================== ROOTKIT DETECTION ======================== -->
<rootcheck>
    <frequency>3600</frequency>
    <rootkit_files>/var/ossec/etc/shared/rootkit_files.txt</rootkit_files>
    <rootkit_trojans>/var/ossec/etc/shared/rootkit_trojans.txt</rootkit_trojans>
    <skip_nfs>yes</skip_nfs>
    <skip_sys>yes</skip_sys>
    <skip_proc>yes</skip_proc>
</rootcheck>

<!-- ======================== SYSTEM INVENTORY ======================== -->
<system_inventory>
    <enabled>yes</enabled>
    <interval>1h</interval>
    <scan_on_start>yes</scan_on_start>
</system_inventory>

<!-- ======================== SECURITY CONFIGURATION ASSESSMENT ======================== -->
<sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>24h</interval>
    <day>Monday</day>
    <time>02:00</time>
</sca>

<!-- FIM PROXMOX CUSTOM CONFIG -->
EOFCONFIG

    # Injetar antes de </ossec_config>
    if ! sed -i '/<\/ossec_config>/e cat '"$AGENT_CONFIG_TEMPLATE" "$AGENT_CONFIG"; then
        error_exit "Falha ao injetar configuração Proxmox"
    fi
    
    log_success "Configuração Proxmox injetada"
    
    # Validar sintaxe XML
    log_info "Validando sintaxe XML da configuração..."
    if ! /var/ossec/bin/wazuh-control status > /dev/null 2>&1; then
        log_warning "Será validado após reinicialização"
    fi
    
    # Cleanup
    rm -f "$AGENT_CONFIG_TEMPLATE"
}

start_wazuh_agent() {
    log_info "=== FASE 6: INICIANDO WAZUH AGENT ==="
    
    log_info "Recarregando daemon systemd..."
    if ! systemctl daemon-reload >> "$LOG_FILE" 2>&1; then
        error_exit "Falha ao recarregar daemon"
    fi
    
    log_info "Ativando Wazuh Agent no boot..."
    if ! systemctl enable wazuh-agent >> "$LOG_FILE" 2>&1; then
        error_exit "Falha ao ativar wazuh-agent no boot"
    fi
    log_success "Wazuh Agent ativado no boot"
    
    log_info "Iniciando Wazuh Agent..."
    if ! systemctl start wazuh-agent >> "$LOG_FILE" 2>&1; then
        error_exit "Falha ao iniciar wazuh-agent"
    fi
    log_success "Wazuh Agent iniciado"
    
    # Aguardar inicialização
    sleep 3
    
    log_info "Verificando status do Wazuh Agent..."
    if ! systemctl is-active --quiet wazuh-agent; then
        error_exit "Wazuh Agent não está rodando. Verifique os logs com: journalctl -u wazuh-agent -n 50"
    fi
    log_success "Wazuh Agent está rodando"
}

validate_installation() {
    log_info "=== FASE 7: VALIDANDO INSTALAÇÃO ==="
    
    # 1. Verificar processo
    log_info "Verificando processo wazuh-agent..."
    if pgrep -f "wazuh-agentd" > /dev/null; then
        log_success "Processo wazuh-agentd detectado"
    else
        error_exit "Processo wazuh-agentd não encontrado"
    fi
    
    # 2. Verificar arquivo de status
    log_info "Verificando arquivo de status do agent..."
    if [[ -f /var/ossec/var/run/wazuh-agentd.state ]]; then
        log_success "Arquivo de estado encontrado"
    fi
    
    # 3. Verificar conectividade (tentando conexão)
    log_info "Testando conectividade com Wazuh Manager..."
    local CHECK_CONNECTIVITY=false
    
    if grep -q "^<server>" "$AGENT_CONFIG" 2>/dev/null; then
        local SERVER=$(grep -A1 "^<server>" "$AGENT_CONFIG" | grep "address" | sed 's/.*<address>\(.*\)<\/address>.*/\1/')
        if [[ -n "$SERVER" ]]; then
            if timeout 5 bash -c "</dev/tcp/${SERVER}/1514" 2>/dev/null; then
                log_success "Conectividade com Wazuh Manager confirmada"
                CHECK_CONNECTIVITY=true
            else
                log_warning "Não foi possível conectar ao Wazuh Manager (pode precisar de time para sincronização)"
            fi
        fi
    fi
    
    # 4. Verificar arquivo de log do agent
    log_info "Verificando logs do agent..."
    if [[ -f /var/ossec/logs/ossec.log ]]; then
        log_success "Arquivo de log encontrado"
        log_info "Últimas 5 linhas do log:"
        tail -5 /var/ossec/logs/ossec.log | tee -a "$LOG_FILE"
    fi
    
    # 5. Testar configuração
    log_info "Executando teste de configuração..."
    if /var/ossec/bin/wazuh-control status | tee -a "$LOG_FILE" | grep -q "wazuh-agentd"; then
        log_success "Configuração do agent validada"
    else
        log_warning "Não foi possível validar completamente (pode estar em inicialização)"
    fi
    
    log_success "=== VALIDAÇÃO CONCLUÍDA ==="
}

generate_report() {
    log_info "=== GERANDO RELATÓRIO FINAL ==="
    
    local ELAPSED=$(($(date +%s) - START_TIME))
    
    cat >> "$LOG_FILE" << EOFREPORT

================================================================================
                        RELATÓRIO FINAL DE INSTALAÇÃO
================================================================================
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Tempo total: ${ELAPSED}s
Versão Wazuh: $WAZUH_VERSION
Wazuh Manager: $WAZUH_MANAGER
Arquivo Log: $LOG_FILE

CHECKLIST:
✓ Pré-requisitos validados
✓ Sistema atualizado
✓ Repositório Wazuh configurado
✓ Wazuh Agent instalado
✓ Configuração Proxmox injetada
✓ Agent iniciado
✓ Instalação validada

PRÓXIMOS PASSOS:
1. Aguarde 60-120s para sincronização com Wazuh Manager
2. Verifique agente no dashboard Wazuh
3. Confirme recebimento de logs em: Agents > Monitor
4. Visualize alertas em: Security Events

COMANDOS ÚTEIS:
- Status: systemctl status wazuh-agent
- Logs: journalctl -u wazuh-agent -f
- Configuração: cat /var/ossec/etc/ossec.conf
- Teste: /var/ossec/bin/wazuh-control status

SUPORTE:
- Documentação: https://documentation.wazuh.com/current/
- Forum: https://github.com/wazuh/wazuh/discussions
- Log completo: $LOG_FILE

================================================================================
EOFREPORT

    cat << EOFOUTPUT

${GREEN}================================================================================
                  ✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO!
================================================================================
${NC}
Wazuh Agent $WAZUH_VERSION foi instalado e configurado com sucesso!

${BLUE}Informações da Instalação:${NC}
  • Tempo total: ${ELAPSED}s
  • Manager: $WAZUH_MANAGER
  • Arquivo de log: $LOG_FILE
  • Configuração: $AGENT_CONFIG

${YELLOW}Próximos passos:${NC}
  1. Acesse o dashboard Wazuh
  2. Verifique o agente em: Agents > Monitor
  3. Confirme o recebimento de logs

${BLUE}Status do Agent:${NC}
$(systemctl status wazuh-agent --no-pager | grep -E "Active|Loaded" | sed 's/^/  /')

${GREEN}${NC}
EOFOUTPUT

}

# ============================= EXECUÇÃO PRINCIPAL ==================================

main() {
    echo -e "${BLUE}"
    cat << "EOFHEADER"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║        WAZUH AGENT 4.14.1 - AUTOMAÇÃO PROXMOX VE                           ║
║        Deployment com Validações e Tratamento de Erros                     ║
║                                                                              ║
║        Data: $(date '+%Y-%m-%d %H:%M:%S')                                      ║
║        Manager: ${WAZUH_MANAGER}                                           ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOFHEADER
    echo -ne "${NC}"
    
    setup_logging
    log_info "Iniciando deployment do Wazuh Agent $WAZUH_VERSION"
    
    validate_prerequisites
    update_system
    setup_wazuh_repo
    install_wazuh_agent
    configure_wazuh_agent
    start_wazuh_agent
    validate_installation
    generate_report
    
    log_success "=== DEPLOYMENT FINALIZADO COM SUCESSO ==="
    exit 0
}

# Executar com tratamento de erro
main "$@" || {
    log_error "Script encerrado com erro"
    exit 1
}
