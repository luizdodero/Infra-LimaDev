# Handoff de Pausa - 2026-02-23 15:29 (-03)

## Objetivo da sessao

Concluir base funcional da cadeia de voz:
`faster-whisper -> n8n -> openclaw -> n8n -> piper`.

## O que foi concluido

1. Acesso n8n recuperado e validado no VPS 1 (`vps-assist`).
2. Fluxo no n8n evoluiu de configuracao inicial para fluxo em 2 webhooks:
   - `POST /webhook/comando-voz` (entrada STT)
   - `POST /webhook/resposta-openclaw` (retorno do Openclaw)
3. Ponte de execucao Openclaw implementada no VPS 1:
   - `/root/bot.py` (backup antigo em `/root/bot.py.bak_2026-02-23_152026`)
4. Ponte para Piper implementada no VPS 1:
   - `/root/piper_bridge.py` (grava fila em `/root/piper_queue.jsonl`)
5. Script de validacao ponta-a-ponta criado e aprovado:
   - `02_assistente_voz/testes/validate_voice_chain.sh`
6. `escuta.py` do notebook ajustado para endpoint real do n8n e TLS self-signed.

## Estado atual validado

- Container n8n:
  - `n8n_automations` ativo em `443 -> 5678`
- Workflows ativos no banco:
  - `PndQfLZsfDZ7X9YQ` (`My workflow`) ativo
  - `VozRetn8nPiper01` (`Voice Return Piper`) ativo
- Ultimas execucoes observadas:
  - `14`: inbound sucesso
  - `15`: retorno/piper sucesso
  - `16`: retorno/piper sucesso (teste manual)
- Fila Piper recebendo eventos:
  - arquivo `/root/piper_queue.jsonl` com `request_id` recentes.

## Evidencias principais

- `02_assistente_voz/testes/2026-02-23_validacao_cadeia_voz.md`
- `02_assistente_voz/logs/voice_chain_2026-02-23_152136.log`
- `02_assistente_voz/logs/check_voice-e2e-2026-02-23_152136.json`
- `01_infra_backbone/evidencias/2026-02-23_validacao_acesso_n8n.md`
- `01_infra_backbone/evidencias/2026-02-23_openclaw_gateway_rpc_timeout.md`
- `03_automacao_vps1/docs/2026-02-23_implantacao_fluxo_voz.md`

## Arquivos locais novos/alterados na sessao

- `README.md`
- `02_assistente_voz/README.md`
- `02_assistente_voz/integracao_n8n/payload_faster_whisper_exemplo.json`
- `02_assistente_voz/testes/validate_voice_chain.sh`
- `02_assistente_voz/testes/2026-02-23_validacao_cadeia_voz.md`
- `02_assistente_voz/stt/notebook_local/assistente_voz/escuta.py`
- `03_automacao_vps1/README.md`
- `03_automacao_vps1/assistente_edge/README.md`
- `03_automacao_vps1/assistente_edge/bot.py`
- `03_automacao_vps1/assistente_edge/piper_bridge.py`
- `03_automacao_vps1/n8n/workflows/wf_voice_inbound_openclaw.json`
- `03_automacao_vps1/n8n/workflows/wf_voice_return_piper.json`
- `03_automacao_vps1/docs/2026-02-23_implantacao_fluxo_voz.md`
- `01_infra_backbone/evidencias/2026-02-23_validacao_acesso_n8n.md`
- `01_infra_backbone/evidencias/2026-02-23_openclaw_gateway_rpc_timeout.md`

## Pendencias para retomada

1. Fechar audio real no notebook:
   - Piper esta em modo fila no VPS 1.
   - Falta worker/endpoint no notebook para consumir e reproduzir.
2. Ajustar monitoramento do backbone:
   - `validate_backbone.sh` acusou `FAIL` de `tailscale ping` no `vps-prod` (fora do fluxo de voz imediato).
3. Tratar timeout RPC do gateway Openclaw:
   - `openclaw health` no gateway WS ainda em timeout.
   - Fluxo atual funciona porque usa `openclaw agent --local`.

## Como retomar rapido

1. Revalidar cadeia atual (sem mexer em nada):
   - `bash 02_assistente_voz/testes/validate_voice_chain.sh`
2. Se quiser ignorar backbone global e validar so voz:
   - `RUN_BACKBONE_CHECK=0 bash 02_assistente_voz/testes/validate_voice_chain.sh`
3. Testar captura real do notebook (faster-whisper):
   - `export N8N_VERIFY_TLS=0`
   - `python3 02_assistente_voz/stt/notebook_local/assistente_voz/escuta.py --loop`

## Observacoes operacionais

- O certificado HTTPS atual do n8n e self-signed (por isso `N8N_VERIFY_TLS=0` no notebook).
- A senha de acesso do n8n foi resetada durante a sessao e o acesso foi confirmado; manter rotacao de senha ao retomar.
