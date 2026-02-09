# 🤝 Guia de Contribuição

Obrigado por considerar contribuir com o Custom Scripts! Este documento explica como criar
scripts compatíveis com o sistema de auto-discovery.

## 📋 Índice

- [Fluxo Rápido](#-fluxo-rápido-3-passos)
- [Como Funciona o Auto-Discovery](#-como-funciona-o-auto-discovery)
- [Formato de Metadados](#-formato-de-metadados-obrigatório)
- [Estrutura do Script](#-estrutura-do-script)
- [Usando a Biblioteca Compartilhada](#-usando-a-biblioteca-compartilhada)
- [Dry-Run Obrigatório](#-dry-run-obrigatório)
- [Testando](#-testando)
- [Padrões de Código](#-padrões-de-código)
- [Processo de Submissão](#-processo-de-submissão)
- [Usando IA para Criar Scripts](#-usando-ia-para-criar-scripts)

## ⚡ Fluxo Rápido (3 passos)

```bash
# 1. Copiar template
cp templates/script-template.sh docker/meu-script.sh

# 2. Editar (preencher metadados + lógica)
nano docker/meu-script.sh

# 3. Testar
bash tests/run-tests.sh --script docker/meu-script.sh
```

**Pronto.** O menu principal detecta o script automaticamente. Não precisa editar `setup.sh`.

## 🔍 Como Funciona o Auto-Discovery

O sistema em `lib/registry.sh`:

1. Escaneia **todas** as pastas de primeiro nível do projeto
2. Ignora: `lib/`, `templates/`, `docs/`, `tests/`, `.git/`
3. Para cada arquivo `.sh`, lê as **primeiras 30 linhas** buscando metadados
4. Scripts com `# Title:` válido são registrados no menu
5. Scripts sem `Title` são **ignorados silenciosamente**

> 💡 Isso significa: coloque o `.sh` na pasta certa com o cabeçalho correto = aparece no menu.

## 📝 Formato de Metadados (Obrigatório)

Todo script deve ter este cabeçalho nas **primeiras 30 linhas**:

```bash
#!/usr/bin/env bash
# Title:       Nome Amigável em Português
# Description: Descrição curta de uma linha
# Supported:   ALL
# Interactive:  no
# Reboot:      no
# Network:     safe
# DryRun:      yes
# Version:     1.0
# Tags:        docker, container
# Author:      Seu Nome
```

### Campos

| Campo | Obrigatório | Valores | Significado |
|-------|:-----------:|---------|-------------|
| `Title` | ✅ | Texto | Nome exibido no menu interativo |
| `Description` | ✅ | Texto | Descrição de 1 linha |
| `Supported` | ✅ | `ALL`, `VM`, `LXC`, `VM, LXC` | Ambientes compatíveis |
| `Interactive` | ✅ | `yes` / `no` | Precisa de input do usuário? |
| `Reboot` | ✅ | `yes` / `no` | Requer reinicialização? |
| `Network` | ✅ | `safe` / `risk` | Altera configuração de rede? |
| `DryRun` | ✅ | `yes` / `no` | Suporta `--dry-run` nativo? |
| `Version` | Recomendado | `X.Y` | Versão do script |
| `Tags` | Opcional | CSV | Tags para busca futura |
| `Author` | Opcional | Texto | Autor do script |

## 🏗️ Estrutura do Script

Organize em funções com responsabilidade única:

```bash
#!/usr/bin/env bash
# [metadados aqui]

set -euo pipefail

# Carregar lib/common.sh (com fallback)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_FILE="${SCRIPT_DIR}/../lib/common.sh"
if [[ -f "$LIB_FILE" ]]; then
    source "$LIB_FILE"
else
    # fallback mínimo (ver template completo)
fi

# Parse de argumentos (--dry-run, --verbose, --help)

# Constantes
readonly APP_NAME="meuapp"

preflight() {
    # Verificar root, dependências, compatibilidade
}

install() {
    # Lógica principal (TODOS os comandos via cs_run)
}

post_install() {
    # Habilitar serviços, verificar status
}

cleanup() {
    # Limpar arquivos temporários
}

main() {
    preflight
    install
    post_install
    cleanup
    msg_info "Concluído! 🎉"
}

main
```

## 📚 Usando a Biblioteca Compartilhada

O arquivo `lib/common.sh` fornece funções prontas. **Não redeclare cores ou msg_info!**

### Funções Disponíveis

| Função | Uso |
|--------|-----|
| `msg_info "texto"` | Mensagem informativa (verde) |
| `msg_warn "texto"` | Aviso (amarelo) |
| `msg_error "texto"` | Erro (vermelho, vai para stderr) |
| `msg_header "texto"` | Cabeçalho de seção (azul, bold) |
| `msg_step "texto"` | Sub-passo (com seta) |
| `msg_success "texto"` | Sucesso com checkmark |
| `msg_dry_run "texto"` | Mensagem de dry-run (magenta) |
| `cs_run <comando>` | **Wrapper de execução** — respeita `--dry-run` |
| `check_root` | Verifica se é root, sai se não for |
| `check_internet` | Verifica conectividade |
| `check_command "cmd"` | Verifica se um comando existe |
| `check_dependencies curl wget jq` | Verifica e instala dependências |
| `cs_apt_install pkg1 pkg2` | apt-get update + install via `cs_run` |
| `detect_env` | Define `$CS_ENV_TYPE` (VM, LXC, Bare-Metal) |
| `detect_distro` | Define `$CS_DISTRO`, `$CS_DISTRO_VERSION` |
| `confirm "Mensagem?" "y"` | Pede confirmação ao usuário |
| `spinner $PID "msg"` | Spinner animado para processos longos |

### Fallback para Execução Standalone

Scripts devem funcionar mesmo sem `lib/common.sh` (ex: download direto). O template inclui
um bloco de fallback mínimo que garante funcionamento standalone.

## 🧪 Dry-Run Obrigatório

**Todos os novos scripts DEVEM suportar `--dry-run`.**

### Regra principal: use `cs_run` em tudo que altera o sistema

```bash
# ✅ CORRETO
cs_run apt-get install -y nginx
cs_run systemctl enable nginx
cs_run mkdir -p /etc/app

# ❌ ERRADO
apt-get install -y nginx
systemctl enable nginx
```

### Para criação de arquivos:

```bash
if [[ "${CS_DRY_RUN}" == "true" ]]; then
    msg_dry_run "Criaria /etc/app/config.yaml"
else
    cat > /etc/app/config.yaml << 'EOF'
    setting: value
EOF
fi
```

## 🧪 Testando

### Antes de submeter, rode:

```bash
# 1. Validar metadados
bash tests/run-tests.sh --metadata

# 2. Lint (ShellCheck)
bash tests/run-tests.sh --lint

# 3. Dry-run local
sudo bash seu-script.sh --dry-run

# 4. (Opcional) Dry-run em Docker
bash tests/run-tests.sh --dry-run-only --script seu-script.sh
```

## 💻 Padrões de Código

### ShellCheck
Todos os scripts devem passar no [ShellCheck](https://www.shellcheck.net/) sem warnings:
```bash
shellcheck seu-script.sh
```

### Formatação
- **Shebang**: `#!/usr/bin/env bash` (nunca `#!/bin/bash`)
- **Indentação**: 4 espaços (não tabs)
- **Linhas**: máximo 100 caracteres
- **Nomes de arquivo**: `nome-descritivo.sh` (minúsculas, hifens)
- **Variáveis**: aspas duplas: `"$var"` (sempre)
- **Funções**: verbos descritivos: `install_package()`, `check_dependencies()`

### Boas Práticas
- **Idempotência**: pode rodar múltiplas vezes sem quebrar
- **Mensagens em pt-BR**: para consistência com o projeto
- **Sem senhas hardcoded**: nunca
- **Sem `echo` para status**: use `msg_info`, `msg_step`, etc.

## 📤 Processo de Submissão

1. Fork o repositório
2. Crie uma branch: `git checkout -b feature/meu-script`
3. Crie o script seguindo este guia
4. Rode os testes: `bash tests/run-tests.sh --script seu-script.sh`
5. Commit: `git commit -m "Adiciona script para [descrição]"`
6. Push + Pull Request

### Checklist do PR
- [ ] Cabeçalho de metadados completo
- [ ] Suporta `--dry-run`
- [ ] Passa no ShellCheck
- [ ] Testado (local ou Docker)
- [ ] Mensagens em português
- [ ] Idempotente
- [ ] Usa `lib/common.sh` (com fallback)

## 🤖 Usando IA para Criar Scripts

Consulte [`docs/AI-PROMPT.md`](docs/AI-PROMPT.md) para instruções detalhadas que qualquer IA
(ChatGPT, Copilot, Claude) pode seguir para gerar scripts 100% compatíveis.

**Prompt rápido:**
> Crie um script bash para o projeto Custom Scripts que instale [FERRAMENTA].
> Siga o formato do arquivo docs/AI-PROMPT.md do projeto.

## 📁 Categorias

| Pasta | Tipo |
|-------|------|
| `system-admin/` | Administração de sistemas |
| `docker/` | Docker e containers |
| `network/` | Redes e VPN |
| `security/` | Segurança |
| `monitoring/` | Monitoramento |
| `maintenance/` | Manutenção e limpeza |
| `backup/` | Backup e recuperação |
| `automation/` | Automação e CI/CD |

Crie novas pastas se necessário — o auto-discovery escaneia todas automaticamente.

---

## 📜 Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a GPL-3.0.

**Obrigado por contribuir! 🎉**
