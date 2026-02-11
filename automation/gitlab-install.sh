#!/usr/bin/env bash
# Title: Instalação do GitLab CE
# Description: Instala o GitLab Community Edition (versão mais recente) em LXC
# Supported: LXC
# Interactive: yes
# Reboot: no
# Network: safe
# License: GPL v3

# Definição de Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Iniciando instalação do GitLab CE...${NC}"

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Por favor, execute como root.${NC}"
  exit 1
fi

# Verificação de Recursos
MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
# 4GB = 4194304 KB
if [ "$MEM_KB" -lt 4000000 ]; then
    echo -e "${YELLOW}AVISO: O GitLab requer pelo menos 4GB de RAM. Detectado: $(($MEM_KB / 1024))MB.${NC}"
    echo -e "${YELLOW}A instalação pode falhar ou o sistema ficar instável.${NC}"

    # Se for Dry-Run, apenas avisar e continuar
    if [[ "${CS_DRY_RUN:-}" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN] Ignorando verificação de memória.${NC}"
    # Se não for interativo, abortar (a menos que forçado, mas aqui é seguro falhar)
    elif [[ ! -t 0 ]]; then
        echo -e "${RED}Ambiente não interativo e memória insuficiente. Abortando.${NC}"
        exit 1
    else
        read -p "Deseja continuar mesmo assim? (s/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            echo -e "${RED}Instalação cancelada.${NC}"
            exit 1
        fi
    fi
fi

echo -e "${YELLOW}Atualizando listas de pacotes...${NC}"
apt-get update

echo -e "${YELLOW}Instalando dependências...${NC}"
# Dependências essenciais conforme documentação oficial
apt-get install -y curl openssh-server ca-certificates tzdata perl

# Instalação do Postfix (Se não existir)
if ! command -v postfix &> /dev/null; then
    echo -e "${YELLOW}Instalando Postfix para envio de e-mails...${NC}"
    # Configuração automática para evitar prompts interativos
    echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
    echo "postfix postfix/mailname string $(hostname -f)" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
fi

echo -e "${YELLOW}Adicionando repositório oficial do GitLab...${NC}"
curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash

# Configuração da URL Externa
CURRENT_IP=$(hostname -I | awk '{print $1}')
DEFAULT_URL="http://$CURRENT_IP"
EXTERNAL_URL="$DEFAULT_URL"

# Se o script estiver rodando interativamente (detectado pelo setup.sh ou terminal)
if [ -t 0 ]; then
    echo -e "${YELLOW}Configuração de URL Externa${NC}"
    echo -e "O endereço padrão será: ${GREEN}$DEFAULT_URL${NC}"
    read -p "Deseja alterar o endereço (ex: http://gitlab.meudominio.com)? [s/N] " -r
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        read -p "Digite a URL completa (com http:// ou https://): " USER_URL
        if [[ -n "$USER_URL" ]]; then
            EXTERNAL_URL="$USER_URL"
        fi
    fi
fi

echo -e "${YELLOW}Instalando GitLab CE (EXTERNAL_URL=$EXTERNAL_URL)...${NC}"
echo -e "${YELLOW}Isso pode demorar alguns minutos dependendo da sua conexão e hardware.${NC}"

# Instalação propriamente dita
EXTERNAL_URL="$EXTERNAL_URL" apt-get install -y gitlab-ce

if [ $? -eq 0 ]; then
    echo -e "${GREEN}GitLab CE instalado com sucesso!${NC}"
    echo -e "Acesse via navegador em: ${GREEN}$EXTERNAL_URL${NC}"
    echo -e "\nA senha inicial do usuário 'root' foi gerada automaticamente em:"
    echo -e "${YELLOW}/etc/gitlab/initial_root_password${NC}"
    echo -e "(Este arquivo será excluído automaticamente após 24 horas)"
    echo -e "\nPara reconfigurar no futuro, edite /etc/gitlab/gitlab.rb e execute 'gitlab-ctl reconfigure'."
else
    echo -e "${RED}A instalação do GitLab CE falhou. Verifique os logs acima.${NC}"
    exit 1
fi
