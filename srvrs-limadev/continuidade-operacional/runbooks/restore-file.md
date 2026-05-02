# Runbook - Restore de Arquivo

## Objetivo

Restaurar arquivo(s) ou pasta(s) especificos sem impactar todo o servico.

## Pre-requisitos

- `/etc/limadev/backup.env` configurado.
- Job existente em `/etc/limadev/jobs/<job>.env`.
- Binario `limadev-restore-job.sh` instalado.

## Passos

1. Criar diretorio de restauracao temporario:
   - `mkdir -p /tmp/restore-file`
2. Executar restore do job:
   - `limadev-restore-job.sh --job-config /etc/limadev/jobs/<job>.env --target /tmp/restore-file --snapshot latest`
3. Se necessario, restaurar apenas um caminho:
   - `limadev-restore-job.sh --job-config /etc/limadev/jobs/<job>.env --target /tmp/restore-file --snapshot latest --include /caminho/do/arquivo`
4. Validar integridade e copiar para destino final.

## Validacao

- Arquivo restaurado abre sem erro.
- Permissoes ajustadas conforme servico.
- Checksum opcional confere com referencia.

## Evidencia minima

- Host, job e snapshot usado.
- Caminho restaurado.
- Resultado (PASS/FAIL).
- Acao corretiva, se houve.
