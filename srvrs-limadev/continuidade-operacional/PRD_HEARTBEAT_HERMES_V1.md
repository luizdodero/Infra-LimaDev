# PRD v1 - Heartbeat Diario de Backup via Hermes

## 1. Problema

O stack de backup da Infra LimaDev ja possui jobs, timers, drills e alertas por Telegram, mas ainda falta uma confirmacao diaria consolidada de saude operacional.

Sem um heartbeat centralizado, uma maquina pode parar de executar backups, perder conectividade, ficar sem espaco ou deixar de reportar falhas sem que isso seja percebido rapidamente. O principal risco e o silencio operacional: ausencia de alerta nao significa que o backup esta saudavel.

## 2. Objetivo

Criar um fluxo diario de reporte para as maquinas do escopo Infra LimaDev, centralizado no `vps-assist`, onde o Hermes consolida o estado e envia uma mensagem unica de confirmacao no Telegram.

O produto deve responder diariamente:

- quais hosts reportaram;
- quais hosts nao reportaram;
- quais jobs de backup estao OK, atrasados ou falhos;
- se houve drill recente;
- se ha risco operacional simples, como disco alto ou unidade systemd falha;
- qual e o status geral da continuidade: OK, ATENCAO ou FALHA.

## 2.1 Status de implantacao - 2026-05-02

Base implementada e validada:

- `limadev-heartbeat-report.sh` criado;
- `limadev-heartbeat-ingest` criado;
- `limadev-heartbeat-daily-summary.sh` criado;
- `heartbeat.env.example` criado;
- units systemd de report e summary criadas;
- testes locais `tests/heartbeat_tests.sh` passando;
- Telegram validado com envio real;
- `vps-assist` em modo `HEARTBEAT_INGEST_MODE=local`;
- report do `vps-assist` gravado em `/var/lib/limadev-heartbeats/YYYY-MM-DD/vps-assist.json`;
- summary diario gerado em `/var/log/limadev-heartbeat/daily-summary-YYYY-MM-DD.md`;
- timer `limadev-heartbeat-report.timer` ativo no `vps-assist`;
- timer `limadev-heartbeat-summary.timer` ativo no `vps-assist`.

Estado esperado ate completar rollout:

- resumo diario fica `ATENCAO`;
- `vps-assist` aparece como `OK`;
- `vps-prod`, `vps-dev`, `mini-pc` e `note-limdev` aparecem como ausentes.

## 3. Escopo

### 3.1 Maquinas

- `vps-assist`
- `vps-prod`
- `vps-dev`
- `mini-pc`
- `note-limdev`

### 3.2 Componentes

- agente local de heartbeat em cada host;
- envio seguro do relatorio para o `vps-assist`;
- ingestao centralizada no `vps-assist`;
- resumo diario com Hermes;
- notificacao Telegram;
- evidencias locais dos reports e resumos.

### 3.3 Fora de escopo v1

- dashboard web;
- banco de dados relacional para historico;
- API HTTP publica;
- correcao automatica de falhas;
- restore automatico destrutivo;
- gerenciamento de credenciais por cofre externo.

## 4. Usuarios

- operador de infraestrutura LimaDev;
- agente IA responsavel por manutencao e diagnostico;
- responsavel pelo acompanhamento diario de continuidade.

## 5. Requisitos funcionais

1. Cada host deve gerar um heartbeat diario em formato estruturado.
2. O heartbeat deve conter, no minimo:
   - host;
   - timestamp local;
   - uptime;
   - uso de disco raiz;
   - timers de backup ativos;
   - status dos services de backup/drill recentes;
   - ultimo snapshot Restic por job configurado;
   - ultimo drill conhecido quando houver;
   - unidades systemd em falha;
   - status final local: `ok`, `warning` ou `fail`.
3. Cada host deve enviar o heartbeat para o `vps-assist` via canal privado.
4. O `vps-assist` deve armazenar os heartbeats recebidos por data e host.
5. O `vps-assist` deve detectar hosts esperados que nao reportaram.
6. O Hermes deve gerar um resumo diario em linguagem operacional curta.
7. O resumo diario deve ser enviado para Telegram.
8. O fluxo deve gerar evidencia em arquivo local no `vps-assist`.
9. O operador deve conseguir executar coleta, ingestao e resumo manualmente.

## 6. Requisitos nao funcionais

- Transporte preferencial: SSH via Tailscale, sem endpoint HTTP publico.
- Agendamento preferencial: systemd timer, mantendo o padrao do stack atual.
- Cron sera aceito apenas como fallback documentado.
- Scripts devem ser idempotentes.
- Falha de um host nao deve impedir o resumo dos demais.
- Segredos nao devem aparecer em logs, repo ou mensagens Telegram.
- Mensagem Telegram deve ser curta e acionavel.
- O fluxo deve funcionar sem depender de interacao manual diaria.

## 7. Arquitetura v1

### 7.1 Coleta local

Cada host executa um script local, por exemplo `limadev-heartbeat-report.sh`, que le configuracoes em `/etc/limadev/heartbeat.env` e inspeciona o estado local do backup.

O script nao altera estado de backup. Ele apenas coleta dados e monta um JSON.

### 7.2 Transporte

O envio recomendado e via SSH para o `vps-assist`.

