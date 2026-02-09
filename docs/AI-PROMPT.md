# 🤖 Guia para IA - Desenvolvendo Scripts para Custom Scripts

> **Este documento é uma instrução para modelos de IA (ChatGPT, Copilot, Claude, etc.)
> gerarem scripts 100% compatíveis com o projeto Custom Scripts.**

---

## 📋 Contexto do Projeto

Este é um repositório de scripts Linux para automação de servidores, HomeLab e DevOps.
Os scripts são descobertos **automaticamente** pelo menu principal (`setup.sh`) — basta
colocar o arquivo `.sh` na pasta correta com o cabeçalho de metadados correto.

**Não é necessário editar nenhum outro arquivo.** O sistema de auto-discovery faz tudo.

---

## 🔑 Regras Obrigatórias

### 1. Cabeçalho de Metadados (OBRIGATÓRIO)

Todo script DEVE começar com estas linhas **exatamente neste formato** nas primeiras 30 linhas:

```bash
#!/usr/bin/env bash
# Title:       Nome Amigável em Português
# Description: Descrição curta em uma linha do que o script faz
# Supported:   ALL
# Interactive:  no
# Reboot:      no
# Network:     safe
# DryRun:      yes
# Version:     1.0
# Tags:        tag1, tag2, tag3
# Author:      Nome do Autor
```

**Campos:**

| Campo | Obrigatório | Valores | Descrição |
|-------|:-----------:|---------|-----------|
| `Title` | ✅ | Texto livre | Nome amigável exibido no menu |
| `Description` | ✅ | Texto livre | Descrição de 1 linha |
| `Supported` | ✅ | `ALL`, `VM`, `LXC`, `VM, LXC` | Ambientes compatíveis |
| `Interactive` | ✅ | `yes` / `no` | Precisa de input do usuário? |
| `Reboot` | ✅ | `yes` / `no` | Requer reboot após execução? |
| `Network` | ✅ | `safe` / `risk` | Altera configuração de rede? |
| `DryRun` | ✅ | `yes` / `no` | Suporta `--dry-run` nativo? |
| `Version` | ⬚ | `X.Y` | Versão do script |
| `Tags` | ⬚ | CSV | Tags para busca |
| `Author` | ⬚ | Texto | Autor do script |

> ⚠️ Se `Title` estiver faltando, o script será **ignorado** pelo menu.

### 2. Shebang

Sempre usar:
```bash
#!/usr/bin/env bash
```

### 3. Strict Mode

Sempre incluir após o cabeçalho:
```bash
set -euo pipefail
```

### 4. Carregar Biblioteca Compartilhada

O script DEVE tentar carregar `lib/common.sh` com fallback inline:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_FILE="${SCRIPT_DIR}/../lib/common.sh"

if [[ -f "$LIB_FILE" ]]; then
    source "$LIB_FILE"
else
    # Fallback mínimo para execução standalone
    CS_DRY_RUN="${CS_DRY_RUN:-false}"
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; NC='\033[0m'
    msg_info()    { echo -e "${GREEN}[INFO]${NC}    $1"; }
    msg_warn()    { echo -e "${YELLOW}[AVISO]${NC}   $1"; }
    msg_error()   { echo -e "${RED}[ERRO]${NC}    $1" >&2; }
    msg_header()  { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
    msg_step()    { echo -e "  ➜ $1"; }
    msg_dry_run() { echo -e "${MAGENTA}[DRY-RUN]${NC} $1"; }
    cs_run() {
        if [[ "${CS_DRY_RUN}" == "true" ]]; then
            msg_dry_run "$ $*"; return 0
        fi
        "$@"
    }
    check_root() {
        [[ $EUID -ne 0 ]] && { msg_error "Execute como root."; exit 1; }
    }
fi
```

### 5. Suporte a `--dry-run`

**Todos os novos scripts DEVEM suportar `--dry-run`.** O campo `DryRun: yes` no cabeçalho.

Use `cs_run` como wrapper em TODOS os comandos que alteram o sistema:

```bash
# ✅ CORRETO - usa cs_run
cs_run apt-get install -y nginx
cs_run systemctl enable nginx
cs_run cp /tmp/config /etc/nginx/nginx.conf

# ❌ ERRADO - executa direto
apt-get install -y nginx
systemctl enable nginx
```

Para operações que não são comandos (criar arquivos, etc):

```bash
if [[ "${CS_DRY_RUN}" == "true" ]]; then
    msg_dry_run "Criaria arquivo /etc/app/config.yaml"
else
    cat > /etc/app/config.yaml << 'EOF'
    setting: value
EOF
fi
```

### 6. Parse de Argumentos

Incluir no mínimo `--dry-run`, `--verbose` e `--help`:

```bash
show_help() {
    cat << 'EOF'
Uso: nome-do-script.sh [opções]

Opções:
  --dry-run     Simular execução sem fazer alterações
  --verbose     Modo detalhado
  --help, -h    Mostrar esta ajuda
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  CS_DRY_RUN=true; shift ;;
        --verbose)  CS_VERBOSE=true; shift ;;
        --help|-h)  show_help ;;
        *)          msg_error "Opção desconhecida: $1"; show_help ;;
    esac
