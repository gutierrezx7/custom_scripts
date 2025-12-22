# 🐳 Docker & Containers Scripts

Scripts para gerenciamento de Docker e containers.

## 📋 Scripts Disponíveis

### install-docker.sh

**Descrição**: Instalação automatizada do Docker Engine e Docker Compose

**Uso**:
```bash
bash install-docker.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-c, --compose`: Instalar Docker Compose
- `-u, --user`: Adicionar usuário ao grupo docker

**Requisitos**:
- Sistema: Debian/Ubuntu/CentOS/RHEL
- Privilégios: root
- Conexão com internet

**Exemplo**:
```bash
sudo bash install-docker.sh --compose --user $USER
```

---

### docker-cleanup.sh

**Descrição**: Limpeza de containers, imagens, volumes e redes não utilizados

**Uso**:
```bash
bash docker-cleanup.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-a, --all`: Remover tudo não utilizado
- `-c, --containers`: Apenas containers parados
- `-i, --images`: Apenas imagens sem tag
- `-v, --volumes`: Apenas volumes não utilizados
- `-n, --dry-run`: Mostrar o que seria removido

**Requisitos**:
- Sistema: Linux com Docker instalado
- Privilégios: usuário no grupo docker ou root
- Dependências: docker

**Exemplo**:
```bash
bash docker-cleanup.sh --dry-run
bash docker-cleanup.sh --all
```

---

### docker-backup.sh

**Descrição**: Backup de volumes, containers e configurações do Docker

**Uso**:
```bash
bash docker-backup.sh [container/volume] [destino]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-a, --all`: Backup de todos containers
- `-c, --compress`: Comprimir backup

**Requisitos**:
- Sistema: Linux com Docker instalado
- Privilégios: usuário no grupo docker ou root
- Dependências: docker, tar

**Exemplo**:
```bash
bash docker-backup.sh nginx /backup/containers --compress
bash docker-backup.sh --all /backup/docker
```

---

### docker-monitor.sh

**Descrição**: Monitor de recursos usados por containers Docker

**Uso**:
```bash
bash docker-monitor.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-i, --interval`: Intervalo de atualização
- `-c, --container`: Container específico

**Requisitos**:
- Sistema: Linux com Docker instalado
- Privilégios: usuário no grupo docker ou root
- Dependências: docker

**Exemplo**:
```bash
bash docker-monitor.sh --interval 5
bash docker-monitor.sh --container nginx
```

---

### install-portainer.sh

**Descrição**: Instalação do Portainer para gerenciamento web do Docker

**Uso**:
```bash
bash install-portainer.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-p, --port`: Porta para Portainer (padrão: 9000)
- `-s, --ssl`: Habilitar SSL

**Requisitos**:
- Sistema: Linux com Docker instalado
- Privilégios: usuário no grupo docker ou root
- Dependências: docker

**Exemplo**:
```bash
bash install-portainer.sh --port 9000
```

## 🎯 Categorias

Scripts nesta pasta cobrem:

- 🐋 Instalação e configuração do Docker
- 🧹 Limpeza de recursos Docker
- 💾 Backup de containers e volumes
- 📊 Monitoramento de containers
- 🚀 Deploy de aplicações populares
- 🔧 Docker Compose helpers
- 🌐 Instalação de aplicações web
- 🔒 Configuração de segurança

## 📦 Instalação Rápida

Para usar todos os scripts desta categoria:

```bash
cd ~/custom_scripts/docker
chmod +x *.sh
```

## 🚀 Aplicações Disponíveis

Scripts para instalação de aplicações populares em containers:

- **Portainer**: Interface web para Docker
- **Nginx Proxy Manager**: Proxy reverso com interface web
- **Traefik**: Proxy reverso e load balancer
- **Watchtower**: Atualização automática de containers
- **Pi-hole**: DNS e bloqueador de ads
- **Nextcloud**: Armazenamento em nuvem
- **GitLab**: Plataforma DevOps
- **Grafana**: Visualização de dados
- **Uptime Kuma**: Monitor de uptime

## 🔧 Docker Compose

Exemplos de docker-compose.yml para aplicações comuns estão incluídos em `compose-examples/`.

## 🛡️ Segurança

### Boas Práticas

1. Nunca execute containers como root quando não necessário
2. Use imagens oficiais ou verificadas
3. Mantenha Docker atualizado
4. Use secrets para dados sensíveis
5. Limite recursos (CPU, RAM) dos containers
6. Configure network segmentation
7. Use volumes para persistência

### Scanning de Vulnerabilidades

```bash
# Instalar trivy
bash install-trivy.sh

# Scan de imagem
trivy image nginx:latest
```

## 🕐 Automação

Para manutenção automática com cron:

```bash
# Limpeza semanal aos domingos às 3h
0 3 * * 0 /path/to/docker-cleanup.sh --all

# Backup diário às 2h
0 2 * * * /path/to/docker-backup.sh --all /backup/docker --compress
```

## 📊 Monitoramento

Para monitoramento avançado, considere:

- **cAdvisor**: Métricas de containers
- **Prometheus**: Coleta de métricas
- **Grafana**: Visualização
- **Portainer**: Interface web

## 🤝 Contribuindo

Tem um script Docker útil? Contribua seguindo nosso [guia de contribuição](../CONTRIBUTING.md)!

## 📚 Recursos Adicionais

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Awesome Docker](https://github.com/veggiemonk/awesome-docker)
