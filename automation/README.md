# 🚀 Automation Scripts

Scripts para automação de tarefas, deployment e CI/CD.

## 📋 Scripts Disponíveis

### deploy-app.sh

**Descrição**: Script genérico para deployment de aplicações

**Uso**:
```bash
bash deploy-app.sh [app] [ambiente] [opções]
```

**Ambientes**:
- `dev`: Desenvolvimento
- `staging`: Staging/Homologação
- `prod`: Produção

**Opções**:
- `-h, --help`: Mostra ajuda
- `-b, --branch`: Branch do git
- `-r, --rollback`: Rollback para versão anterior

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: git, rsync

**Exemplo**:
```bash
bash deploy-app.sh myapp prod --branch main
bash deploy-app.sh myapp prod --rollback
```

---

### git-auto-backup.sh

**Descrição**: Backup automático de repositórios Git

**Uso**:
```bash
bash git-auto-backup.sh [repositório] [destino]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-c, --compress`: Comprimir backup
- `-a, --all`: Todos os repositórios em um diretório

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: git

**Exemplo**:
```bash
bash git-auto-backup.sh /home/user/projeto /backup/repos --compress
bash git-auto-backup.sh --all /var/www /backup/www-repos
```

---

### cron-manager.sh

**Descrição**: Gerenciamento simplificado de cron jobs

**Uso**:
```bash
bash cron-manager.sh [ação] [opções]
```

**Ações**:
- `add`: Adicionar cron job
- `remove`: Remover cron job
- `list`: Listar cron jobs
- `edit`: Editar crontab

**Opções**:
- `-h, --help`: Mostra ajuda
- `-u, --user`: Usuário específico

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário (root para outros usuários)
- Dependências: cron

**Exemplo**:
```bash
bash cron-manager.sh add "0 2 * * * /path/to/backup.sh"
bash cron-manager.sh list
```

---

### webhook-handler.sh

**Descrição**: Handler para webhooks (GitHub, GitLab, etc.)

**Uso**:
```bash
bash webhook-handler.sh [porta] [secret]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-c, --command`: Comando a executar ao receber webhook
- `-l, --log`: Arquivo de log

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: nc (netcat) ou socat

**Exemplo**:
```bash
bash webhook-handler.sh 8080 my-secret --command "/path/to/deploy.sh"
```

---

### batch-process.sh

**Descrição**: Processamento em lote de arquivos ou comandos

**Uso**:
```bash
bash batch-process.sh [comando] [arquivos...] [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-p, --parallel`: Número de processos paralelos
- `-l, --log`: Arquivo de log

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: parallel (opcional)

**Exemplo**:
```bash
bash batch-process.sh "convert {} {.}.jpg" *.png --parallel 4
bash batch-process.sh "gzip {}" *.log --log process.log
```

---

### systemd-service-creator.sh

**Descrição**: Criação de serviços systemd de forma interativa

**Uso**:
```bash
sudo bash systemd-service-creator.sh [nome-servico]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-e, --enable`: Habilitar serviço após criar
- `-s, --start`: Iniciar serviço após criar

**Requisitos**:
- Sistema: Linux com systemd
- Privilégios: root
- Dependências: systemd

**Exemplo**:
```bash
sudo bash systemd-service-creator.sh myapp --enable --start
```

## 🎯 Categorias

Scripts nesta pasta cobrem:

- 🚀 Deployment automático
- 📦 Empacotamento de aplicações
- 🔄 CI/CD helpers
- ⏰ Gerenciamento de cron jobs
- 🪝 Webhook handlers
- 📊 Processamento em lote
- 🔧 Criação de serviços systemd
- 🔁 Tarefas agendadas
- 🤖 Automação de DevOps
- 📡 Integração com APIs

## 📦 Instalação Rápida

Para usar todos os scripts desta categoria:

```bash
cd ~/custom_scripts/automation
chmod +x *.sh
```

## 🔄 CI/CD Integration

### GitHub Actions

```yaml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy
        run: |
          bash deploy-app.sh myapp prod --branch main
```

### GitLab CI

```yaml
deploy:
  stage: deploy
  script:
    - bash deploy-app.sh myapp prod --branch main
  only:
    - main
```

### Jenkins

```groovy
pipeline {
    agent any
    stages {
        stage('Deploy') {
            steps {
                sh 'bash deploy-app.sh myapp prod --branch main'
            }
        }
    }
}
```

## 🕐 Exemplos de Cron Jobs

### Backups Automáticos

```bash
# Backup diário de banco de dados às 2h
0 2 * * * /path/to/backup-mysql.sh --all --compress

# Backup de arquivos às 3h
0 3 * * * /path/to/backup-files.sh /var/www /backup/www --incremental
```

### Manutenção

```bash
# Limpeza semanal do sistema
0 4 * * 0 /path/to/clean-system.sh

# Atualização de certificados SSL
0 5 * * 1 /path/to/ssl-cert-manager.sh renew --all
```

### Monitoramento

```bash
# Verificar serviços a cada 5 minutos
*/5 * * * * /path/to/service-check.sh nginx mysql --restart

# Relatório diário de performance
0 6 * * * /path/to/performance-report.sh --output /var/log/daily-report.html
```

### Deploy Automático

```bash
# Deploy automático de staging a cada hora
0 * * * * cd /path/to/repo && git pull && /path/to/deploy-app.sh myapp staging
```

## 🤖 Automação Avançada

### Ansible Integration

```yaml
---
- name: Deploy application
  hosts: webservers
  tasks:
    - name: Run deploy script
      script: /path/to/deploy-app.sh myapp prod --branch main
```

### Terraform Integration

```hcl
resource "null_resource" "deploy" {
  provisioner "local-exec" {
    command = "bash deploy-app.sh myapp prod --branch main"
  }
}
```

## 🔐 Segurança

### Secrets Management

Nunca armazene credenciais em scripts. Use:

1. **Variáveis de ambiente**
   ```bash
   export DB_PASSWORD="secret"
   ```

2. **Arquivos .env**
   ```bash
   source .env
   ```

3. **Vault/Secret managers**
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault

### Validação de Webhooks

```bash
# Verificar assinatura do GitHub
if ! verify_signature "$payload" "$signature"; then
    echo "Invalid signature"
    exit 1
fi
```

## 📊 Logging e Notificações

### Logs Estruturados

```bash
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a "$LOG_FILE" >&2
}
```

### Notificações

Scripts podem enviar notificações via:
- Email
- Slack
- Discord
- Telegram
- PagerDuty

## 🧪 Testes

### Teste de Deploy

```bash
# Dry run
bash deploy-app.sh myapp staging --dry-run

# Deploy para staging primeiro
bash deploy-app.sh myapp staging
# Verificar
# Deploy para produção
bash deploy-app.sh myapp prod
```

### Rollback

```bash
# Fazer rollback em caso de problema
bash deploy-app.sh myapp prod --rollback
```

## 🤝 Contribuindo

Tem um script de automação útil? Contribua seguindo nosso [guia de contribuição](../CONTRIBUTING.md)!

## 📚 Recursos Adicionais

- [Cron Documentation](https://man7.org/linux/man-pages/man5/crontab.5.html)
- [systemd Documentation](https://www.freedesktop.org/software/systemd/man/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [Ansible Documentation](https://docs.ansible.com/)
