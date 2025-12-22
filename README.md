# 🐧 Custom Scripts - Scripts Linux Sortidos

<div align="center">

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/gutierrezx7/custom_scripts/blob/main/CONTRIBUTING.md)
[![GitHub Stars](https://img.shields.io/github/stars/gutierrezx7/custom_scripts?style=social)](https://github.com/gutierrezx7/custom_scripts/stargazers)

</div>

Uma coleção de scripts Linux úteis e sortidos para automatizar tarefas comuns, administração de sistemas, manutenção e muito mais. Inspirado no projeto Proxmox Helper Scripts, este repositório visa fornecer scripts bem documentados e fáceis de usar para a comunidade.

## 📋 Índice

- [Sobre o Projeto](#-sobre-o-projeto)
- [Categorias de Scripts](#-categorias-de-scripts)
- [Como Usar](#-como-usar)
- [Instalação Rápida](#-instalação-rápida)
- [Estrutura do Repositório](#-estrutura-do-repositório)
- [Contribuindo](#-contribuindo)
- [Segurança](#-segurança)
- [Licença](#-licença)

## 🎯 Sobre o Projeto

Este repositório contém uma coleção curada de scripts shell para Linux que ajudam a:

- ⚡ **Automatizar tarefas repetitivas** - Economize tempo com automação
- 🔧 **Administrar sistemas** - Ferramentas para gerenciamento de servidores
- 🛠️ **Manutenção** - Scripts para backup, limpeza e otimização
- 📊 **Monitoramento** - Ferramentas para monitorar recursos do sistema
- 🐳 **DevOps** - Scripts para Docker, containers e CI/CD
- 🌐 **Redes** - Utilitários para configuração e diagnóstico de rede

## 📂 Categorias de Scripts

### 🔧 [System Administration](./system-admin/)
Scripts para administração e configuração de sistemas Linux.
- Gerenciamento de usuários e permissões
- Configuração de serviços
- Atualizações automáticas do sistema

### 🛠️ [Maintenance](./maintenance/)
Scripts para manutenção e otimização do sistema.
- Limpeza de arquivos temporários
- Gerenciamento de logs
- Análise de espaço em disco

### 💾 [Backup & Recovery](./backup/)
Soluções para backup e recuperação de dados.
- Scripts de backup automático
- Sincronização de arquivos
- Snapshots e versionamento

### 📊 [Monitoring](./monitoring/)
Ferramentas para monitoramento de recursos e serviços.
- Monitoramento de CPU, RAM e disco
- Alertas de sistema
- Relatórios de performance

### 🐳 [Docker & Containers](./docker/)
Scripts para gerenciamento de containers e Docker.
- Instalação e configuração do Docker
- Instalação de aplicações em containers
- Limpeza de imagens e volumes

### 🌐 [Network](./network/)
Utilitários para redes e conectividade.
- Configuração de firewall
- Diagnóstico de rede
- VPN e túneis SSH

### 🔒 [Security](./security/)
Scripts relacionados à segurança do sistema.
- Hardening de sistema
- Auditoria de segurança
- Gerenciamento de certificados SSL

### 🚀 [Automation](./automation/)
Scripts para automação e deployment.
- CI/CD helpers
- Deployment automático
- Cron jobs e agendamento

## 🚀 Como Usar

### Método 1: Execução Direta (Recomendado)

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/path/to/script.sh)"
```

ou com curl:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/path/to/script.sh)"
```

### Método 2: Download e Execução

```bash
# Baixar o script
wget https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/path/to/script.sh

# Tornar executável
chmod +x script.sh

# Executar
./script.sh
```

### Método 3: Clone do Repositório

```bash
# Clonar o repositório
git clone https://github.com/gutierrezx7/custom_scripts.git

# Navegar até a pasta
cd custom_scripts

# Executar qualquer script
bash system-admin/exemplo-script.sh
```

## 📦 Instalação Rápida

Para clonar e usar todos os scripts:

```bash
git clone https://github.com/gutierrezx7/custom_scripts.git ~/custom_scripts
cd ~/custom_scripts
chmod +x **/*.sh
```

## 📁 Estrutura do Repositório

```
custom_scripts/
├── system-admin/          # Administração de sistemas
│   ├── README.md
│   └── scripts...
├── maintenance/           # Manutenção do sistema
│   ├── README.md
│   └── scripts...
├── backup/               # Backup e recuperação
│   ├── README.md
│   └── scripts...
├── monitoring/           # Monitoramento
│   ├── README.md
│   └── scripts...
├── docker/               # Docker e containers
│   ├── README.md
│   └── scripts...
├── network/              # Redes
│   ├── README.md
│   └── scripts...
├── security/             # Segurança
│   ├── README.md
│   └── scripts...
├── automation/           # Automação
│   ├── README.md
│   └── scripts...
├── templates/            # Templates de scripts
├── docs/                 # Documentação adicional
├── CONTRIBUTING.md       # Guia de contribuição
└── README.md            # Este arquivo
```

## 🤝 Contribuindo

Contribuições são muito bem-vindas! Este é um projeto comunitário e sua ajuda é essencial.

### Como Contribuir

1. Fork este repositório
2. Crie uma branch para sua feature (`git checkout -b feature/NovoScript`)
3. Commit suas mudanças (`git commit -m 'Adiciona novo script de backup'`)
4. Push para a branch (`git push origin feature/NovoScript`)
5. Abra um Pull Request

Leia nosso [Guia de Contribuição](CONTRIBUTING.md) para mais detalhes sobre:
- Padrões de código
- Como testar scripts
- Diretrizes de documentação
- Processo de revisão

## ⚠️ Segurança

### Antes de Executar Qualquer Script:

1. **👀 SEMPRE revise o código** - Nunca execute scripts sem entender o que fazem
2. **🧪 Teste em ambiente seguro** - Use VMs ou containers para testar primeiro
3. **💾 Faça backup** - Sempre faça backup antes de executar scripts em produção
4. **🔒 Verifique permissões** - Execute apenas com as permissões necessárias
5. **📖 Leia a documentação** - Cada script tem instruções específicas

### Reportar Vulnerabilidades

Se encontrar problemas de segurança, por favor reporte via:
- GitHub Issues (para problemas não críticos)
- Email privado para questões sensíveis

## 📜 Licença

Este projeto está licenciado sob a GNU General Public License v3.0 - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🌟 Agradecimentos

- Inspirado pelo excelente trabalho do [Proxmox Helper Scripts](https://github.com/tteck/Proxmox)
- Agradecimentos a todos os [contribuidores](https://github.com/gutierrezx7/custom_scripts/graphs/contributors)
- Comunidade open-source por todo o suporte

## 📞 Suporte

- 🐛 [Reportar Bug](https://github.com/gutierrezx7/custom_scripts/issues/new?labels=bug)
- 💡 [Sugerir Feature](https://github.com/gutierrezx7/custom_scripts/issues/new?labels=enhancement)
- 💬 [Discussões](https://github.com/gutierrezx7/custom_scripts/discussions)

## 📈 Status do Projeto

Este projeto está em **desenvolvimento ativo**. Novos scripts são adicionados regularmente.

---

<div align="center">

**Feito com ❤️ para a comunidade Linux**

⭐ Se este projeto foi útil, considere dar uma estrela!

</div>