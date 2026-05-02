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

## 2.1 Status de implantacao - 2026-05-02

Base operacional validada no `vps-assist`:

- bucket remoto privado `limadev-backup` criado no Backblaze B2;
- chave de aplicacao restrita ao bucket criada para uso Restic/S3;
- repositorio Restic inicializado;
- `restic check` executado com sucesso;
- snapshot `db` criado: `2ec26849`;
- snapshot `system_config` criado: `13dcbb23`;
- drill de restore do `db` executado com resultado PASS;
- timers de backup, drill e heartbeat ativados no `vps-assist`;
- Telegram validado com envio real;
- heartbeat do `vps-assist` em `ok`.

Pendencias de v1:

- implantar `vps-prod`;
- implantar `vps-dev`;
- implantar `mini-pc`;
- implantar `note-limdev`;
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
- [ ] implantar jobs criticos em `vps-prod`;
- [x] ativar notificacao Telegram;
- [x] validar restore de servico critico no `vps-assist`.

### Onda 2

- [ ] expandir para as 5 maquinas e todas as classes de dados prioritarias;
- [x] consolidar evidencia recorrente inicial no `vps-assist`.

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
