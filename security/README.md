# 🔒 Security Scripts

Scripts relacionados à segurança do sistema Linux.

## 📋 Scripts Disponíveis

### wazuh-agent-install.sh

**Descrição**: Script de deployment automatizado do Wazuh Agent 4.14.1 para Proxmox VE com validações completas e tratamento de erros

**Uso**:
```bash
sudo bash wazuh-agent-install.sh
```

**Variáveis de Ambiente**:
- `WAZUH_MANAGER`: Endereço do servidor Wazuh Manager (padrão: soc.expertlevel.lan)
- `WAZUH_MANAGER_PORT`: Porta do Wazuh Manager (padrão: 1514)

**Requisitos**:
- Sistema: Debian 11/12, Ubuntu 20.04/22.04 (Proxmox 7/8/9)
- Privilégios: root
- Conexão com internet para download de pacotes

**Características**:
- Validação de pré-requisitos do sistema
- Instalação automática do repositório e GPG keys
- Configuração automática do agente
- Backup de configurações anteriores
- Logging detalhado de todas as operações
- Validação pós-instalação

**Exemplo**:
```bash
# Instalação padrão
sudo bash wazuh-agent-install.sh

# Com servidor customizado
WAZUH_MANAGER=seu-servidor.com sudo bash wazuh-agent-install.sh
```

---

### system-hardening.sh

**Descrição**: Hardening automático de sistema Linux seguindo best practices

**Uso**:
```bash
sudo bash system-hardening.sh [perfil] [opções]
```

**Perfis**:
- `basic`: Hardening básico
- `advanced`: Hardening avançado
- `server`: Otimizado para servidores
- `paranoid`: Máxima segurança

**Opções**:
- `-h, --help`: Mostra ajuda
- `-d, --dry-run`: Mostrar mudanças sem aplicar
- `-b, --backup`: Fazer backup das configurações

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root

**Exemplo**:
```bash
sudo bash system-hardening.sh server --backup
sudo bash system-hardening.sh advanced --dry-run
```

---

### security-audit.sh

**Descrição**: Auditoria de segurança completa do sistema

**Uso**:
```bash
sudo bash security-audit.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-o, --output`: Arquivo de saída do relatório
- `-f, --format`: Formato (text, html, json)
- `-v, --verbose`: Modo verbose

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root
- Dependências: lynis (opcional)

**Exemplo**:
```bash
sudo bash security-audit.sh --output audit-report.html --format html
```

---

### ssh-hardening.sh

**Descrição**: Configuração segura do servidor SSH

**Uso**:
```bash
sudo bash ssh-hardening.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-p, --port`: Mudar porta SSH
- `-k, --key-only`: Desabilitar autenticação por senha
- `-2fa, --two-factor`: Habilitar 2FA

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root
- Dependências: openssh-server

**Exemplo**:
```bash
sudo bash ssh-hardening.sh --port 2222 --key-only
sudo bash ssh-hardening.sh --two-factor
```

---

### ssl-cert-manager.sh

