# Runbook - Rebuild de Maquina do Zero

## Objetivo

Reestabelecer host completo apos perda total, mantendo RTO alvo.

## Fase A - Bootstrap base

1. Provisionar SO limpo e acesso administrativo.
2. Aplicar hardening minimo (SSH por chave, firewall, fail2ban, updates).
3. Instalar runtime base do host (docker/systemd/rede conforme papel).
4. Instalar stack de backup:
   - executar `scripts/install_backup_stack.sh` a partir do repositorio.

## Fase B - Restauracao

1. Configurar `/etc/limadev/backup.env` com credenciais validas.
2. Restaurar classes de dados na ordem:
   - `system_config`
   - `db`
   - `app_data`
   - `ops_artifacts` e `repos` quando aplicavel
3. Aplicar permissoes e ownership corretos.
4. Reconfigurar secrets locais que nao devem ficar em repo.

## Fase C - Retomada de servico

1. Subir servicos por prioridade.
2. Executar healthchecks tecnicos.
3. Executar checklist funcional de aceite.
4. Confirmar telemetria/alertas e reativar timers de backup.

## Criterio de pronto

- Acesso operacional normalizado.
- Servico principal funcional.
- Job de backup do host em execucao.
- Evidencia de recuperacao registrada.