done
```

### 7. Estrutura de Funções

Organizar em funções claras com responsabilidade única:

```bash
preflight()    # Verificações: root, dependências, compatibilidade
install()      # Lógica principal de instalação
post_install() # Habilitar serviços, verificar status
cleanup()      # Limpar arquivos temporários
main()         # Orquestrar tudo
```

---

## 📁 Onde Colocar o Script

| Categoria | Pasta | Exemplos |
|-----------|-------|----------|
| Sistema & Utilitários | `system-admin/` | Setup workspace, shell moderno |
| Docker & DevOps | `docker/` | Docker, NPM, Watchtower |
| Redes | `network/` | Tailscale, AdGuard, IP estático |
| Segurança | `security/` | Fail2Ban, Firewall, Wazuh |
| Monitoramento | `monitoring/` | Netdata, Frigate |
| Manutenção | `maintenance/` | Limpeza, otimização |
| Backup | `backup/` | Backup MySQL, rsync |
| Automação | `automation/` | GitLab, n8n |

> Crie novas pastas se necessário. O auto-discovery escaneia TODAS as pastas.

---

## 🏗️ Template Completo

Use este template como base. Copie e adapte:

```bash
#!/usr/bin/env bash
# Title:       Instalar MeuApp
# Description: Instala e configura o MeuApp no sistema
# Supported:   ALL
# Interactive:  no
# Reboot:      no
# Network:     safe
# DryRun:      yes
# Version:     1.0
# Tags:        meuapp, ferramenta
# Author:      Seu Nome

set -euo pipefail

# ── Carregar biblioteca ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_FILE="${SCRIPT_DIR}/../lib/common.sh"
if [[ -f "$LIB_FILE" ]]; then
    source "$LIB_FILE"
else
    CS_DRY_RUN="${CS_DRY_RUN:-false}"
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; NC='\033[0m'
    msg_info()    { echo -e "${GREEN}[INFO]${NC}    $1"; }
    msg_warn()    { echo -e "${YELLOW}[AVISO]${NC}   $1"; }
    msg_error()   { echo -e "${RED}[ERRO]${NC}    $1" >&2; }
    msg_header()  { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
    msg_step()    { echo -e "  ➜ $1"; }
    msg_dry_run() { echo -e "${MAGENTA}[DRY-RUN]${NC} $1"; }
    cs_run() {
        if [[ "${CS_DRY_RUN}" == "true" ]]; then
            msg_dry_run "$ $*"; return 0
        fi
        "$@"
    }
    check_root() {
        [[ $EUID -ne 0 ]] && { msg_error "Execute como root."; exit 1; }
    }
fi

# ── Argumentos ───────────────────────────────────────────────────────────────
show_help() {
    cat << 'EOF'
Uso: meuapp-install.sh [opções]

Opções:
  --dry-run     Simular sem instalar
  --verbose     Modo detalhado
  --help, -h    Mostrar ajuda
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  CS_DRY_RUN=true; shift ;;
        --verbose)  CS_VERBOSE=true; shift ;;
        --help|-h)  show_help ;;
        *)          msg_error "Opção desconhecida: $1"; show_help ;;
    esac
done

# ── Constantes ───────────────────────────────────────────────────────────────
readonly APP_NAME="meuapp"
readonly APP_VERSION="1.0"

