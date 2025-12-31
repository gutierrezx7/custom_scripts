#!/usr/bin/env bash

# Master Setup Script para VMs
# Part of Custom Scripts
# License: GPL v3

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções de Log
msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
msg_error() { echo -e "${RED}[ERRO]${NC} $1"; }
msg_title() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Verificar Root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        msg_error "Por favor, execute como root."
        exit 1
    fi
}

# Verificar Ambiente (Deve ser VM)
check_env() {
    msg_info "Verificando ambiente..."
    if command -v systemd-detect-virt >/dev/null; then
        VIRT=$(systemd-detect-virt)
        if [ "$VIRT" == "lxc" ]; then
            msg_error "Este script é destinado apenas para Máquinas Virtuais (VMs)."
            msg_error "Detectado container LXC. Por favor, use o script setup-lxc.sh."
            exit 1
        fi
        msg_info "Ambiente detectado: $VIRT (Compatível)"
    else
        msg_warn "Não foi possível detectar o tipo de virtualização. Assumindo VM."
    fi
}

# 1. Preparação do Sistema
system_prep() {
    msg_title "Preparação do Sistema"

    msg_info "Atualizando pacotes (apt update & upgrade)..."
    apt-get update && apt-get upgrade -y

    # Hostname
    CURRENT_HOSTNAME=$(hostname)
    read -p "Digite o novo Hostname [$CURRENT_HOSTNAME]: " NEW_HOSTNAME
    NEW_HOSTNAME=${NEW_HOSTNAME:-$CURRENT_HOSTNAME}

    if [ "$NEW_HOSTNAME" != "$CURRENT_HOSTNAME" ]; then
        hostnamectl set-hostname "$NEW_HOSTNAME"
        sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
        msg_info "Hostname alterado para $NEW_HOSTNAME"
    fi

    # Ferramentas Básicas
    msg_info "Instalando ferramentas essenciais..."
    apt-get install -y curl wget git htop unzip nano
    msg_info "Preparação concluída."
}

# 2. Configuração de Rede
network_config() {
    msg_title "Configuração de Rede (IP Estático)"
    msg_warn "ATENÇÃO: Alterar o IP via SSH pode desconectar sua sessão."

    # Identificar interface
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    read -p "Interface de Rede detectada [$INTERFACE]: " INPUT_IF
    INTERFACE=${INPUT_IF:-$INTERFACE}

    read -p "Endereço IP desejado (ex: 192.168.1.50/24): " IP_ADDR
    read -p "Gateway (ex: 192.168.1.1): " GATEWAY
    read -p "DNS (ex: 8.8.8.8, 1.1.1.1): " DNS_SERVERS

    if [[ -z "$IP_ADDR" || -z "$GATEWAY" || -z "$DNS_SERVERS" ]]; then
        msg_error "Dados incompletos. Pulando configuração de rede."
        return
    fi

    NETPLAN_FILE="/etc/netplan/99-custom.yaml"

    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $IP_ADDR
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVERS]
EOF

    msg_info "Arquivo criado: $NETPLAN_FILE"
    chmod 600 "$NETPLAN_FILE"

    read -p "Deseja aplicar as configurações agora? Isso pode desconectar você. (s/n): " APPLY
    if [[ "$APPLY" =~ ^[Ss]$ ]]; then
        msg_warn "Aplicando configurações em 5 segundos..."
        msg_warn "Se desconectar, reconecte-se no novo IP: ${IP_ADDR%/*}"
        sleep 5
        netplan apply
    fi
}

# 3. Docker
install_docker() {
    msg_title "Instalação do Docker"
    # Baixar script oficial do repo se não existir localmente, ou usar caminho relativo se estiver no repo clonado
    if [ -f "docker/docker-install.sh" ]; then
        bash docker/docker-install.sh
    else
        msg_warn "Script docker/docker-install.sh não encontrado localmente."
        msg_info "Baixando do repositório..."
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/docker/docker-install.sh)"
    fi
}

# 4. Segurança (Firewall)
setup_firewall() {
    msg_title "Configuração de Firewall (UFW)"

    if ! command -v ufw >/dev/null; then
        apt-get install -y ufw
    fi

    msg_info "Configurando regras padrão..."
    ufw default deny incoming
    ufw default allow outgoing

    msg_info "Liberando porta 22 (SSH)..."
    ufw allow 22/tcp

    msg_info "Liberando portas HTTP/HTTPS (80/443)..."
    ufw allow 80/tcp
    ufw allow 443/tcp

    msg_info "Liberando porta 8000 (Supabase API)..."
    ufw allow 8000/tcp

    msg_info "Liberando porta 5678 (n8n Workflow)..."
    ufw allow 5678/tcp

    read -p "Deseja ativar o firewall agora? (s/n): " ENABLE_UFW
    if [[ "$ENABLE_UFW" =~ ^[Ss]$ ]]; then
        echo "y" | ufw enable
        msg_info "Firewall ativado."
    fi
}

# 5. Workspace
setup_workspace() {
    msg_title "Estrutura de Pastas (Workspace)"
    TARGET_DIR="/opt/stack"

    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
        msg_info "Diretório criado: $TARGET_DIR"
        chmod 755 "$TARGET_DIR"
    else
        msg_info "Diretório já existe: $TARGET_DIR"
    fi
}

# Menu Principal
show_menu() {
    clear
    msg_title "Custom Scripts - Configuração de VM"
    echo "1. Preparação do Sistema (Update, Hostname, Tools)"
    echo "2. Configuração de Rede (Static IP via Netplan)"
    echo "3. Motor Docker (Instalação Oficial + Grupo)"
    echo "4. Segurança (Firewall UFW)"
    echo "5. Estrutura de Pastas (/opt/stack)"
    echo "6. INSTALAR TUDO (Sequencial 1-5)"
    echo "0. Sair"
    echo
}

main() {
    check_root
    check_env

    while true; do
        show_menu
        read -p "Escolha uma opção: " OPTION

        case $OPTION in
            1) system_prep ;;
            2) network_config ;;
            3) install_docker ;;
            4) setup_firewall ;;
            5) setup_workspace ;;
            6)
                system_prep
                network_config
                install_docker
                setup_firewall
                setup_workspace
                ;;
            0) exit 0 ;;
            *) msg_error "Opção inválida!" ;;
        esac

        read -p "Pressione Enter para continuar..."
    done
}

main
