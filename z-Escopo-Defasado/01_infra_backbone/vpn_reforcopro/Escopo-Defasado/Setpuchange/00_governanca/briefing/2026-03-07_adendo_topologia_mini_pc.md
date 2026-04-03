# Adendo de topologia - mini-pc - 2026-03-07

Este adendo atualiza o memorial original que descrevia um ecossistema de 4 nos.

## Nova composicao local

- `note-limdev`: interface humana, navegador, VS Code Remote e operacao manual.
- `mini-pc`: novo host para testes de desenvolvimento e cargas locais mais pesadas da solucao de portaria inteligente.

## Novo total de nos

O ecossistema passa a operar com 5 nos:

1. `note-limdev`
2. `mini-pc`
3. `vps-assist`
4. `vps-prod`
5. `vps-dev`

## Diretriz operacional

- O `note-limdev` deixa de ser o host preferencial para execucao dos testes mais intensivos.
- O `mini-pc` entra na tailnet com MagicDNS `mini-pc.tailed51fe.ts.net`, IPv4 `100.87.104.42` e IPv6 `fd7a:115c:a1e0::5d3b:682a`.
- O bootstrap inicial do `mini-pc` sera feito com senha no usuario `limadev`, seguido da instalacao de chave SSH dedicada.
