# 🤝 Guia de Contribuição

Obrigado por considerar contribuir com o Custom Scripts! Este documento fornece diretrizes para contribuir com o projeto.

## 📋 Índice

- [Código de Conduta](#código-de-conduta)
- [Como Posso Contribuir?](#como-posso-contribuir)
- [Diretrizes de Scripts](#diretrizes-de-scripts)
- [Padrões de Código](#padrões-de-código)
- [Processo de Submissão](#processo-de-submissão)
- [Documentação](#documentação)

## 📜 Código de Conduta

Este projeto segue um código de conduta simples:

- Seja respeitoso e inclusivo
- Aceite críticas construtivas
- Foque no que é melhor para a comunidade
- Mostre empatia com outros membros da comunidade

## 🎯 Como Posso Contribuir?

### Reportar Bugs

Antes de criar um report de bug, verifique se o problema já foi reportado. Se encontrar um issue existente, adicione um comentário em vez de abrir um novo.

**Ao reportar um bug, inclua:**

- Descrição clara e concisa do problema
- Passos para reproduzir o comportamento
- Comportamento esperado vs. atual
- Screenshots, se aplicável
- Informações do sistema (distribuição, versão, etc.)
- Logs de erro relevantes

### Sugerir Melhorias

Sugestões de novos scripts ou melhorias são sempre bem-vindas! Abra um issue com:

- Descrição clara da funcionalidade proposta
- Casos de uso
- Exemplos de como seria usado
- Se possível, referências a implementações similares

### Contribuir com Scripts

1. **Fork o Repositório**
2. **Clone seu Fork**
   ```bash
   git clone https://github.com/seu-usuario/custom_scripts.git
   cd custom_scripts
   ```

3. **Crie uma Branch**
   ```bash
   git checkout -b feature/meu-novo-script
   ```

4. **Desenvolva seu Script**
   - Siga os [padrões de código](#padrões-de-código)
   - Adicione documentação adequada
   - Teste em múltiplos ambientes

5. **Commit suas Mudanças**
   ```bash
   git add .
   git commit -m "Adiciona script para [descrição]"
   ```

6. **Push para o GitHub**
   ```bash
   git push origin feature/meu-novo-script
   ```

7. **Abra um Pull Request**

## 📝 Diretrizes de Scripts

### Estrutura Básica de um Script

Todo script deve seguir esta estrutura básica:

```bash
#!/bin/bash

#############################################################
# Nome do Script: nome-do-script.sh
# Descrição: Breve descrição do que o script faz
# Autor: Seu Nome
# Data: DD/MM/YYYY
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
readonly NC='\033[0m' # No Color

# Funções auxiliares
msg_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

msg_error() {
    echo -e "${RED}[ERRO]${NC} $1" >&2
}

msg_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Verificação de privilégios (se necessário)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "Este script precisa ser executado como root"
        exit 1
    fi
}

# Função principal
main() {
    msg_info "Iniciando script..."
    
    # Seu código aqui
    
    msg_info "Script concluído com sucesso!"
}

# Executar script
main "$@"
```

### Requisitos Obrigatórios

1. **Shebang**: Todo script deve começar com `#!/bin/bash`

2. **Cabeçalho**: Incluir informações sobre o script (nome, descrição, autor, data, versão)

3. **Segurança**:
   - Use `set -e` para sair em caso de erro
   - Use `set -u` para tratar variáveis não definidas como erro
   - Use `set -o pipefail` para falhar em pipes
   - Valide entradas do usuário
   - Nunca execute comandos com privilégios desnecessários

4. **Validações**:
   - Verificar se comandos necessários estão instalados
   - Verificar se o usuário tem permissões adequadas
   - Verificar se arquivos/diretórios necessários existem

5. **Feedback**:
   - Fornecer mensagens claras sobre o progresso
   - Usar cores para melhorar legibilidade (mas permitir desabilitar)
   - Informar erros de forma clara

6. **Documentação**:
   - Comentários explicando lógica complexa
   - Função `--help` ou `-h` para mostrar uso
   - README na categoria do script

### Boas Práticas

1. **Nomeação**:
   - Use nomes descritivos em minúsculas
   - Use hífens para separar palavras: `backup-mysql.sh`
   - Extensão `.sh` para scripts shell

2. **Variáveis**:
   - Use `readonly` para constantes
   - Use letras maiúsculas para variáveis de ambiente
   - Use letras minúsculas para variáveis locais
   - Use `local` para variáveis dentro de funções

3. **Funções**:
   - Uma função deve fazer uma coisa
   - Use nomes descritivos de verbos: `install_package()`, `check_dependencies()`
   - Documente parâmetros e valores de retorno

4. **Portabilidade**:
   - Prefira comandos POSIX quando possível
   - Documente dependências específicas de distribuição
   - Teste em múltiplas distribuições (Debian, Ubuntu, CentOS, etc.)

5. **Idempotência**:
   - Scripts devem poder ser executados múltiplas vezes com segurança
   - Verificar estado antes de fazer mudanças

6. **Logging**:
   - Registrar ações importantes
   - Incluir timestamps quando relevante
   - Permitir níveis de verbosidade

### Exemplo de Validações

```bash
# Verificar se está executando no sistema correto
check_system() {
    if [[ ! -f /etc/debian_version ]]; then
        msg_error "Este script é apenas para sistemas Debian/Ubuntu"
        exit 1
    fi
}

# Verificar dependências
check_dependencies() {
    local deps=("curl" "wget" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            msg_error "Dependência não encontrada: $dep"
            exit 1
        fi
    done
}

# Verificar conectividade
check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        msg_error "Sem conexão com a internet"
        exit 1
    fi
}
```

## 💻 Padrões de Código

### ShellCheck

Todos os scripts devem passar no [ShellCheck](https://www.shellcheck.net/) sem warnings:

```bash
shellcheck script.sh
```

### Formatação

- Indentação: 4 espaços (não tabs)
- Linhas: máximo 100 caracteres
- Comentários: espaço após `#`
- Aspas: usar aspas duplas para variáveis: `"$var"`

### Exemplo de Código Bem Formatado

```bash
#!/bin/bash

# Função para instalar pacotes
install_packages() {
    local packages=("$@")
    
    msg_info "Instalando pacotes: ${packages[*]}"
    
    if apt-get update && apt-get install -y "${packages[@]}"; then
        msg_info "Pacotes instalados com sucesso"
        return 0
    else
        msg_error "Falha ao instalar pacotes"
        return 1
    fi
}
```

## 📤 Processo de Submissão

### Pull Request

1. **Título**: Use um título descritivo
   - ✅ "Adiciona script de backup MySQL"
   - ❌ "Novo script"

2. **Descrição**: Inclua:
   - O que o script faz
   - Por que é útil
   - Testado em quais distribuições
   - Screenshots ou output de exemplo

3. **Checklist**:
   - [ ] Script passa no ShellCheck
   - [ ] Script foi testado em ambiente real
   - [ ] Documentação foi adicionada
   - [ ] README da categoria foi atualizado
   - [ ] Segue os padrões de código
   - [ ] Inclui tratamento de erros
   - [ ] Inclui validações necessárias

### Revisão de Código

Todos os PRs passarão por revisão. Esteja preparado para:

- Responder perguntas sobre implementação
- Fazer ajustes conforme feedback
- Testar em ambientes adicionais se solicitado

## 📚 Documentação

### README da Categoria

Ao adicionar um script, atualize o README da categoria:

```markdown
## nome-do-script.sh

**Descrição**: Breve descrição do script

**Uso**:
```bash
bash nome-do-script.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-v, --verbose`: Modo verbose

**Requisitos**:
- Sistema: Debian/Ubuntu
- Privilégios: root
- Dependências: curl, jq

**Exemplo**:
```bash
sudo bash nome-do-script.sh --verbose
```
```

### Comentários no Código

- Explique o "porquê", não o "o quê"
- Documente comportamentos não óbvios
- Referencie issues ou fontes quando relevante

```bash
# Usar --no-install-recommends para economizar espaço em containers
apt-get install --no-install-recommends -y nginx
```

## 🧪 Testando Scripts

### Teste Local

1. **Máquina Virtual**: Use VMs para testes destrutivos
2. **Containers**: Docker ou LXC para testes rápidos
3. **Múltiplas Distros**: Teste em Debian, Ubuntu, CentOS

### Teste Automatizado

Se possível, inclua testes:

```bash
#!/bin/bash
# tests/test-script.sh

test_installation() {
    if command -v programa &> /dev/null; then
        echo "✓ Programa instalado"
        return 0
    else
        echo "✗ Programa não encontrado"
        return 1
    fi
}
```

## 🎨 Categorias de Scripts

Organize seu script na categoria apropriada:

- **system-admin**: Administração de sistemas
- **maintenance**: Manutenção e limpeza
- **backup**: Backup e recuperação
- **monitoring**: Monitoramento
- **docker**: Docker e containers
- **network**: Redes
- **security**: Segurança
- **automation**: Automação

Se nenhuma categoria se encaixa, sugira uma nova!

## 🆘 Precisa de Ajuda?

- 📖 Leia a [documentação](./docs/)
- 💬 Abra uma [discussão](https://github.com/gutierrezx7/custom_scripts/discussions)
- 📧 Entre em contato via issues

## 📄 Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a GPL-3.0.

---

**Obrigado por contribuir! 🎉**
