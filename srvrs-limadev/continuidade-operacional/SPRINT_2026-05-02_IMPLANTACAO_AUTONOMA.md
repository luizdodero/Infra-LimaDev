# Sprint - Implantacao Autonoma de Continuidade Operacional

## Objetivo

Expandir a implantacao de backup, restore drill e heartbeat do `vps-assist` para `vps-prod`, `vps-dev`, `mini-pc` e `note-limdev` em modo autonomo, com execucao segura, sem interromper servicos e sem solicitar interacao humana durante a sprint.

## Janela

- Inicio sugerido: apos validacao do `vps-assist` em `2026-05-02`.
- Duracao alvo: 1 a 2 dias operacionais.
- Modo: autonomo com checkpoints em arquivo e Telegram.

## Estado Inicial Validado

- `vps-assist` implantado.
- Bucket B2 privado `limadev-backup` criado.
- Repositorio Restic inicializado.
- Chave B2 restrita ao bucket em uso.
- `restic check`: OK.
- Snapshot `db` do `vps-assist`: `2ec26849`.
- Snapshot `system_config` do `vps-assist`: `13dcbb23`.
- Drill `vps-assist-db`: PASS.
- Heartbeat `vps-assist`: OK.
- Telegram: OK.

## Hosts da Sprint

| Ordem | Host | Classe | Meta |
|---|---|---|---|
| 1 | `vps-prod` | critical | backup + heartbeat + drill critico |
| 2 | `vps-dev` | high | backup + heartbeat |
| 3 | `mini-pc` | medium | backup + heartbeat |
| 4 | `note-limdev` | medium | backup + heartbeat |

## Regras de Autonomia

O agente deve prosseguir sem solicitar interacao quando:

- acesso SSH existe;
- host responde;
- disco tem espaco suficiente para dump temporario;
- Docker/systemd estao saudaveis o bastante para leitura;
- backup pode ser feito em modo somente leitura ou com dump logico;
- falha e recuperavel por retry simples.

O agente deve pular o host, registrar bloqueio e seguir para o proximo quando:

- SSH falhar por permissao ou timeout apos 3 tentativas;
- host nao puder ser identificado com seguranca;
- backup exigir segredo ausente no host;
- houver risco de sobrescrever dados;
- banco exigir operacao destrutiva;
- comando de dump falhar por credencial de aplicacao desconhecida;
- root filesystem estiver acima de 90%;
- `restic check` falhar de forma nao transitoria.

O agente nao deve executar:

- `rm -rf` em diretorios de dados de aplicacao;
- restore sobre paths de producao;
- `docker compose down`, `systemctl stop` de servicos de negocio ou reboot;
- alteracao de DNS, firewall publico ou usuario de aplicacao;
- rotacao/revogacao de chave Backblaze durante a sprint.

## Guardrails Tecnicos

- Copiar modulo para `/opt/limadev/continuidade-operacional`.
- Nunca copiar `secure/` para hosts.
- Gerar `/etc/limadev/backup.env` no host usando valores do arquivo privado local.
- Gerar `/etc/limadev/restic-password` com permissao `600`.
- Gerar `/etc/limadev/heartbeat.env` com permissao `600`.
- Rodar backup primeiro em classes menores/criticas.
- Todo restore deve ir para `/tmp/limadev-drill`, nunca para destino real.
- Toda evidencia deve ir para `/var/log/limadev-backup` ou `/var/log/limadev-heartbeat`.
- Toda falha deve ser registrada em `SPRINT_2026-05-02_IMPLANTACAO_AUTONOMA_STATUS.md`.

## Definition of Done

Para cada host, a implantacao so esta concluida quando:

- `restic snapshots --host <host>` lista pelo menos 1 snapshot valido;
- heartbeat do host e aceito no `vps-assist`;
- timer de heartbeat esta ativo;
- timers de backup estao ativos para jobs configurados;
- logs nao contem erro critico na ultima execucao;
- evidencia markdown ou bloco de status foi registrado;
- Telegram diario passa a refletir o host como reportado.

Para hosts critical (`vps-prod`):

- deve haver drill de restore PASS para a classe mais critica;
- se drill falhar, manter backup ativo mas marcar host como bloqueado para aceite.

## Plano de Execucao

### Fase 0 - Preflight Global

- [ ] Confirmar que `secure/limadev-backup-credentials.env` esta ignorado pelo git.
- [ ] Validar campos obrigatorios do `.env` privado sem imprimir valores.
- [ ] Rodar `restic check` local.
- [ ] Rodar `tests/heartbeat_tests.sh`.
- [ ] Confirmar Telegram com mensagem de teste curta.
- [ ] Criar/atualizar `SPRINT_2026-05-02_IMPLANTACAO_AUTONOMA_STATUS.md`.