**Descrição**: Gerenciamento de certificados SSL/TLS (Let's Encrypt)

**Uso**:
```bash
sudo bash ssl-cert-manager.sh [ação] [domínio]
```

**Ações**:
- `create`: Criar novo certificado
- `renew`: Renovar certificado
- `list`: Listar certificados
- `delete`: Remover certificado

**Opções**:
- `-h, --help`: Mostra ajuda
- `-e, --email`: Email para notificações
- `-w, --webroot`: Webroot path

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root
- Dependências: certbot

**Exemplo**:
```bash
sudo bash ssl-cert-manager.sh create example.com --email admin@example.com
sudo bash ssl-cert-manager.sh renew example.com
```

---

### malware-scan.sh

**Descrição**: Scanner de malware e rootkits no sistema

**Uso**:
```bash
sudo bash malware-scan.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-p, --path`: Caminho específico para scan
- `-q, --quarantine`: Quarentena de arquivos suspeitos

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root
- Dependências: clamav, rkhunter, chkrootkit

**Exemplo**:
```bash
sudo bash malware-scan.sh --path /var/www
sudo bash malware-scan.sh --quarantine
```

---

### password-audit.sh

**Descrição**: Auditoria de senhas fracas no sistema

**Uso**:
```bash
sudo bash password-audit.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-s, --strict`: Modo strict
- `-o, --output`: Arquivo de saída

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root
- Dependências: john, hashcat (opcional)

**Exemplo**:
```bash
sudo bash password-audit.sh --strict --output weak-passwords.txt
```

## 🎯 Categorias

Scripts nesta pasta cobrem:

- 🛡️ Hardening de sistema
- 🔍 Auditoria de segurança
- 🔐 Configuração SSH segura
- 🔒 Gerenciamento de certificados SSL
- 🦠 Scanner de malware e rootkits
- 👤 Auditoria de senhas
- 🚨 Detecção de intrusão
- 📋 Compliance (CIS, STIG)
- 🔑 Gerenciamento de chaves
- 🛑 Fail2ban e rate limiting

## 📦 Instalação Rápida

Para usar todos os scripts desta categoria:

```bash
cd ~/custom_scripts/security
chmod +x *.sh
```

## 🔧 Ferramentas de Segurança

Instale ferramentas essenciais:

```bash
# Debian/Ubuntu
sudo apt-get install -y ufw fail2ban aide rkhunter chkrootkit \
                        clamav clamav-daemon lynis apparmor \
                        auditd certbot

# CentOS/RHEL
sudo yum install -y firewalld fail2ban aide rkhunter \
                    clamav clamd lynis selinux-policy \
                    audit certbot
```

## 🛡️ Hardening Checklist

### Básico
- ✅ Desabilitar root login por SSH
- ✅ Usar autenticação por chave SSH
- ✅ Configurar firewall
- ✅ Manter sistema atualizado
- ✅ Desabilitar serviços desnecessários
- ✅ Configurar fail2ban

### Avançado
- ✅ Implementar SELinux/AppArmor
- ✅ Configurar auditd
- ✅ Criptografia de disco
- ✅ Configurar 2FA
- ✅ Monitoramento de integridade (AIDE)
- ✅ Isolamento de processos

### Servidor Web
- ✅ SSL/TLS certificates
- ✅ Security headers
- ✅ Rate limiting
- ✅ WAF (Web Application Firewall)
- ✅ DDoS protection

## 📊 Monitoramento

### Logs de Segurança

```bash
# Auth logs
sudo tail -f /var/log/auth.log

# Fail2ban
sudo tail -f /var/log/fail2ban.log

# Audit logs
sudo tail -f /var/log/audit/audit.log
```

### Alertas

Configure alertas para:
- Tentativas de login falhadas
- Mudanças em arquivos críticos
- Processos suspeitos
- Portas abertas não autorizadas

## 🕐 Automação

Para segurança contínua com cron:

```bash
# Auditoria de segurança semanal
0 3 * * 0 /path/to/security-audit.sh --output /var/log/security/audit-$(date +\%Y\%m\%d).html

# Scan de malware diário
0 2 * * * /path/to/malware-scan.sh

# Atualização de definições de vírus
0 1 * * * freshclam

# Verificação de integridade
0 4 * * * aide --check
```

## 🚨 Resposta a Incidentes

### Em Caso de Comprometimento

1. **Isolar o sistema**
   ```bash
   sudo iptables -P INPUT DROP
   sudo iptables -P OUTPUT DROP
   ```

2. **Analisar logs**
   ```bash
   sudo bash security-audit.sh --verbose
   ```

3. **Verificar processos suspeitos**
   ```bash
   ps aux | grep -v "\[" | sort -k3 -r | head -20
   ```

4. **Scan de malware**
   ```bash
   sudo bash malware-scan.sh --quarantine
   ```

## 🔐 Compliance

Scripts seguem padrões de:

- **CIS Benchmarks**: Center for Internet Security
- **STIG**: Security Technical Implementation Guides
- **PCI DSS**: Payment Card Industry Data Security Standard
- **HIPAA**: Health Insurance Portability and Accountability Act

## 🤝 Contribuindo

Tem um script de segurança útil? Contribua seguindo nosso [guia de contribuição](../CONTRIBUTING.md)!

## 📚 Recursos Adicionais

- [Linux Security](https://www.kernel.org/doc/html/latest/admin-guide/security.html)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Lynis Documentation](https://cisofy.com/lynis/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