Modelo esperado:

```bash
limadev-heartbeat-report.sh | ssh limadev-report@vps-assist 'limadev-heartbeat-ingest'
```

O usuario remoto `limadev-report` deve ser restrito para executar apenas o comando de ingestao.

### 7.3 Ingestao central

No `vps-assist`, `limadev-heartbeat-ingest` valida o JSON, identifica o host e grava em:

```text
/var/lib/limadev-heartbeats/YYYY-MM-DD/<host>.json
```

Erros de ingestao devem ser registrados em:

```text
/var/log/limadev-heartbeat/ingest.log
```

### 7.4 Consolidacao com Hermes

Um timer diario no `vps-assist` executa o sumarizador depois da janela esperada de reportes.

O sumarizador:

- carrega a lista de hosts esperados;
- le os JSONs recebidos no dia;
- marca hosts ausentes;
- calcula status geral;
- chama Hermes para gerar texto operacional;
- envia Telegram.

### 7.5 Evidencias

Cada resumo diario deve gerar arquivo markdown:

```text
/var/log/limadev-heartbeat/daily-summary-YYYY-MM-DD.md
```

## 8. Status Geral

O status geral deve seguir esta regra:

- `OK`: todos os hosts esperados reportaram e nenhum item critico falhou.
- `ATENCAO`: existe host ausente, backup atrasado, drill antigo, disco alto ou warning local.
- `FALHA`: existe falha explicita de backup recente, Restic inacessivel em host critico ou erro critico de coleta no `vps-assist`.

## 9. Roadmap

### Onda 0 - Desenho e Contratos

- [x] definir contrato JSON do heartbeat;
- [x] definir arquivo `/etc/limadev/heartbeat.env`;
- [x] definir lista canonica de hosts esperados;
- [x] definir mensagem Telegram padrao;
- [x] documentar operacao manual.

### Onda 1 - Coleta Local

- [x] criar script de coleta local;
- [x] criar testes com fixtures de comandos simulados;
- [x] validar saida JSON;
- [x] adicionar systemd service/timer local.

### Onda 2 - Ingestao no vps-assist

- [x] criar script de ingestao;
- [x] validar JSON recebido;
- [x] gravar relatorio por data/host;
- [ ] restringir usuario SSH de ingestao para hosts remotos;
- [ ] testar envio via Tailscale a partir de host remoto.

### Onda 3 - Resumo Diario

- [x] criar sumarizador;
- [x] detectar hosts ausentes;
- [x] integrar Telegram;
- [ ] integrar Hermes como gerador de resumo;
- [x] gerar evidencia markdown.

### Onda 4 - Implantacao nos Hosts

- [x] implantar primeiro no `vps-assist`;
- [ ] implantar em `vps-prod`;
- [ ] implantar em `vps-dev`;
- [ ] implantar em `mini-pc`;
- [ ] implantar em `note-limdev`.

### Onda 5 - Operacao Continua

- revisar ruido da mensagem diaria;
- ajustar limites de alerta;
- executar drill mensal de falha simulada;
- revisar seguranca das chaves SSH restritas.

## 10. Testes e Validacao

### 10.1 Testes de unidade

- coleta gera JSON valido;
- status local vira `warning` quando disco passa do limite;
- status local vira `fail` quando backup critico falha;
- ingestao rejeita JSON invalido;
- ingestao rejeita host nao esperado;
- sumarizador marca host ausente;
- sumarizador calcula status geral corretamente.

### 10.2 Testes de integracao

- host envia heartbeat para `vps-assist` via SSH;
- `vps-assist` grava arquivo no diretorio correto;
- sumarizador le reports reais;
- Telegram recebe mensagem de teste;
- Hermes gera resumo sem expor segredos.

### 10.3 Testes operacionais

- simular host sem reporte;
- simular backup falho;
- simular disco acima de 85%;
- simular drill atrasado;
- desligar temporariamente o timer de um host;
- validar que a mensagem diaria mostra `ATENCAO` ou `FALHA`.

### 10.4 Criterios de aceite

1. Todos os 5 hosts possuem heartbeat diario instalado ou excecao documentada.
2. O `vps-assist` recebe e armazena reports por data/host.
3. O Hermes envia uma mensagem diaria no Telegram.
4. Host ausente e detectado no resumo diario.
5. Falha de backup aparece como `FALHA`.
6. Warning de disco aparece como `ATENCAO`.
7. Evidencia markdown diaria e gerada no `vps-assist`.
8. Operador consegue executar coleta, ingestao e resumo manualmente.

## 11. Riscos

- Dependencia do `vps-assist` como ponto central.
- Chaves SSH mal restringidas podem ampliar superficie de ataque.
- Mensagem diaria pode virar ruido se os criterios forem frouxos.
- Hermes pode falhar na geracao do texto, entao o sistema precisa ter fallback deterministico.
- Hosts fora da Tailscale podem ficar sem transporte.

## 12. Decisoes

- Usar systemd timer como agendador principal.
- Usar SSH via Tailscale como transporte principal.
- Centralizar Telegram no `vps-assist`.
- Usar Hermes para consolidacao textual, nao para coleta bruta.
- Manter evidencias em arquivo antes de considerar banco de dados.
