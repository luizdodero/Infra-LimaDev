# assistente_edge

Arquivos do assistente IA executado no VPS 1.

## Conteudo esperado

- codigo-fonte do runtime do assistente
- configuracoes por ambiente
- adaptadores de entrada (STT/webhook) e saida (resposta para TTS com Piper)
- scripts de inicializacao e healthcheck

## Scripts implementados

- `bot.py`: recebe texto via argumento (n8n), chama `openclaw agent --local --json` e publica retorno no webhook `/webhook/resposta-openclaw`.
- `piper_bridge.py`: recebe resposta do assistente via n8n e registra em fila (`/root/piper_queue.jsonl`) para consumo pelo Piper no notebook.
