# Validacao de Acesso n8n - 2026-02-23

## Contexto

- Objetivo: confirmar recuperacao de acesso ao `n8n` no VPS assist e registrar evidencias.
- Host: `vps-assist.tailed51fe.ts.net`
- Porta: `443` (HTTPS)
- Usuario validado: `luizdodero@gmail.com`

## Evidencias tecnicas

1. Endpoint HTTPS ativo
- Comando: `curl -k -I https://vps-assist.tailed51fe.ts.net`
- Resultado: `HTTP/1.1 200 OK`

2. Conta n8n atualizada no banco
- Banco: `/var/lib/docker/volumes/n8n-docker_n8n_data/_data/database.sqlite`
- Validacao: hash de senha em formato `bcrypt` (`$2b$10$...`) e `updatedAt` atualizado.

3. Backup do banco antes da alteracao
- Arquivo: `/var/lib/docker/volumes/n8n-docker_n8n_data/_data/database.sqlite.bak_2026-02-23_150418`

4. Webhook funcional
- Endpoint encontrado no banco: `POST /webhook/comando-voz`
- Teste executado em `2026-02-23 15:10 (-03)`:
  - `POST https://vps-assist.tailed51fe.ts.net/webhook/comando-voz`
  - Resposta: `{"message":"Workflow was started"}`
  - HTTP: `200`

5. Execucao no n8n concluida com sucesso
- Workflow ID: `PndQfLZsfDZ7X9YQ`
- Ultima execucao observada: `id=11`, `status=success`, `mode=webhook`
- Janela de execucao: `2026-02-23 18:10:55.022` a `2026-02-23 18:10:55.401` (UTC)

## Observacao

- O fluxo atual do workflow `My workflow` possui 2 nos (`Webhook` e `Execute a command`).
- A etapa de resposta TTS com Piper ainda deve ser adicionada ao workflow para fechar o ciclo completo de voz.
