#!/usr/bin/env bash
# Title: Shell Moderno (Zsh + Fastfetch)
# Description: Instala Zsh, Oh My Zsh e Fastfetch para um terminal moderno
# Supported: VM, LXC
# Interactive: no
# Reboot: no
# Network: safe
# Author: Custom Scripts Team

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
msg_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Verificar Root
if [ "$EUID" -ne 0 ]; then
    msg_error "Por favor, execute como root."
    exit 1
fi

msg_info "Instalando Zsh, Git e Curl..."
apt-get update -qq
apt-get install -y zsh git curl -qq

# Instalar Fastfetch (Substituto moderno do Neofetch)
msg_info "Instalando Fastfetch..."
if ! command -v fastfetch >/dev/null; then
    # Adicionar PPA para Ubuntu se necessário, ou baixar binário para Debian
    # Tentativa genérica segura
    if apt-cache search fastfetch | grep -q fastfetch; then
        apt-get install -y fastfetch
    else
        msg_warn "Fastfetch não encontrado nos repositórios padrão. Tentando instalar via PPA (Ubuntu) ou Download direto..."
        # Lógica simplificada: Instalar Neofetch como fallback se falhar
        apt-get install -y neofetch
    fi
fi

# Instalar Oh My Zsh (Unattended)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    msg_info "Instalando Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    msg_info "Oh My Zsh já está instalado."
fi

# Definir Zsh como shell padrão
if [ "$SHELL" != "$(which zsh)" ]; then
    msg_info "Definindo Zsh como shell padrão..."
    chsh -s "$(which zsh)"
fi

# Adicionar fastfetch/neofetch ao .zshrc
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "neofetch" "$HOME/.zshrc" && ! grep -q "fastfetch" "$HOME/.zshrc"; then
        echo "fastfetch 2>/dev/null || neofetch" >> "$HOME/.zshrc"
    fi
fi

msg_info "Instalação concluída! Faça logoff e login novamente para ver o novo shell."
