# 💾 Backup & Recovery Scripts

Soluções para backup e recuperação de dados.

## 📋 Scripts Disponíveis

### backup-files.sh

**Descrição**: Backup incremental de arquivos e diretórios com compressão

**Uso**:
```bash
bash backup-files.sh [origem] [destino] [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-c, --compress`: Comprimir backup
- `-e, --encrypt`: Encriptar backup
- `-i, --incremental`: Backup incremental

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário (root para arquivos de sistema)
- Dependências: tar, gzip, rsync

**Exemplo**:
```bash
bash backup-files.sh /home/usuario /backup/home --compress --incremental
```

---

### backup-mysql.sh

**Descrição**: Backup automático de bases de dados MySQL/MariaDB

**Uso**:
```bash
bash backup-mysql.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-d, --database`: Base de dados específica
- `-a, --all`: Todas as bases de dados
- `-c, --compress`: Comprimir backup

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário com acesso ao MySQL
- Dependências: mysqldump, gzip

**Exemplo**:
```bash
bash backup-mysql.sh --all --compress
```

---

### sync-files.sh

**Descrição**: Sincronização de arquivos entre servidores ou diretórios

**Uso**:
```bash
bash sync-files.sh [origem] [destino] [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-d, --delete`: Deletar arquivos no destino que não existem na origem
- `-n, --dry-run`: Simular sincronização

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário
- Dependências: rsync

**Exemplo**:
```bash
bash sync-files.sh /var/www usuario@servidor:/backup/www --delete
```

---

### restore-backup.sh

**Descrição**: Restauração de backups criados pelos scripts deste repositório

**Uso**:
```bash
bash restore-backup.sh [arquivo-backup] [destino]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-v, --verify`: Verificar integridade antes de restaurar
- `-f, --force`: Forçar restauração (sobrescrever)

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário (root para arquivos de sistema)
- Dependências: tar, gzip

**Exemplo**:
```bash
bash restore-backup.sh backup-20231215.tar.gz /home/usuario --verify
```

## 🎯 Categorias

Scripts nesta pasta cobrem:

- 💾 Backup de arquivos e diretórios
- 🗄️ Backup de bancos de dados (MySQL, PostgreSQL)
- 📦 Backup completo de sistema
- 🔄 Sincronização de arquivos
- 📅 Agendamento de backups
- 🔐 Encriptação de backups
- ♻️ Restauração de backups
- 🗂️ Rotação de backups antigos

## 📦 Instalação Rápida

Para usar todos os scripts desta categoria:

```bash
cd ~/custom_scripts/backup
chmod +x *.sh
```

## ⚠️ Avisos Importantes

- Sempre teste restaurações de backup regularmente
- Armazene backups em locais separados do sistema original
- Use encriptação para dados sensíveis
- Implemente estratégia 3-2-1: 3 cópias, 2 mídias diferentes, 1 offsite
- Verifique a integridade dos backups periodicamente

## 🕐 Automação

Para agendar backups automáticos com cron:

```bash
# Backup diário às 2h da manhã
0 2 * * * /path/to/backup-files.sh /home /backup/home --compress --incremental

# Backup de MySQL diário às 3h da manhã
0 3 * * * /path/to/backup-mysql.sh --all --compress
```

## 🤝 Contribuindo

Tem um script de backup útil? Contribua seguindo nosso [guia de contribuição](../CONTRIBUTING.md)!

## 📚 Recursos Adicionais

- [Backup Best Practices](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/)
- [rsync Documentation](https://rsync.samba.org/documentation.html)
- [MySQL Backup Guide](https://dev.mysql.com/doc/refman/8.0/en/backup-methods.html)
