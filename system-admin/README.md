# 🔧 System Administration Scripts

Scripts para administração e configuração de sistemas Linux.

## 📋 Scripts Disponíveis

### update-system.sh

**Descrição**: Script para atualização completa do sistema com backup e validação

**Uso**:
```bash
sudo bash update-system.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-r, --reboot`: Reinicia o sistema após atualização
- `-c, --cleanup`: Remove pacotes desnecessários após atualização

**Requisitos**:
- Sistema: Debian/Ubuntu/CentOS/RHEL
- Privilégios: root
- Dependências: apt/yum/dnf

**Exemplo**:
```bash
sudo bash update-system.sh --cleanup
```

---

### user-manager.sh

**Descrição**: Gerenciamento avançado de usuários e grupos

**Uso**:
```bash
sudo bash user-manager.sh [ação] [usuário]
```

**Ações**:
- `create`: Criar novo usuário
- `delete`: Remover usuário
- `modify`: Modificar usuário existente
- `list`: Listar usuários

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root

**Exemplo**:
```bash
sudo bash user-manager.sh create joao
```

---

### service-manager.sh

**Descrição**: Gerenciamento simplificado de serviços systemd

**Uso**:
```bash
sudo bash service-manager.sh [ação] [serviço]
```

**Ações**:
- `start`: Iniciar serviço
- `stop`: Parar serviço
- `restart`: Reiniciar serviço
- `status`: Ver status do serviço
- `enable`: Habilitar no boot
- `disable`: Desabilitar no boot

**Requisitos**:
- Sistema: Linux com systemd
- Privilégios: root

**Exemplo**:
```bash
sudo bash service-manager.sh restart nginx
```

## 🎯 Categorias

Scripts nesta pasta cobrem:

- ✅ Gerenciamento de usuários e permissões
- ✅ Configuração de serviços
- ✅ Atualizações automáticas do sistema
- ✅ Configuração de SSH
- ✅ Gerenciamento de cron jobs
- ✅ Configuração de timezone e locale
- ✅ Otimização de sistema

## 📦 Instalação Rápida

Para usar todos os scripts desta categoria:

```bash
cd ~/custom_scripts/system-admin
chmod +x *.sh
```

## 🤝 Contribuindo

Tem um script de administração útil? Contribua seguindo nosso [guia de contribuição](../CONTRIBUTING.md)!

## 📚 Recursos Adicionais

- [Linux System Administration Guide](https://www.tldp.org/LDP/sag/html/)
- [systemd Documentation](https://www.freedesktop.org/wiki/Software/systemd/)
- [Linux User Management](https://www.redhat.com/sysadmin/managing-users-passwd)
