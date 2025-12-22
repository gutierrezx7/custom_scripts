# 🛠️ Maintenance Scripts

Scripts para manutenção e otimização do sistema Linux.

## 📋 Scripts Disponíveis

### clean-system.sh

**Descrição**: Limpeza completa do sistema removendo arquivos temporários, cache e logs antigos

**Uso**:
```bash
sudo bash clean-system.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-d, --deep`: Limpeza profunda (mais agressiva)
- `-n, --dry-run`: Mostra o que seria removido sem remover

**Requisitos**:
- Sistema: Debian/Ubuntu
- Privilégios: root
- Espaço liberado: Varia (geralmente 500MB - 5GB)

**Exemplo**:
```bash
sudo bash clean-system.sh --dry-run
sudo bash clean-system.sh --deep
```

---

### disk-analyzer.sh

**Descrição**: Análise detalhada de uso de disco e identificação de grandes arquivos

**Uso**:
```bash
bash disk-analyzer.sh [caminho]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-s, --size`: Tamanho mínimo para reportar (ex: 100M)
- `-t, --top`: Número de maiores arquivos/diretórios a mostrar

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: usuário (root para análise completa)
- Dependências: du, find

**Exemplo**:
```bash
bash disk-analyzer.sh /home --size 100M --top 20
```

---

### log-manager.sh

**Descrição**: Gerenciamento de logs do sistema com rotação e compressão

**Uso**:
```bash
sudo bash log-manager.sh [ação]
```

**Ações**:
- `rotate`: Rotacionar logs
- `compress`: Comprimir logs antigos
- `clean`: Limpar logs antigos
- `analyze`: Analisar uso de espaço por logs

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root
- Dependências: gzip, logrotate (opcional)

**Exemplo**:
```bash
sudo bash log-manager.sh clean
```

---

### optimize-system.sh

**Descrição**: Otimizações gerais de sistema para melhor performance

**Uso**:
```bash
sudo bash optimize-system.sh [opções]
```

**Opções**:
- `-h, --help`: Mostra ajuda
- `-m, --memory`: Otimizar uso de memória
- `-d, --disk`: Otimizar disco
- `-a, --all`: Aplicar todas otimizações

**Requisitos**:
- Sistema: Linux (qualquer distribuição)
- Privilégios: root

**Exemplo**:
```bash
sudo bash optimize-system.sh --all
```

## 🎯 Categorias

Scripts nesta pasta cobrem:

- 🧹 Limpeza de arquivos temporários
- 📊 Análise de uso de disco
- 📝 Gerenciamento de logs
- ⚡ Otimização de performance
- 🗑️ Remoção de pacotes órfãos
- 💾 Limpeza de cache
- 🔄 Rotação de logs

## 📦 Instalação Rápida

Para usar todos os scripts desta categoria:

```bash
cd ~/custom_scripts/maintenance
chmod +x *.sh
```

## ⚠️ Avisos Importantes

- Sempre faça backup antes de executar scripts de limpeza
- Use `--dry-run` quando disponível para ver o que será feito
- Scripts de limpeza profunda podem remover arquivos importantes se mal usados
- Revise a documentação de cada script antes de usar

## 🤝 Contribuindo

Tem um script de manutenção útil? Contribua seguindo nosso [guia de contribuição](../CONTRIBUTING.md)!

## 📚 Recursos Adicionais

- [Linux System Maintenance](https://www.cyberciti.biz/tips/linux-unix-bsd-nginx-webserver-security.html)
- [Log Management Best Practices](https://www.loggly.com/ultimate-guide/managing-linux-logs/)
- [Disk Space Management](https://www.tecmint.com/find-top-large-directories-and-files-sizes-in-linux/)
