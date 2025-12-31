#!/usr/bin/env bash

# Docker Installer (VM & LXC)
# Part of Custom Scripts
# License: GPL v3

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
msg_error() { echo -e "${RED}[ERRO]${NC} $1"; }

echo -e "${GREEN}Iniciando Instalação do Docker...${NC}"

# Verificar root
if [ "$EUID" -ne 0 ]; then
  msg_error "Por favor, execute como root."
  exit 1
fi

# Detectar Ambiente (VM ou LXC)
ENV_TYPE="vm"
if command -v systemd-detect-virt >/dev/null; then
    VIRT=$(systemd-detect-virt)
    if [ "$VIRT" == "lxc" ]; then
        ENV_TYPE="lxc"
    fi
fi

msg_info "Ambiente detectado: $ENV_TYPE"

echo -e "${YELLOW}Atualizando sistema...${NC}"
apt-get update

echo -e "${YELLOW}Instalando pré-requisitos...${NC}"
apt-get install -y ca-certificates curl gnupg

echo -e "${YELLOW}Adicionando chave GPG oficial do Docker...${NC}"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo -e "${YELLOW}Adicionando repositório do Docker...${NC}"
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

echo -e "${YELLOW}Instalando Docker Engine...${NC}"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo -e "${YELLOW}Verificando instalação...${NC}"
docker --version

if [ $? -eq 0 ]; then
    msg_info "Docker instalado com sucesso!"

    # Configurações Específicas
    if [ "$ENV_TYPE" == "lxc" ]; then
        msg_warn "Nota para usuários LXC: Certifique-se de que as opções 'Nesting' e 'keyctl' estejam ativadas nas opções do Container no Proxmox."
    else
        # VM - Adicionar usuário ao grupo docker
        TARGET_USER="$SUDO_USER"
        if [ -z "$TARGET_USER" ]; then
            read -p "Digite o nome do usuário para adicionar ao grupo docker (deixe em branco para pular): " TARGET_USER
        fi

        if [ -n "$TARGET_USER" ]; then
            if id "$TARGET_USER" &>/dev/null; then
                usermod -aG docker "$TARGET_USER"
                msg_info "Usuário '$TARGET_USER' adicionado ao grupo docker."
                msg_warn "Você precisará sair e entrar novamente (logoff/login) para que as permissões de grupo tenham efeito."
            else
                msg_error "Usuário '$TARGET_USER' não encontrado. Pulando etapa."
            fi
        fi
    fi
else
    msg_error "Falha na instalação do Docker."
    exit 1
fi