# ── Verificações ─────────────────────────────────────────────────────────────
preflight() {
    msg_header "Verificações"
    check_root

    msg_step "Verificando dependências..."
    local deps=(curl)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            cs_run apt-get update -qq
            cs_run apt-get install -y "$dep"
        fi
    done
}

# ── Instalação ───────────────────────────────────────────────────────────────
install() {
    msg_header "Instalando ${APP_NAME}"

    msg_step "Atualizando pacotes..."
    cs_run apt-get update -qq

    msg_step "Instalando ${APP_NAME}..."
    cs_run apt-get install -y "${APP_NAME}"

    # Configuração
    msg_step "Configurando..."
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_dry_run "Criaria /etc/${APP_NAME}/config"
    else
        mkdir -p "/etc/${APP_NAME}"
        cat > "/etc/${APP_NAME}/config" << EOF
# Configuração padrão do ${APP_NAME}
enabled=true
EOF
    fi
}

# ── Pós-instalação ──────────────────────────────────────────────────────────
post_install() {
    msg_header "Finalizando"

    cs_run systemctl enable "${APP_NAME}" 2>/dev/null || true
    cs_run systemctl start "${APP_NAME}" 2>/dev/null || true

    if [[ "${CS_DRY_RUN}" != "true" ]]; then
        if systemctl is-active --quiet "${APP_NAME}" 2>/dev/null; then
            msg_info "${APP_NAME} está rodando! ✔"
        fi
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    [[ "${CS_DRY_RUN}" == "true" ]] && msg_header "🔍 DRY-RUN: ${APP_NAME}"

    preflight
    install
    post_install

    echo ""
    if [[ "${CS_DRY_RUN}" == "true" ]]; then
        msg_info "Simulação concluída. Nenhuma alteração foi feita."
    else
        msg_info "${APP_NAME} instalado com sucesso! 🎉"
    fi
}

main
```

---

## ✅ Checklist para IA

Antes de entregar o script, verifique:

- [ ] Cabeçalho com TODOS os campos de metadados obrigatórios
- [ ] `#!/usr/bin/env bash` como shebang
- [ ] `set -euo pipefail` logo após o cabeçalho
- [ ] Carrega `lib/common.sh` com fallback inline
- [ ] Suporta `--dry-run` (todos os comandos de sistema via `cs_run`)
- [ ] Suporta `--verbose` e `--help`
- [ ] Funções organizadas: `preflight`, `install`, `post_install`, `main`
- [ ] Mensagens em português brasileiro
- [ ] Nome do arquivo: `nome-descritivo.sh` (minúsculas, hifens)
- [ ] Idempotente (pode rodar múltiplas vezes sem quebrar)
- [ ] Verifica dependências antes de usar
- [ ] Trata erros com mensagens claras

---

## 🧪 Como Testar

O projeto inclui testes via Docker. O script pode ser testado assim:

```bash
# Dry-run (sem instalar nada)
sudo bash meu-script.sh --dry-run

# Testar em container Docker
cd tests/
bash run-tests.sh --script ../docker/meu-script.sh --distro ubuntu

# Validar sintaxe com ShellCheck
shellcheck meu-script.sh
```

---

## 🚫 O que NÃO Fazer

1. **NÃO** edite `setup.sh` para adicionar seu script
2. **NÃO** duplique funções de `lib/common.sh` (use `source`)
3. **NÃO** use `#!/bin/bash` (use `#!/usr/bin/env bash`)
4. **NÃO** use comandos sem `cs_run` se alteram o sistema
5. **NÃO** assuma distribuição (verifique com `detect_distro`)
6. **NÃO** use `echo` para mensagens de status (use `msg_info`, `msg_step`, etc.)
7. **NÃO** deixe senhas ou tokens hardcoded
8. **NÃO** ignore erros silenciosamente

---

## 💡 Prompt Sugerido para IA

Se precisar pedir para uma IA criar um script, use este prompt:

> Crie um script bash para o projeto Custom Scripts que instale o [NOME DA FERRAMENTA].
> Siga o formato do arquivo `docs/AI-PROMPT.md` do projeto.
> O script deve:
> - Ter o cabeçalho completo de metadados
> - Carregar lib/common.sh com fallback
> - Suportar --dry-run, --verbose e --help
> - Ser idempotente
> - Ter mensagens em português
> - Ir na pasta [CATEGORIA]/
> - Ser compatível com [ALL/VM/LXC]
