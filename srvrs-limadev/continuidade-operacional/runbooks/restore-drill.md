# Runbook - Drill de Restore

## Objetivo

Validar periodicamente que os backups estao restauraveis.

## Frequencia recomendada

- Semanal: drill tecnico automatizado.
- Mensal: drill ampliado com validacao funcional.

## Execucao manual

- `limadev-drill-restore.sh --job-config /etc/limadev/jobs/<job>.env`

## Execucao via systemd

- `systemctl start limadev-backup-drill@<job>.service`
- `systemctl status limadev-backup-drill@<job>.service`

## Criterio de sucesso

- `restic check` sem erro critico.
- Restore concluido no target temporario.
- Relatorio markdown gerado em `/var/log/limadev-backup`.

## Pos-drill

- Abrir incidente se houver falha.
- Registrar evidencias e acao corretiva.
- Reexecutar ate obter PASS.
