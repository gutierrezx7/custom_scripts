# 📊 Monitoring Scripts

Ferramentas para monitoramento de recursos e serviços do sistema.

## 📋 Scripts Disponíveis

### system-monitor.sh

**Descrição**: Monitor em tempo real de CPU, RAM, disco e rede

**Uso**:
```bash
bash system-monitor.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-i, --interval`: Intervalo de atualização (segundos)
- `-a, --alert`: Definir limites de alerta
- `-l, --log`: Salvar em arquivo de log

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: top, free, df, ifstat

**Exemplo**:
```bash
bash system-monitor.sh --interval 5 --alert cpu:80,ram:90
```

---

### service-check.sh

**Descrição**: Verifica status de serviços críticos e envia alertas

**Uso**:
```bash
bash service-check.sh [serviços...] [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-e, --email`: Enviar email em caso de falha
- `-r, --restart`: Tentar reiniciar serviço se estiver down

**Requisitos**:
- Sistema: Linux com systemd
- Privilégios: root (para restart)
- Dependências: systemctl, mail (opcional)

**Exemplo**:
```bash
sudo bash service-check.sh nginx mysql redis --restart --email admin@example.com
```

---

### disk-usage-alert.sh

**Descrição**: Alerta quando o uso de disco ultrapassa limite configurado

**Uso**:
```bash
bash disk-usage-alert.sh [limite%] [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-e, --email`: Email para enviar alertas
- `-p, --path`: Caminho específico para monitorar

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: df, mail (opcional)

**Exemplo**:
```bash
bash disk-usage-alert.sh 85 --email admin@example.com --path /var
```

---

### performance-report.sh

**Descrição**: Gera relatório detalhado de performance do sistema

**Uso**:
```bash
bash performance-report.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-o, --output`: Arquivo de saída
- `-f, --format`: Formato (text, html, json)
- `-d, --days`: Dados dos últimos N dias

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: sar, vmstat (sysstat package)

**Exemplo**:
```bash
bash performance-report.sh --output report.html --format html --days 7
```

## 🎯 Categorias

Scripts nesta pasta cobrem:

- 📊 Monitoramento de CPU, RAM e disco
- 🌐 Monitoramento de rede
- 🔍 Verificação de serviços
- 📈 Relatórios de performance
- 🚨 Sistema de alertas
- 📉 Análise de tendências
- 🔔 Notificações (email, Slack, etc.)
- 📝 Logging de métricas

## 📦 Instalação Rápida

Para usar todos os scripts desta categoria:

```bash
cd ~/custom_scripts/monitoring
chmod +x *.sh
```

## 🎨 Dashboards

Os scripts podem ser integrados com ferramentas de visualização:

- **Grafana**: Para dashboards visuais
- **Prometheus**: Para coleta de métricas
- **Nagios**: Para monitoramento corporativo
- **Zabbix**: Para monitoramento empresarial

## 🕐 Automação

Para monitoramento contínuo com cron:

```bash
# Verificar serviços a cada 5 minutos
*/5 * * * * /path/to/service-check.sh nginx mysql --restart --email admin@example.com

# Alerta de disco a cada hora
0 * * * * /path/to/disk-usage-alert.sh 85 --email admin@example.com

# Relatório diário às 6h da manhã
0 6 * * * /path/to/performance-report.sh --output /var/log/daily-report.html --format html
```

## 🚨 Configuração de Alertas

### Email

Configure o sistema de email (postfix, sendmail) ou use serviços externos:

```bash
# Instalar mailutils
sudo apt-get install mailutils

# Configurar SMTP externo
# Editar /etc/ssmtp/ssmtp.conf
```

### Slack

Para integração com Slack:

```bash
# Adicionar webhook URL no script
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

## 🤝 Contribuindo

Tem um script de monitoramento útil? Contribua seguindo nosso [guia de contribuição](../CONTRIBUTING.md)!

## 📚 Recursos Adicionais

- [Linux Performance Monitoring](https://www.brendangregg.com/linuxperf.html)
- [Sysstat Tools](https://github.com/sysstat/sysstat)
- [Prometheus Node Exporter](https://github.com/prometheus/node_exporter)
