# 02_assistente_voz

## Objetivo
Fechar o ciclo de voz bidirecional com robustez:
STT/TTS no host de execucao local -> n8n (VPS 1) -> resposta do assistente -> retorno sonoro no host de execucao.

Alocacao operacional atual:
- `note-limdev`: interface de trabalho, observabilidade e disparo remoto.
- `mini-pc`: destino planejado para STT/TTS e para os testes de desenvolvimento mais pesados da portaria inteligente.

## Pastas

- `stt`: scripts, modelos e ajustes do Faster-Whisper.
- `tts`: engine de sintese (Piper) e pipeline de reproducao.
- `integracao_n8n`: payloads, webhooks e contratos de API.
- `testes`: cenarios funcionais e de carga.
- `logs`: logs de execucao e rastreio de latencia.

## Checklist inicial

- [x] Padronizar contrato JSON enviado ao n8n.
- [x] Definir mecanismo de correlacao por sessao (request_id).
- [ ] Definir voz/modelo do Piper e parametros de qualidade/latencia.
- [ ] Medir latencia ponta-a-ponta em cenarios curtos e longos.
- [ ] Tratar falhas de contexto e repeticao de comandos.
- [ ] Documentar fluxo de erro e retentativa.

## Validacao atual da cadeia

- Fluxo validado em `2026-02-23`: `faster-whisper -> n8n -> openclaw -> n8n -> piper (fila)`.
- Script de validacao: `02_assistente_voz/testes/validate_voice_chain.sh`.
- Evidencia: `02_assistente_voz/testes/2026-02-23_validacao_cadeia_voz.md`.
- Payload de referencia: `02_assistente_voz/integracao_n8n/payload_faster_whisper_exemplo.json`.

## Validacao com audio local

- Fluxo validado em `2026-02-23`: `faster-whisper -> n8n -> openclaw -> n8n -> piper (audio local)`.
- Evidencia: `02_assistente_voz/testes/2026-02-23_validacao_audio_ponta_a_ponta.md`.

## Execucao rapida

`bash 02_assistente_voz/testes/validate_voice_chain.sh`

Opcional (nao bloquear por backbone):
`RUN_BACKBONE_CHECK=0 bash 02_assistente_voz/testes/validate_voice_chain.sh`

## Execucao com Faster-Whisper real (notebook)

As URLs abaixo refletem a ultima validacao concluida no `note-limdev`. Durante a migracao para o `mini-pc`, manter a documentacao de endpoints sincronizada assim que os servicos equivalentes forem publicados.

Referencia operacional do notebook:
- `02_assistente_voz/stt/notebook_local/README.md`

No script `02_assistente_voz/stt/notebook_local/assistente_voz/escuta.py`, o webhook padrao ja aponta para:
`https://vps-assist.tailed51fe.ts.net/webhook/comando-voz`

Variaveis recomendadas:
- `export N8N_VERIFY_TLS=0` (certificado self-signed atual no VPS 1)
- `export STT_LANGUAGE=pt`

## Interface grafica (liga/desliga conversa)

UI simples em navegador com botao para ativar/desativar a captura continua:

`~/.local/bin/limadev-conversa-ui`

Comportamento:
- `Ativar conversa`: sobe Piper (se necessario) e inicia `escuta.py --loop`.
- `Desativar conversa`: encerra captura e para o Piper iniciado pela propria UI.
- Log de runtime: `02_assistente_voz/stt/notebook_local/assistente_voz/conversa_runtime.log`

Endpoint da interface:
- `http://127.0.0.1:18900`
- `http://note-limdev.tailed51fe.ts.net:18900` (tailnet)

Destino de migracao:
- publicar interface equivalente no `mini-pc` quando o host assumir a execucao do ciclo de voz.

## Atalho no dock (favoritos)

Atalho local instalado:
- `.desktop`: `~/.local/share/applications/limadev-conversa-ui.desktop`
- launcher: `~/.local/bin/limadev-conversa-ui`

Comando direto (sem abrir terminal):
`~/.local/bin/limadev-conversa-ui`

## Piper local (audio final)

Servidor local para receber o retorno do n8n e reproduzir audio:

1. Instalar e baixar voz:
   `02_assistente_voz/tts/piper/README.md`
2. Subir servidor:
   `02_assistente_voz/tts/piper/scripts/run_piper_server.sh`

O endpoint fica em `http://<notebook>:18888/tts`.
Na nova topologia, substituir `<notebook>` pelo host executor do ciclo de voz (`mini-pc` quando a migracao estiver concluida).
