# Mudanca de Setup LimaDev - Estrutura de Trabalho

Este workspace organiza a transicao para o ecossistema de 5 nos:
- `note-limdev` (interface humana e estacao principal de trabalho remoto)
- `mini-pc` (laboratorio de testes e desenvolvimento da portaria inteligente)
- VPS 1 (assistente e orquestracao)
- VPS 2 (producao/experimentacao)
- VPS 3 (desenvolvimento e governanca)

Base documental atual:
- `00_governanca/briefing/Briefing Projeto Mudança de Setup LimaDev.txt`
- `00_governanca/briefing/2026-03-07_adendo_topologia_mini_pc.md`

## Frentes de trabalho

1. `00_governanca`: briefing, arquitetura, roadmap, riscos e registro de decisoes.
2. `01_infra_backbone`: Tailscale, SSH, UFW e acesso confiavel ao assistente IA edge no VPS 1.
3. `02_assistente_voz`: ciclo STT -> n8n -> TTS (Piper) e testes de latencia/robustez.
4. `03_automacao_vps1`: n8n, integracoes e arquivos do assistente edge.
5. `04_producao_vps2`: projetos em execucao e camada de infra compartilhada (nginx, TLS, firewall, observabilidade).
6. `05_migracao_vps3`: inventario, saneamento e plano de sincronizacao/backup.
7. `06_seguranca`: scans, hardening, chaves SSH e politicas.
8. `99_shared`: scripts e templates reutilizaveis.

## Estrutura criada

```text
00_governanca/
01_infra_backbone/
02_assistente_voz/
03_automacao_vps1/
04_producao_vps2/
05_migracao_vps3/
06_seguranca/
99_shared/
```

## Regras praticas

1. Cada frente mantem seu proprio `README.md` com escopo e checklist.
2. Evidencias tecnicas ficam na frente correspondente (prints, logs, comandos).
3. Configuracoes compartilhadas de servidor vao em `04_producao_vps2/infra_compartilhada`.
4. Documentos de decisao e planejamento ficam em `00_governanca`.

## Proximos passos operacionais

- [ ] Validar conectividade completa entre os nos (Tailscale + SSH + HTTPS).
- [ ] Fechar acesso ao endpoint do assistente edge no VPS 1 pelo backbone.
- [ ] Consolidar execucao dos testes pesados de desenvolvimento no `mini-pc`, mantendo o `note-limdev` como interface de trabalho.
- [ ] Migrar STT/TTS e reproducao final de audio para o `mini-pc` quando os servicos equivalentes estiverem publicados.
- [ ] Iniciar inventario para saneamento e migracao ao VPS 3.
- [ ] Executar primeira rodada de scans de seguranca.

## Status rapido (2026-02-23)

- Cadeia `faster-whisper -> n8n -> openclaw -> n8n -> piper (fila)` validada.
- Cadeia com audio local via Piper validada (`2026-02-23`).
- Script oficial de validacao: `02_assistente_voz/testes/validate_voice_chain.sh`.
- Evidencia: `02_assistente_voz/testes/2026-02-23_validacao_cadeia_voz.md`.

## Atualizacao operacional (2026-03-07)

- `mini-pc` adicionado a tailnet para absorver os testes de desenvolvimento da solucao de portaria inteligente.
- `note-limdev` passa a operar prioritariamente como interface de trabalho, terminal remoto e ponto de observabilidade.
- O acesso inicial ao `mini-pc` sera bootstrapado por senha via Tailscale, seguido da instalacao de chave SSH dedicada.

## Como iniciar hoje

1. Preparar hosts:
   `cp 01_infra_backbone/checklists/hosts.example.csv 01_infra_backbone/checklists/hosts.csv`
2. Preencher `01_infra_backbone/checklists/hosts.csv` com os hosts reais.
3. (Opcional) Definir healthcheck do assistente edge:
   `export ASSISTANT_EDGE_URL="https://<host>:18789/health"`
   Para Openclaw gateway (WebSocket):
   `export ASSISTANT_EDGE_CHECK_MODE=tcp && export ASSISTANT_EDGE_HOST="<host>"`
   Se o Openclaw estiver em implantacao, nao definir `ASSISTANT_EDGE_*` nesta etapa.
   Em operacao interna, usar tailnet-only (sem funnel).
4. Rodar a primeira validacao:
   `bash 99_shared/scripts/validate_backbone.sh 01_infra_backbone/checklists/hosts.csv`
5. Salvar evidencias:
   `bash 99_shared/scripts/validate_backbone.sh 01_infra_backbone/checklists/hosts.csv | tee 01_infra_backbone/evidencias/backbone_$(date +%F_%H%M).log`
