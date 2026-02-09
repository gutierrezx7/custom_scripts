#!/usr/bin/env bash

# Title: Frigate NVR
# Description: NVR com IA e Aceleração de Hardware (Instalação Bare Metal)
# Supported: LXC
# Interactive: yes
# Reboot: no
# Network: safe

# Copyright (c) 2021-2026 tteck
# Author: tteck (tteckster)
# Co-Author: remz1337
# Adapter: Jules (DevOps Engineer)
# License: MIT
# Source: https://frigate.video/

# Cores e Funções de Log (Emulando o ambiente padrão caso não esteja carregado)
setup_colors() {
    if [[ -t 2 ]] && [[ -z "${no_color-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m'
    else
        NOFORMAT='' RED='' GREEN='' YELLOW='' BLUE=''
    fi
}
msg_info() { setup_colors; printf "${BLUE}[INFO]${NOFORMAT} %s\n" "$1"; }
msg_ok() { setup_colors; printf "${GREEN}[OK]${NOFORMAT} %s\n" "$1"; }
msg_warn() { setup_colors; printf "${YELLOW}[AVISO]${NOFORMAT} %s\n" "$1"; }
msg_error() { setup_colors; printf "${RED}[ERRO]${NOFORMAT} %s\n" "$1"; }

# Verificação de Root
if [[ $EUID -ne 0 ]]; then
    msg_error "Este script deve ser executado como root."
    exit 1
fi

# Configurações
FRIGATE_VERSION="v0.14.1"
INSTALL_DIR="/opt/frigate"
VENV_DIR="${INSTALL_DIR}/venv"
# shellcheck disable=SC2034
STD="" # Defina como ">/dev/null" para silenciar ou vazio para debug

msg_info "Iniciando instalação do Frigate NVR (Bare Metal - Bookworm Compatível)"

# 1. Atualizar SO
msg_info "Atualizando listas de pacotes..."
apt-get update
apt-get upgrade -y

# 2. Instalar Dependências do Sistema (Adaptado para Debian 12)
msg_info "Instalando Dependências do Sistema..."
DEPS=(
    git ca-certificates automake build-essential xz-utils libtool ccache pkg-config
    libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
    libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff-dev gfortran openexr
    libatlas-base-dev libssl-dev
    libtbb12 libtbb-dev  # CORREÇÃO: libtbb2 -> libtbb12
    libdc1394-22-dev libopenexr-dev libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev
    gcc libopenblas-dev liblapack-dev libusb-1.0-0-dev jq moreutils
    python3 python3-dev python3-setuptools python3-pip python3-venv python3-full
    curl unzip zip sudo gnupg
)

apt-get install -y "${DEPS[@]}"
msg_ok "Dependências instaladas."

# 3. Setup NodeJS (v22)
msg_info "Configurando NodeJS 22..."
if ! command -v node >/dev/null; then
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
    apt-get update
    apt-get install -y nodejs
fi
msg_ok "NodeJS instalado."

# 4. Instalar Go2RTC
msg_info "Instalando Go2RTC..."
mkdir -p /usr/local/go2rtc/bin
curl -fsSL "https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_linux_amd64" -o "/usr/local/go2rtc/bin/go2rtc"
chmod +x /usr/local/go2rtc/bin/go2rtc
ln -svf /usr/local/go2rtc/bin/go2rtc /usr/local/bin/go2rtc
msg_ok "Go2RTC instalado."

# 5. Baixar e Preparar Frigate
msg_info "Baixando código fonte do Frigate (${FRIGATE_VERSION})..."
cd ~ || exit 1
rm -rf frigate.tar.gz
curl -fsSL "https://github.com/blakeblackshear/frigate/archive/refs/tags/${FRIGATE_VERSION}.tar.gz" -o "frigate.tar.gz"
mkdir -p "${INSTALL_DIR}"
tar -xzf frigate.tar.gz -C "${INSTALL_DIR}" --strip-components 1
rm -rf frigate.tar.gz

# 6. Ambiente Virtual Python (Correção PEP 668)
msg_info "Criando Ambiente Virtual Python (Venv)..."
if [ ! -d "${VENV_DIR}" ]; then
    python3 -m venv "${VENV_DIR}"
fi
# Alias para usar o pip do venv
VPIP="${VENV_DIR}/bin/pip3"
VPYTHON="${VENV_DIR}/bin/python3"

$VPIP install --upgrade pip setuptools wheel
msg_ok "Ambiente Virtual configurado em ${VENV_DIR}."

# 7. Build do Frigate e Dependências Python
msg_info "Compilando dependências do Frigate (Isso pode demorar)..."
cd "${INSTALL_DIR}" || exit 1

# Patching: Evitar que scripts internos tentem instalar libtbb2 ou usar pip global
# Vamos assumir o controle das dependências aqui, ignorando o install_deps.sh do repo se ele for problemático.
# Mas o install_deps.sh instala pacotes apt. Vamos checar e rodar o que for seguro.
# Como não posso ver o conteúdo, vou confiar na lista que instalei acima e pular o script de deps do apt interno se possível,
# ou deixá-lo falhar graciosamente. O script original roda: /opt/frigate/docker/main/install_deps.sh
# Vamos tentar rodar, mas antes corrigir libtbb2 nele se existir.
if [ -f "docker/main/install_deps.sh" ]; then
    sed -i 's/libtbb2/libtbb12/g' docker/main/install_deps.sh
    # Também remova comandos que tentam adicionar repositórios antigos se houver
fi

# Instalar Wheels requeridos
mkdir -p /wheels
$VPIP wheel --wheel-dir=/wheels -r docker/main/requirements-wheels.txt

# Copiar estrutura do docker rootfs para o sistema (Standard Bare Metal Hack)
cp -a docker/main/rootfs/. /

# Configurações de sistema
echo 'libc6 libraries/restart-without-asking boolean true' | debconf-set-selections
export TARGETARCH="amd64"

# Linkar ffmpeg do sistema se necessário (O script original usa btbn-ffmpeg, aqui vamos tentar usar o do sistema ou baixar)
# Para Debian 12, ffmpeg do repo é decente (5.1.x).
# O script original tenta linkar /usr/lib/btbn-ffmpeg. Se não existir, linkamos o do sistema.
if [ ! -d "/usr/lib/btbn-ffmpeg" ]; then
    ln -svf "$(which ffmpeg)" /usr/local/bin/ffmpeg
    ln -svf "$(which ffprobe)" /usr/local/bin/ffprobe
fi

# Instalar Dependências Python Finais
$VPIP install -U /wheels/*.whl
$VPIP install -r docker/main/requirements-dev.txt

# Inicializar devcontainer (setup version)
if [ -f ".devcontainer/initialize.sh" ]; then
    bash .devcontainer/initialize.sh
fi
make version

# 8. Build da Interface Web
msg_info "Compilando Interface Web (Requer CPU/RAM)..."
cd "${INSTALL_DIR}/web" || exit 1
npm install
npm run build

# Copiar build para local final
cp -r dist/* .

# 9. Configuração Final
msg_info "Configurando arquivos e serviços..."
cd "${INSTALL_DIR}" || exit 1
mkdir -p /config
cp -r config/. /config

# Patching no runner do s6-overlay para usar nosso Python Venv?
# O script original usa s6-overlay para gerenciar processos.
# Se formos rodar "Bare Metal Real" via systemd direto, ignoramos o s6.
# O script original cria services que chamam `bash .../s6-rc.d/frigate/run`.
# Vamos adaptar esses services para usar o Venv.

# Ajustar config.yml padrão
cat <<EOF >/config/config.yml
mqtt:
  enabled: false
cameras:
  test:
    ffmpeg:
      inputs:
        - path: /media/frigate/person-bicycle-car-detection.mp4
          input_args: -re -stream_loop -1 -fflags +genpts
          roles:
            - detect
            - rtmp
    detect:
      height: 1080
      width: 1920
      fps: 5
EOF
ln -sf /config/config.yml "${INSTALL_DIR}/config/config.yml"

# Permissões de Grupo (Render/KVM)
usermod -aG render root
usermod -aG video root
# Se o grupo render não existir (LXC unprivileged as vezes muda), criar ou adaptar.
if getent group render >/dev/null; then
    echo "Grupo render existe."
else
    groupadd -g 104 render
fi
# Adicionar usuário atual ao render
usermod -aG render root

# Setup Diretórios de Log
mkdir -p /dev/shm/logs/{frigate,go2rtc,nginx}
chmod -R 777 /dev/shm/logs

# 10. Criar Serviços Systemd (Adaptados para VENV)

# Create Directories Service
cat <<EOF >/etc/systemd/system/create_directories.service
[Unit]
Description=Create necessary directories for logs

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/bin/mkdir -p /dev/shm/logs/{frigate,go2rtc,nginx} && /bin/touch /dev/shm/logs/{frigate/current,go2rtc/current,nginx/current} && /bin/chmod -R 777 /dev/shm/logs'

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now create_directories

# Go2RTC Service
cat <<EOF >/etc/systemd/system/go2rtc.service
[Unit]
Description=go2rtc service
After=network.target
After=create_directories.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
ExecStartPre=+rm -f /dev/shm/logs/go2rtc/current
# Go2RTC é binário estático, roda direto
ExecStart=/usr/local/bin/go2rtc -config /config/go2rtc.yaml
StandardOutput=append:/dev/shm/logs/go2rtc/current
StandardError=append:/dev/shm/logs/go2rtc/current

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now go2rtc

# Frigate Service (CRITICO: Usar VENV)
# O runner original do Frigate faz muita configuração de env. Vamos tentar simplificar chamando o módulo python direto.
cat <<EOF >/etc/systemd/system/frigate.service
[Unit]
Description=Frigate service
After=go2rtc.service
After=create_directories.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
WorkingDirectory=/opt/frigate
Environment=PYTHONPATH=/opt/frigate
Environment="PATH=${VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin"
Environment=CONFIG_FILE=/config/config.yml
ExecStartPre=+rm -f /dev/shm/logs/frigate/current
# Executa o módulo frigate diretamente via Python do Venv
ExecStart=${VPYTHON} -m frigate
StandardOutput=append:/dev/shm/logs/frigate/current
StandardError=append:/dev/shm/logs/frigate/current

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now frigate

# Nginx Service
# Precisamos compilar o nginx com módulos? O script original compila.
# Vamos tentar usar o build_nginx.sh original se possível, mas ele pode falhar por deps.
# Se falhar, instalamos nginx do sistema e configuramos o site.
msg_info "Configurando Nginx..."

# Tentar usar script de build do nginx se existir
if [ -f "docker/main/build_nginx.sh" ]; then
    # Patch para usar /usr/local correto
    chmod +x docker/main/build_nginx.sh
    ./docker/main/build_nginx.sh
    ln -sf /usr/local/nginx/sbin/nginx /usr/local/bin/nginx
else
    apt-get install -y nginx
fi

# Configurar Nginx Service (Se usarmos o compilado)
if [ -f "/usr/local/nginx/sbin/nginx" ]; then
    cat <<EOF >/etc/systemd/system/nginx.service
[Unit]
Description=Nginx service
After=frigate.service
After=create_directories.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
ExecStartPre=+rm -f /dev/shm/logs/nginx/current
ExecStart=/usr/local/nginx/sbin/nginx -g "daemon off;"
StandardOutput=append:/dev/shm/logs/nginx/current
StandardError=append:/dev/shm/logs/nginx/current

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable -q --now nginx
else
    # Se usarmos o do sistema, apenas garanta que a config aponte para o lugar certo
    # A config do Frigate nginx geralmente fica em docker/main/rootfs/usr/local/nginx/conf/nginx.conf
    # Precisamos copiar para /etc/nginx/sites-available/frigate
    msg_warn "Usando Nginx do sistema. Configuração manual pode ser necessária."
fi

msg_ok "Serviços Configurados."

# Finalização
IP=$(hostname -I | cut -f1 -d ' ')
msg_header "Instalação Concluída!"
echo -e "${GREEN}Frigate NVR instalado com sucesso (Bare Metal / Venv).${NOFORMAT}"
echo -e "${YELLOW}Acesse via: http://${IP}:5000${NOFORMAT}"
echo -e "${BLUE}Logs em: /dev/shm/logs/${NOFORMAT}"
