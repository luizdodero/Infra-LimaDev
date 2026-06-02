# PRD v1 - Continuidade Operacional da Infra LimaDev

## 1. Problema

A infraestrutura possui hardening e operacao razoavelmente maduros, mas nao possui padrao de backup/restore automatizado e monitorado de ponta a ponta.

Impactos atuais:

- risco de perda parcial ou total de dados por falta de rotina uniforme;
- ausencia de validacao periodica de restauracao;
- ausencia de trilha formal de evidencias para auditoria operacional.

## 2. Objetivo

Criar um produto interno de continuidade operacional com:

- backup automatizado e criptografado para backend S3 compativel;
- monitoramento com alertas de falha e atraso;
- restauracao validada para arquivo, servico e host completo;
- reconstruicao de maquina do zero com bootstrap automatizado.

## 2.1 Status de implantacao - 2026-06-02

Base operacional validada e expandida:

- bucket remoto privado `limadev-backup` criado no Backblaze B2;
- chave de aplicacao restrita ao bucket criada para uso Restic/S3;
- repositorio Restic inicializado; `restic snapshots --json` no `vps-assist` retornou 53 snapshots em 2026-06-02 apos revalidacao;
- `vps-assist` operacional como host central de ingestao/summary, com backups, drill DB e heartbeat ativos;
- `vps-prod` operacional com backups de `db`, `app_data`, `system_config`, drill DB e heartbeat ativos;
- `vps-prod-db` cobre PicFound, VoxGate, Camada 30 atendimento e Zammad via dumps logicos;
- `vps-prod-app` cobre `/opt/limadev/camada30` e volumes relevantes de Zammad (`zammad-storage` e `zammad-backup`);
- `vps-dev` reporta OK no heartbeat com backups ativos de `repos` e `system_config`; a classe `db` local foi retirada do escopo operacional porque serve apenas a testes locais no VPS;
- `mini-pc` desbloqueado para implantacao: acesso validado como `limadev@100.87.104.42:22022` com chave `/root/.ssh/id_mini_pc_limalab`, `sudo -n` habilitado, stack instalada e snapshots iniciais de `system_config`, `repos` e `ops_artifacts` criados;
- `mini-pc` e tratado como servidor; teve exclude aplicado, drill manual de restore `system_config` validado, heartbeat recebido no `vps-assist`, timers de backup/heartbeat ativos e timer recorrente de drill `mini-pc-system` ativado;
- `note-limdev` desbloqueado para implantacao: acesso validado como `luiz@100.123.108.43:22` com chave `/root/.ssh/id_note_opsbot`, `sudo -n` habilitado, stack instalada e snapshots iniciais de `system_config`, `repos` e `ops_artifacts` criados;
- `note-limdev` teve `EXCLUDE_FILE` aplicado, drill manual de restore `system_config` validado, heartbeat recebido no `vps-assist` e timers de backup/heartbeat ativos;
- scripts `backup_job.sh` e `heartbeat_report.sh` foram endurecidos contra falsos negativos de repositorio Restic, lock temporario no `forget/prune` e selecao incorreta do snapshot mais recente; quando o snapshot ja foi criado, lock no `forget/prune` passa a ser aviso operacional em vez de falha do backup;
- `note-limdev` e a unica estacao de trabalho no escopo atual; drill pesado/restore amplo ficou sob autorizacao explicita em Multica `LIM-40`, status `in_review`, prioridade `medium`, sem execucao automatica;
- recorrencia de aprovacao do `note-limdev` configurada no Multica do `vps-assist`: autopilot `f4171362-8ade-4e94-a5c3-e08fb689a81e`, modo `create_issue`, cron `0 9 5 * *`, timezone `America/Sao_Paulo`, para criar mensalmente uma issue de revisao sem iniciar o drill automaticamente;
- Telegram/summary diario permanecem ativos no `vps-assist`;
- heartbeat de 2026-06-02: `vps-assist`, `vps-prod`, `vps-dev`, `mini-pc` e `note-limdev` em `ok`; `Status geral: OK`.

Pendencias de v1:

- acompanhar a issue mensal criada pelo autopilot Multica `f4171362-8ade-4e94-a5c3-e08fb689a81e` e aguardar autorizacao de janela para drill leve/amostral do `note-limdev`;
- executar drill de falha simulada apos todos os hosts reportarem;
- rotacionar/revogar chave ampla usada no bootstrap e manter somente chave restrita.

## 3. Escopo

### 3.1 Maquinas

- note-limdev
- mini-pc
- vps-assist
- vps-dev
- vps-prod

### 3.2 Classes de dados

- bancos de dados
- volumes persistentes de aplicacao
- configuracao de sistema
- repositorios locais relevantes
- artefatos operacionais

## 4. Requisitos funcionais

1. Executar backup automatico por host e classe de dado.
2. Encriptar no cliente antes de enviar para o backend remoto.
3. Aplicar retencao 7 diarios, 4 semanais e 6 mensais.
4. Alertar por Telegram em falha, atraso ou ausencia de execucao.
5. Publicar evidencia por execucao (host, job, duracao, tamanho, status).
6. Suportar restore em 3 niveis:
   - arquivo;
   - servico completo;
   - host completo (rebuild).

## 5. Requisitos nao funcionais

- SLO critico: RPO 6h, RTO 4h.
- taxa de sucesso mensal >= 98% dos jobs.
- seguranca por menor privilegio em credenciais do backend remoto.
- runbooks legiveis e executaveis por operador diferente.

## 6. Arquitetura v1

- coleta local por host com dumps/snapshots logicos;
- restic como motor de snapshot e criptografia;
- backend S3 compativel;
- timer systemd por job;
- notificacao Telegram;
- drill de restore recorrente.

## 7. Roadmap

### Onda 0

- [x] reconciliar inventario canonicamente;
- [x] fechar matriz de ativos/criticidade;
- [x] definir jobs iniciais por host/classe.

### Onda 1

- [x] implantar jobs criticos em `vps-assist`;
- [x] implantar jobs criticos em `vps-prod`;
- [x] ativar notificacao Telegram;
- [x] validar restore de servico critico no `vps-assist`;
- [x] validar restore critico de `vps-prod-db`.

### Onda 2

- [x] expandir para as 5 maquinas e todas as classes de dados prioritarias;
- [x] consolidar evidencia recorrente inicial no `vps-assist`;
- [x] ativar `vps-dev` para `repos`, `system_config` e heartbeat;
- [x] concluir `note-limdev`: ajuste de excludes, drill manual de restore, heartbeat e timers de backup/heartbeat;
- [x] ativar timer recorrente de drill do `mini-pc` como servidor;
- [x] criar autopilot Multica mensal para solicitar autorizacao de janela do drill `note-limdev` sem execucao automatica;
- [ ] executar drill leve/amostral do `note-limdev` somente apos autorizacao de janela humana;
- [x] retirar `vps-dev-db` do escopo operacional; banco local do VPS e apenas ambiente de teste local.

### Onda 3

- [x] validar restore tecnico de `db` no `vps-assist`;
- [ ] validar restore de arquivo;
- [ ] validar restore de servico completo;
- [ ] executar drill de rebuild completo em maquina critica.

### Onda 4

- [ ] operacao continua, tuning de custo e revisao de retencao.

## 8. Criterios de aceite v1

1. inventario completo das 5 maquinas com classes de dados;
2. jobs automatizados documentados e rastreaveis;
3. alertas Telegram em producao;
4. restore de servico validado com evidencia;
5. runbook de rebuild completo publicado.
