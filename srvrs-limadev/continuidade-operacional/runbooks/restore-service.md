# Runbook - Restore de Servico Completo

## Objetivo

Restaurar servico completo (dados + configuracao) para voltar operacao.

## Escopo tipico

- Banco de dados.
- Volumes persistentes do servico.
- Configuracao de sistema associada.

## Pre-requisitos

- Janela de manutencao aprovada.
- Snapshot de destino definido (latest ou ID).
- Plano de rollback definido.

## Passos

1. Identificar job(s) do servico em `/etc/limadev/jobs`.
2. Parar servico alvo para evitar escrita concorrente.
3. Restaurar dados em staging:
   - `limadev-restore-job.sh --job-config /etc/limadev/jobs/<job>.env --target /tmp/restore-service --snapshot <id_ou_latest>`
4. Aplicar restauracao no destino oficial (com cuidado de permissao/ownership).
5. Subir servico e executar healthcheck.
6. Validar funcionalmente com checklist de negocio.

## Validacao tecnica minima

- Servico sobe sem erro.
- Endpoint de health responde OK.
- Logs sem erro critico no startup.
- Dado principal acessivel.

## Evidencia minima

- Inicio/fim da janela.
- Snapshot usado.
- Resultado de healthcheck.
- Resultado funcional (PASS/FAIL).
