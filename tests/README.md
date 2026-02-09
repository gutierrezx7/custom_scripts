# Tests

Diretório de testes do Custom Scripts. Veja o README principal para mais informações.

## Como usar

```bash
# Validar metadados de todos os scripts (rápido, sem Docker)
bash tests/run-tests.sh --metadata

# Lint com ShellCheck (rápido, sem Docker)
bash tests/run-tests.sh --lint

# Dry-run em Docker (seguro, não instala nada)
bash tests/run-tests.sh --dry-run-only

# Todos os testes
bash tests/run-tests.sh
```
