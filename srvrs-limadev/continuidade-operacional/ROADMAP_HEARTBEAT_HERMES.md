# Roadmap - Heartbeat Diario Hermes/Telegram

## Objetivo

Implantar confirmacao diaria de saude dos backups da Infra LimaDev, com reports enviados pelas maquinas do escopo para o `vps-assist`, resumo gerado pelo Hermes e notificacao unica no Telegram.

## Marcos

## Progresso atual - 2026-05-02

- Backend B2 e Restic validados.
- `vps-assist` implantado com backup `db`, backup `system_config`, drill `db` e heartbeat local.
- Telegram validado.
- Timers ativos no `vps-assist`.
- Resumo diario atual esperado: `ATENCAO`, pois os demais hosts ainda nao reportam.
- Proxima frente: sprint autonoma de implantacao nos hosts restantes.

### Marco 0 - Contrato e Documentacao

**Resultado:** escopo fechado e criterios de aceite claros.

- [x] Aprovar PRD `PRD_HEARTBEAT_HERMES_V1.md`.
- [x] Definir contrato JSON final do heartbeat.
- [x] Definir nomes dos hosts esperados.
- [x] Definir horario da janela diaria.
- [x] Definir limites de alerta:
  - disco raiz warning: 80%;
  - disco raiz fail: 90%;
  - backup atrasado critico: maior que RPO + 2h;
  - drill atrasado: maior que 8 dias para criticos.

**Teste de saida:** revisao manual do PRD e aceite do operador.

### Marco 1 - Coleta Local

**Resultado:** cada host consegue gerar heartbeat local em JSON.

- [x] Criar `scripts/heartbeat_report.sh`.
- [x] Criar `config/heartbeat.env.example`.
- [x] Adicionar leitura dos jobs em `/etc/limadev/jobs/*.env`.
- [x] Coletar snapshots Restic por host/classe.
- [x] Coletar status de timers e services systemd.
- [x] Coletar disco, uptime e unidades falhas.
- [x] Retornar exit code nao-zero apenas quando a coleta nao puder gerar JSON.

**Testes:**

- [x] Rodar coleta manual no `vps-assist`.
- [x] Rodar coleta com Restic indisponivel e validar `warning` ou `fail`.
- [x] Rodar coleta sem jobs e validar report com warning.
- [x] Validar JSON com `jq`.

### Marco 2 - Ingestao Central no vps-assist

**Resultado:** `vps-assist` recebe e persiste heartbeats.

- [x] Criar `scripts/heartbeat_ingest.sh`.
- [x] Validar JSON recebido com `jq`.
- [x] Validar host contra allowlist.
- [x] Gravar em `/var/lib/limadev-heartbeats/YYYY-MM-DD/<host>.json`.
- [x] Registrar erros em `/var/log/limadev-heartbeat/ingest.log`.
- [ ] Documentar usuario SSH restrito `limadev-report` para hosts remotos.

**Testes:**

- [x] Enviar JSON valido por stdin e verificar arquivo salvo.
- [x] Enviar JSON invalido e verificar rejeicao.
- [x] Enviar host desconhecido e verificar rejeicao.
- [x] Enviar duas vezes o mesmo host e verificar overwrite controlado do dia.

### Marco 3 - Agendamento por Host

**Resultado:** reports diarios acontecem sem intervencao manual.

- [x] Criar `systemd/limadev-heartbeat-report.service`.
- [x] Criar `systemd/limadev-heartbeat-report.timer`.
- [x] Atualizar `scripts/install_backup_stack.sh` para instalar unidades.
- [x] Documentar fallback com cron.

**Testes:**

- [x] `systemctl start limadev-heartbeat-report.service` no `vps-assist`.
- [x] `systemctl status limadev-heartbeat-report.timer` no `vps-assist`.
- [x] Verificar journal do envio no `vps-assist`.
- [ ] Simular reboot e validar `Persistent=true`.

### Marco 4 - Resumo Diario Hermes/Telegram

**Resultado:** o `vps-assist` envia uma mensagem diaria unica.

- [x] Criar `scripts/heartbeat_daily_summary.sh`.
- [x] Carregar allowlist de hosts esperados.
- [x] Detectar hosts ausentes.
- [x] Calcular status geral `OK`, `ATENCAO` ou `FALHA`.
- [x] Gerar fallback deterministico sem Hermes.
- [ ] Chamar Hermes para texto final quando disponivel.
- [x] Enviar Telegram usando variaveis de `/etc/limadev/backup.env` ou `/etc/limadev/heartbeat.env`.
- [x] Gerar markdown em `/var/log/limadev-heartbeat/daily-summary-YYYY-MM-DD.md`.

**Testes:**

- [x] Rodar resumo com todos os hosts OK em fixture local.
- [x] Rodar resumo com um host ausente.
- [x] Rodar resumo com backup falho em fixture local.
- [x] Rodar resumo com Hermes indisponivel e validar fallback.
- [x] Enviar Telegram para chat de teste.

### Marco 5 - Implantacao Controlada

**Resultado:** fluxo ativo no escopo real.

- [x] Implantar em `vps-assist`.
- [ ] Implantar em `vps-prod`.
- [ ] Implantar em `vps-dev`.
- [ ] Implantar em `mini-pc`.
- [ ] Implantar em `note-limdev`.

**Testes:**

- [x] Validar report manual no `vps-assist`.
- [x] Validar ingestao local no `vps-assist`.
- [ ] Validar resumo diario com todos os hosts.
- [x] Registrar evidencia da primeira execucao completa do `vps-assist`.

### Marco 6 - Drills de Falha

**Resultado:** o sistema detecta falhas reais, nao apenas sucesso.

- [ ] Desativar temporariamente heartbeat de host nao critico.
- [ ] Simular backup atrasado com fixture ou job desabilitado.
- [ ] Simular disco alto via fixture.
- [ ] Simular falha Hermes.
- [ ] Simular falha Telegram.

**Testes:**

- [ ] Resumo deve marcar host ausente como `ATENCAO`.
- [ ] Backup critico falho deve marcar `FALHA`.
- [ ] Falha Hermes deve manter mensagem fallback.
- [ ] Falha Telegram deve gerar evidencia local e log de erro.

## Ordem Recomendada de Entrega

1. `vps-assist` local-only: coleta + resumo sem transporte.
2. Ingestao via stdin no `vps-assist`.
3. Transporte SSH do `vps-prod` para `vps-assist`.
4. Telegram em chat de teste.
5. Expansao para os demais hosts.
6. Drill de host ausente.
7. Ativacao do Telegram oficial.

## Criterio de Pronto

- PRD aprovado.
- Scripts instalados no `vps-assist`.
- Pelo menos `vps-assist` e `vps-prod` reportando.
- Telegram diario ativo.
- Host ausente detectado corretamente.
- Evidencia markdown gerada.
- Runbook operacional publicado.