### Fase 1 - Preparar Ingestao Remota no vps-assist

- [ ] Criar usuario restrito `limadev-report` se nao existir.
- [ ] Instalar `authorized_keys` com `command="/usr/local/bin/limadev-heartbeat-ingest"`.
- [ ] Testar ingestao remota com fixture JSON de host permitido.
- [ ] Confirmar rejeicao de host desconhecido.
- [ ] Registrar evidencia.

### Fase 2 - vps-prod

- [ ] Descobrir acesso SSH por aliases/config local.
- [ ] Validar identidade do host.
- [ ] Copiar modulo sem `secure/`.
- [ ] Instalar stack.
- [ ] Criar jobs `db`, `app_data`, `system_config` conforme descoberta.
- [ ] Criar excludes conservadores para caches/runtimes.
- [ ] Executar primeiro backup.
- [ ] Executar drill da classe critica.
- [ ] Configurar heartbeat remoto.
- [ ] Ativar timers.
- [ ] Registrar evidencia.

### Fase 3 - vps-dev

- [ ] Descobrir acesso SSH por aliases/config local.
- [ ] Validar identidade do host.
- [ ] Copiar modulo sem `secure/`.
- [ ] Instalar stack.
- [ ] Criar jobs `app_data`, `system_config`, `repos` conforme descoberta.
- [ ] Executar primeiro backup.
- [ ] Configurar heartbeat remoto.
- [ ] Ativar timers.
- [ ] Registrar evidencia.

### Fase 4 - mini-pc

- [ ] Validar acesso SSH via Tailscale.
- [ ] Validar identidade do host.
- [ ] Copiar modulo sem `secure/`.
- [ ] Instalar stack.
- [ ] Criar jobs `app_data`, `system_config`, `repos`.
- [ ] Evitar backup de modelos grandes e caches (`Ollama`, modelos STT/TTS) salvo se explicitamente classificados como dado critico.
- [ ] Executar primeiro backup.
- [ ] Configurar heartbeat remoto.
- [ ] Ativar timers.
- [ ] Registrar evidencia.

### Fase 5 - note-limdev

- [ ] Validar acesso local ou SSH.
- [ ] Validar identidade do host.
- [ ] Copiar modulo sem `secure/`.
- [ ] Instalar stack.
- [ ] Criar jobs `repos`, `ops_artifacts`, `system_config`.
- [ ] Evitar backup de caches, downloads e diretorios temporarios.
- [ ] Executar primeiro backup.
- [ ] Configurar heartbeat remoto.
- [ ] Ativar timers.
- [ ] Registrar evidencia.

### Fase 6 - Consolidacao

- [ ] Rodar heartbeat report em todos os hosts acessiveis.
- [ ] Rodar summary no `vps-assist`.
- [ ] Confirmar Telegram com status consolidado.
- [ ] Rodar `restic snapshots` por host.
- [ ] Rodar `restic check`.
- [ ] Atualizar roadmap e status final.
- [ ] Listar hosts bloqueados, se houver.

## Testes Obrigatorios

- `bash tests/heartbeat_tests.sh`
- `bash -n scripts/*.sh tests/*.sh`
- `systemd-analyze verify systemd/*.service systemd/*.timer`
- `restic check`
- `restic snapshots --host <host>`
- `systemctl start limadev-heartbeat-report.service`
- `systemctl start limadev-heartbeat-summary.service` no `vps-assist`
- `systemctl list-timers --all "limadev-*"`

## Evidencia Minima por Host

Registrar no status da sprint:

```text
Host:
Inicio:
Fim:
Resultado: PASS | BLOCKED | FAIL
Jobs criados:
Snapshots:
Drill:
Heartbeat:
Timers:
Alertas:
Bloqueios:
Proxima acao:
```

## Criterios de Falha da Sprint

A sprint deve encerrar como `FAIL` se:

- `vps-assist` perder acesso ao repositorio Restic;
- Telegram parar de funcionar;
- chave B2 restrita deixar de autenticar;
- backup do `vps-assist` deixar de listar snapshots existentes;
- qualquer comando tentar operacao destrutiva fora dos guardrails.

Se um host individual falhar, marcar `BLOCKED` e seguir para o proximo.

## Pos-Sprint

- Rotacionar/revogar chave ampla usada no bootstrap.
- Manter somente chave B2 restrita ao bucket.
- Gerar copia criptografada atualizada do `.env` privado para Google Drive.
- Avaliar custo/tamanho dos primeiros snapshots.
- Revisar excludes por host apos 7 dias de operacao.
