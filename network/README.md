# 🌐 Network Scripts

Utilitários para configuração, diagnóstico e gerenciamento de redes.

## 📋 Scripts Disponíveis

### network-diagnostic.sh

**Descrição**: Diagnóstico completo de conectividade e problemas de rede

**Uso**:
```bash
bash network-diagnostic.sh [host] [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-v, --verbose`: Modo verbose
- `-o, --output`: Salvar relatório em arquivo

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: ping, traceroute, dig, netstat

**Exemplo**:
```bash
bash network-diagnostic.sh google.com --verbose
bash network-diagnostic.sh 8.8.8.8 --output report.txt
```

---

### firewall-setup.sh

**Descrição**: Configuração básica de firewall com iptables/ufw

**Uso**:
```bash
sudo bash firewall-setup.sh [perfil] [opções]
```

**Perfis**:
- `basic`: Firewall básico (SSH, HTTP, HTTPS)
- `web`: Servidor web
- `database`: Servidor de banco de dados
- `custom`: Configuração customizada

**Opções**:
- `-h, --help`: Mostra ajuda
- `-p, --port`: Adicionar porta específica
- `-i, --ip`: Permitir IP específico

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root
- Dependências: iptables ou ufw

**Exemplo**:
```bash
sudo bash firewall-setup.sh web
sudo bash firewall-setup.sh custom --port 3000 --port 8080
```

---

### port-scanner.sh

**Descrição**: Scanner de portas abertas e serviços em execução

**Uso**:
```bash
bash port-scanner.sh [host] [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-p, --ports`: Range de portas (ex: 1-1000)
- `-f, --fast`: Scan rápido (portas comuns)

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: nmap (opcional)

**Exemplo**:
```bash
bash port-scanner.sh 192.168.1.1 --ports 1-1000
bash port-scanner.sh localhost --fast
```

---

### vpn-setup.sh

**Descrição**: Configuração de VPN (WireGuard ou OpenVPN)

**Uso**:
```bash
sudo bash vpn-setup.sh [tipo] [opções]
```

**Tipos**:
- `wireguard`: WireGuard VPN
- `openvpn`: OpenVPN

**Opções**:
- `-h, --help`: Mostra ajuda
- `-c, --client`: Gerar configuração de cliente
- `-s, --server`: Configurar servidor

**Requisitos**:
- Sistema: Debian/Ubuntu
- Privilégios: root
- Dependências: wireguard ou openvpn

**Exemplo**:
```bash
sudo bash vpn-setup.sh wireguard --server
sudo bash vpn-setup.sh wireguard --client usuario1
```

---

### bandwidth-monitor.sh

**Descrição**: Monitor de uso de largura de banda por interface

**Uso**:
```bash
bash bandwidth-monitor.sh [interface] [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-i, --interval`: Intervalo de atualização
- `-l, --log`: Salvar em log

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: ifstat, iftop

**Exemplo**:
```bash
bash bandwidth-monitor.sh eth0 --interval 5
bash bandwidth-monitor.sh --log /var/log/bandwidth.log
```

## 🎯 Categorias

Scripts nesta pasta cobrem:

- 🔍 Diagnóstico de rede
- 🔥 Configuração de firewall
- 🔒 VPN (WireGuard, OpenVPN)
- 📡 Monitoramento de largura de banda
- 🌐 Configuração de DNS
- 🚪 Scanner de portas
- 🔐 SSH hardening
- 📊 Análise de tráfego
- 🔗 Túneis SSH

## 📦 Instalação Rápida

Para usar todos os scripts desta categoria:

```bash
cd ~/custom_scripts/network
chmod +x *.sh
```

## 🔧 Ferramentas Necessárias

Instale ferramentas de rede úteis:

```bash
# Debian/Ubuntu
sudo apt-get install -y net-tools iproute2 dnsutils nmap traceroute \
                        iptables ufw wireguard openvpn iftop nethogs

# CentOS/RHEL
sudo yum install -y net-tools iproute dnsutils nmap traceroute \
                    iptables wireguard-tools openvpn iftop nethogs
```

## 🛡️ Segurança

### Firewall

Scripts incluem configurações seguras por padrão:

- Bloqueio de conexões não autorizadas
- Proteção contra port scanning
- Rate limiting para SSH
- Logging de tentativas suspeitas

### VPN

Configurações de VPN incluem:

- Criptografia forte (ChaCha20/AES-256)
- Kill switch (previne vazamento de tráfego)
- DNS seguro
- Configurações otimizadas

## 📊 Monitoramento

### Em Tempo Real

```bash
# Monitor de conexões
watch -n 1 'netstat -tuln'

# Monitor de largura de banda
iftop -i eth0

# Monitor de processos de rede
nethogs eth0
```

### Logs

```bash
# Logs do firewall
sudo tail -f /var/log/ufw.log

# Logs do VPN
sudo tail -f /var/log/openvpn.log
```

## 🕐 Automação

Para monitoramento contínuo com cron:

```bash
# Diagnóstico de rede diário
0 6 * * * /path/to/network-diagnostic.sh google.com --output /var/log/network-check.log

# Verificar largura de banda a cada hora
0 * * * * /path/to/bandwidth-monitor.sh eth0 --log /var/log/bandwidth.log
```

## 🔍 Troubleshooting

### Problemas Comuns

1. **Sem conectividade**:
   ```bash
   bash network-diagnostic.sh 8.8.8.8
   ```

2. **Problemas de DNS**:
   ```bash
   dig google.com
   nslookup google.com
   ```

3. **Portas bloqueadas**:
   ```bash
   bash port-scanner.sh localhost --fast
   ```

4. **Performance de rede**:
   ```bash
   bash bandwidth-monitor.sh eth0
   ```

## 🤝 Contribuindo

Tem um script de rede útil? Contribua seguindo nosso [guia de contribuição](../CONTRIBUTING.md)!

## 📚 Recursos Adicionais

- [Linux Network Administration](https://www.tldp.org/LDP/nag2/index.html)
- [iptables Tutorial](https://www.frozentux.net/iptables-tutorial/iptables-tutorial.html)
- [WireGuard Documentation](https://www.wireguard.com/quickstart/)
- [OpenVPN Documentation](https://openvpn.net/community-resources/)
