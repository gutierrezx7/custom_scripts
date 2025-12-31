# 🐧 Custom Scripts - Scripts Linux Sortidos (2025 Edition)

<div align="center">

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/gutierrezx7/custom_scripts/blob/main/CONTRIBUTING.md)
[![GitHub Stars](https://img.shields.io/github/stars/gutierrezx7/custom_scripts?style=social)](https://github.com/gutierrezx7/custom_scripts/stargazers)

</div>

Uma coleção atualizada de scripts Linux para DevOps, SysAdmins e entusiastas de HomeLab. Este repositório foca em ferramentas modernas e essenciais para 2025.

## 🚀 Instalação Recomendada (Global)

Para garantir a melhor experiência, use o **Menu Interativo**. Ele detecta automaticamente seu ambiente (VM, LXC, Bare Metal), baixa os módulos necessários e evita erros de compatibilidade.

**Basta rodar este comando:**

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/setup.sh)"
```

*O script cuidará de tudo para você.*

---

## 📂 O que está incluído?

O menu principal (`setup.sh`) dá acesso a todas as ferramentas abaixo, organizadas por categoria:

### 🛡️ Segurança
- **Fail2Ban**: Proteção essencial contra força bruta (SSH).
- **Firewall (UFW)**: Configuração rápida e segura de portas.
- **Wazuh Agent**: Monitoramento de segurança avançado.

### 🌐 Redes
- **Tailscale**: VPN Mesh zero-config para acesso remoto seguro.
- **AdGuard Home**: DNS Server com bloqueio de anúncios e rastreadores.
- **IP Estático (Netplan)**: Utilitário para configurar IP fixo em VMs Ubuntu.

### 🐳 Docker & DevOps
- **Docker Engine**: Instalação oficial e atualizada.
- **Nginx Proxy Manager**: O jeito mais fácil de gerenciar Proxy Reverso e SSL.
- **Portainer**: Interface gráfica para gerenciar seus containers.
- **Watchtower**: Mantém seus containers atualizados automaticamente.

### 🔧 Sistema & Utilitários
- **Shell Moderno**: Instala Zsh, Oh-My-Zsh e Fastfetch para um terminal produtivo.
- **System Prep**: Define Hostname, atualiza pacotes e instala ferramentas básicas.
- **Webmin**: Administração de sistema via web.
- **DynFi Manager**: Gerenciamento centralizado de firewalls.

---

## ⚡ Exemplos de Uso Direto (Avançado)

Embora recomendemos fortemente o uso do `setup.sh`, você pode executar scripts individuais se souber o que está fazendo.

| Script | Descrição | Link Direto (Exemplo) |
| :--- | :--- | :--- |
| **Docker** | Instalação do Docker | `bash -c "$(wget -qLO - https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/docker/docker-install.sh)"` |
| **NPM** | Nginx Proxy Manager | `bash -c "$(wget -qLO - https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/docker/npm-install.sh)"` |
| **Tailscale** | Instalar VPN | `bash -c "$(wget -qLO - https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/network/tailscale-install.sh)"` |
| **Zsh** | Shell Moderno | `bash -c "$(wget -qLO - https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/system-admin/modern-shell.sh)"` |

## 📁 Estrutura do Repositório

```
custom_scripts/
├── setup.sh               # 🌟 MENU PRINCIPAL (Execute este!)
├── system-admin/          # Scripts de sistema (Zsh, Prep, Webmin...)
├── docker/                # Scripts Docker (NPM, Watchtower, Portainer...)
├── network/               # Scripts de Rede (Tailscale, AdGuard, IP...)
├── security/              # Scripts de Segurança (Fail2Ban, UFW...)
├── monitoring/            # Ferramentas de Monitoramento
├── maintenance/           # Scripts de Manutenção
├── backup/                # Scripts de Backup
└── README.md              # Documentação
```

## 🤝 Contribuindo

Contribuições são bem-vindas! Se você criar um novo script:
1. Adicione-o na pasta correta.
2. Inclua o cabeçalho de metadados padrão (`# Title`, `# Description`, `# Supported`).
3. O `setup.sh` detectará seu script automaticamente!

## ⚠️ Segurança e Isenção de Responsabilidade

Sempre revise o código antes de executar scripts com privilégios de root. Estes scripts são fornecidos "como estão", sem garantias. Teste em ambiente seguro antes de usar em produção.

## 📜 Licença

GPL v3 - Veja o arquivo [LICENSE](LICENSE) para detalhes.
