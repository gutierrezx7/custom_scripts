# 🐧 Custom Scripts - Scripts Linux Sortidos (2025 Edition)

<div align="center">

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/gutierrezx7/custom_scripts/blob/main/CONTRIBUTING.md)
[![GitHub Stars](https://img.shields.io/github/stars/gutierrezx7/custom_scripts?style=social)](https://github.com/gutierrezx7/custom_scripts/stargazers)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen)](https://www.shellcheck.net/)

**Uma coleção de scripts Linux com auto-discovery, dry-run e menu interativo.**

</div>

---

## ✨ Destaques da v2.0

| Feature | Descrição |
|---------|-----------|
| 🧙 **Wizard Inicial** | Assistente guiado: hostname, IP fixo, timezone e scripts em um fluxo. |
| ↻ **Resume após Reboot** | Reinicia a máquina e continua de onde parou automaticamente. |
| 🔍 **Auto-Discovery** | Novos scripts são detectados automaticamente. Basta colocar na pasta. |
| 🧪 **Dry-Run** | Teste qualquer script com `--dry-run` sem instalar nada. |
| 📚 **Biblioteca Compartilhada** | Funções comuns em `lib/` — sem código duplicado. |
| 🐳 **Testes em Docker** | Rode testes seguros em containers sem afetar o host. |
| 🤖 **Guia para IA** | Instruções para que IAs gerem scripts 100% compatíveis. |
| 🔌 **Plug & Play** | Adicione scripts sem editar `setup.sh` ou qualquer outro arquivo. |

---

## 🚀 Instalação (One-liner)

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/gutierrezx7/custom_scripts/main/setup.sh)"
```

O script detecta seu ambiente (VM, LXC, Bare Metal), baixa tudo e abre o menu interativo.

---

## 📖 Modos de Uso

### 🧙 Wizard — Primeira Configuração (recomendado)
```bash
sudo bash setup.sh --wizard
```
Fluxo guiado em 4 passos:
1. **Hostname** — Renomear a máquina
2. **IP Estático** — Configurar via Netplan (opcional)
3. **Timezone** — Definir fuso horário
4. **Scripts** — Selecionar o que instalar

Se precisar de reboot (ex: mudança de IP), o sistema reinicia e **continua automaticamente**.

### Menu Interativo
```bash
sudo bash setup.sh
```

### ↻ Retomar após reboot
```bash
sudo bash setup.sh --resume
```
> Normalmente não precisa rodar manualmente — o systemd faz isso por você.

### Dry-Run — Testar sem instalar
```bash
sudo bash setup.sh --dry-run
```

### Listar scripts disponíveis
```bash
sudo bash setup.sh --list
```

### Executar script específico
```bash
sudo bash setup.sh --run docker-install
sudo bash setup.sh --dry-run --run tailscale
```

### Script individual (avançado)
```bash
sudo bash docker/docker-install.sh --dry-run
sudo bash network/tailscale-install.sh
```

---

## 📂 Estrutura do Projeto

```
custom_scripts/
├── setup.sh               # 🌟 MENU PRINCIPAL
├── lib/                   # 📚 Biblioteca compartilhada
│   ├── common.sh          #    Funções utilitárias (cores, msg, cs_run)
│   ├── state.sh           #    Persistência de estado + resume
│   ├── registry.sh        #    Auto-discovery de scripts
│   └── runner.sh          #    Motor de execução + dry-run + reboot
├── templates/
│   └── script-template.sh # 📝 Template para novos scripts
├── docs/
│   └── AI-PROMPT.md       # 🤖 Instruções para IAs
├── tests/                 # 🧪 Framework de testes
│   ├── run-tests.sh       #    Test runner
│   ├── Dockerfile.ubuntu  #    Container Ubuntu
│   └── Dockerfile.debian  #    Container Debian
├── system-admin/          # 🔧 Sistema & Utilitários
├── docker/                # 🐳 Docker & DevOps
├── network/               # 🌐 Redes
├── security/              # 🛡️ Segurança
├── monitoring/            # 📊 Monitoramento
├── maintenance/           # 🧹 Manutenção
├── backup/                # 💾 Backup
└── automation/            # ⚙️ Automação
```

---

## 📦 Scripts Incluídos

### 🛡️ Segurança
| Script | Descrição | Ambiente |
|--------|-----------|----------|
| `fail2ban-install.sh` | Proteção contra força bruta (SSH) | ALL |
| `setup-firewall.sh` | Configuração rápida do UFW | ALL |
| `wazuh-agent-install.sh` | Monitoramento de segurança SIEM | VM |

### 🌐 Redes
| Script | Descrição | Ambiente |
|--------|-----------|----------|
| `tailscale-install.sh` | VPN Mesh zero-config | ALL |
| `adguard-install.sh` | DNS Server com bloqueio de ads | ALL |
| `set-static-ip.sh` | Configurar IP fixo (Netplan) | VM |

### 🐳 Docker & DevOps
| Script | Descrição | Ambiente |
|--------|-----------|----------|
| `docker-install.sh` | Docker Engine + Compose | VM, LXC |
| `npm-install.sh` | Nginx Proxy Manager | VM, LXC |
| `watchtower-install.sh` | Atualização automática de containers | ALL |
| `portainer-install.sh` | Interface gráfica para Docker | ALL |

### 🔧 Sistema & Utilitários
| Script | Descrição | Ambiente |
|--------|-----------|----------|
| `modern-shell.sh` | Zsh + Oh-My-Zsh + Fastfetch | ALL |
| `system-prep.sh` | Hostname, pacotes, ferramentas básicas | ALL |
| `webmin-install.sh` | Administração web do sistema | VM |
| `update-system.sh` | Atualização completa do sistema | ALL |

> 💡 Use `bash setup.sh --list` para ver a lista completa e atualizada.

---

## 🔌 Adicionando Novos Scripts (Plug & Play)

### Passo 1: Criar o arquivo

Copie o template:
```bash
cp templates/script-template.sh docker/meu-novo-script.sh
```

### Passo 2: Editar os metadados

As primeiras linhas **devem** conter:
```bash
#!/usr/bin/env bash
# Title:       Meu Novo Script
# Description: Instala algo incrível
# Supported:   ALL
# Interactive:  no
# Reboot:      no
# Network:     safe
# DryRun:      yes
# Version:     1.0
# Tags:        exemplo
# Author:      Seu Nome
```

### Passo 3: Pronto!

O menu principal detecta automaticamente. Não precisa editar mais nada.

### Usando IA para criar scripts

Consulte o [Guia para IA](docs/AI-PROMPT.md) — contém instruções completas para que
ChatGPT, Copilot, Claude ou qualquer IA gere scripts 100% compatíveis.

---

## 🧪 Testando Scripts

### Sem Docker (rápido)
```bash
# Dry-run — simula sem instalar
sudo bash docker/meu-script.sh --dry-run

# Validar metadados
bash tests/run-tests.sh --metadata

# Lint com ShellCheck
bash tests/run-tests.sh --lint
```

### Com Docker (seguro)
```bash
# Dry-run em container Ubuntu
bash tests/run-tests.sh --dry-run-only --distro ubuntu

# Todos os testes
bash tests/run-tests.sh

# Testar script específico
bash tests/run-tests.sh --script docker/meu-script.sh
```

---

## 🏗️ Arquitetura

```
                      ┌──────────────┐
                      │   setup.sh   │  ← Ponto de entrada
                      └──────┬───────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
     ┌─────┴─────┐    ┌─────┴─────┐    ┌──────┴──────┐
     │ common.sh │    │ registry  │    │  runner.sh  │
     │           │    │   .sh     │    │             │
     │ • Cores   │    │ • Scan    │    │ • Batch     │
     │ • msg_*   │    │ • Meta    │    │ • DryRun    │
     │ • cs_run  │    │ • Filter  │    │ • Reboot    │
     │ • Checks  │    │ • List    │    │ • Report    │
     └───────────┘    └───────────┘    └──────┬──────┘
                                              │
                                       ┌──────┴──────┐
                                       │  state.sh   │
                                       │             │
                                       │ • Save/Load │
                                       │ • systemd   │
                                       │ • Resume    │
                                       └──────┬──────┘
                                              │
                               /var/lib/custom_scripts/state

           │
     ┌─────┼──────────┐
     │     │          │
   ┌─┴──┐ ┌┴────┐ ┌──┴────┐
   │ 📁 │ │ 📁  │ │  📁   │   ← Pastas auto-escaneadas
   │dock│ │netw │ │secur  │
   │er/ │ │ork/ │ │ity/   │
   └────┘ └─────┘ └───────┘
```

### Como funciona o Auto-Discovery

1. `registry.sh` escaneia **todas** as pastas de primeiro nível
2. Ignora `lib/`, `templates/`, `docs/`, `tests/`
3. Para cada `.sh`, lê as primeiras 30 linhas buscando metadados
4. Scripts com `Title:` válido são registrados automaticamente
5. Filtra por ambiente (VM, LXC) antes de exibir no menu

### Como funciona o Resume após Reboot

1. O **Wizard** ou o **Runner** detecta que um reboot é necessário
2. Salva a fila de scripts em `/var/lib/custom_scripts/state`
3. Instala um serviço **systemd oneshot** (`custom-scripts-resume.service`)
4. Faz o reboot
5. No próximo boot, o serviço executa `setup.sh --resume`
6. O resume lê o state, pula scripts já concluídos, e continua
7. Ao finalizar tudo, remove o serviço e limpa o estado

```
  ┌── Wizard / Runner ──┐
  │  hostname + IP       │
  │  scripts 1, 2, 3     │
  │  script 2 precisa ↻  │
  └──────────┬───────────┘
             │
  ┌──────────▼───────────┐
  │  Salva estado:       │
  │  ✔ script 1 (DONE)   │
  │  ✔ script 2 (DONE)   │
  │  ⏳ script 3 (PENDING)│
  └──────────┬───────────┘
             │ reboot
  ┌──────────▼───────────┐
  │  systemd resume      │
  │  setup.sh --resume   │
  │  ⏳ script 3 → RUN    │
  │  ✔ DONE!             │
  └──────────────────────┘
```

### Como funciona o Dry-Run

1. `cs_run()` — wrapper que intercepta comandos do sistema
2. Em modo `--dry-run`, os comandos são **exibidos** mas **não executados**
3. Scripts que suportam `DryRun: yes` recebem a flag `--dry-run`
4. Scripts que não suportam têm seus comandos listados em modo preview

---

## 🤝 Contribuindo

1. Fork o repositório
2. Crie seu script seguindo o [template](templates/script-template.sh)
3. Coloque na pasta da categoria correta
4. Teste: `bash tests/run-tests.sh --script seu-script.sh`
5. Abra um Pull Request

Veja o [Guia de Contribuição](CONTRIBUTING.md) para detalhes completos.

---

## ⚠️ Segurança

- Sempre revise o código antes de executar com root
- Use `--dry-run` para verificar o que será feito
- Teste em ambiente seguro antes de produção
- Scripts são fornecidos "como estão", sem garantias

## 📜 Licença

GPL v3 — Veja [LICENSE](LICENSE) para detalhes.
