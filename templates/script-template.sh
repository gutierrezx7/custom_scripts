#!/bin/bash

#############################################################
# Nome do Script: script-template.sh
# Descrição: Template básico para scripts shell
# Autor: Seu Nome
# Data: $(date +%d/%m/%Y)
# Versão: 1.0
# Licença: GPL-3.0
#############################################################

# Configurações de segurança
set -e  # Sair em caso de erro
set -u  # Tratar variáveis não definidas como erro
set -o pipefail  # Falhar em pipes

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Variáveis globais
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/${SCRIPT_NAME%.sh}.log"

#############################################################
# Funções auxiliares
#############################################################

# Mensagem de informação
msg_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Mensagem de erro
msg_error() {
    echo -e "${RED}[ERRO]${NC} $1" >&2
}

# Mensagem de aviso
msg_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Mensagem de debug
msg_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Função de ajuda
show_help() {
    cat << EOF
Uso: $SCRIPT_NAME [opções]

Descrição:
    Template básico para scripts shell

Opções:
    -h, --help          Mostra esta mensagem de ajuda
    -v, --verbose       Modo verbose
    -d, --debug         Modo debug
    -V, --version       Mostra a versão

Exemplos:
    $SCRIPT_NAME --help
    $SCRIPT_NAME --verbose

EOF
    exit 0
}

# Verificar se está rodando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "Este script precisa ser executado como root"
        exit 1
    fi
}

# Verificar se comandos necessários estão instalados
check_dependencies() {
    local deps=("curl" "wget")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        msg_error "Dependências não encontradas: ${missing[*]}"
        msg_info "Instale com: sudo apt-get install ${missing[*]}"
        exit 1
    fi
}

# Verificar conectividade com internet
check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        msg_error "Sem conexão com a internet"
        exit 1
    fi
}

# Cleanup ao sair
cleanup() {
    msg_debug "Executando limpeza..."
    # Adicione comandos de limpeza aqui
}

# Trap para executar cleanup
trap cleanup EXIT INT TERM

#############################################################
# Função principal
#############################################################

main() {
    msg_info "Iniciando $SCRIPT_NAME..."
    
    # Verificações iniciais
    # check_root
    # check_dependencies
    # check_internet
    
    # Seu código aqui
    msg_info "Executando lógica principal..."
    
    # Exemplo de processamento
    # ...
    
    msg_info "Script concluído com sucesso!"
}

#############################################################
# Processamento de argumentos
#############################################################

# Se nenhum argumento, mostrar ajuda
if [[ $# -eq 0 ]]; then
    show_help
fi

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        -d|--debug)
            DEBUG=1
            shift
            ;;
        -V|--version)
            echo "$SCRIPT_NAME versão 1.0"
            exit 0
            ;;
        *)
            msg_error "Opção desconhecida: $1"
            show_help
            ;;
    esac
done

#############################################################
# Executar script
#############################################################

main "$@"
