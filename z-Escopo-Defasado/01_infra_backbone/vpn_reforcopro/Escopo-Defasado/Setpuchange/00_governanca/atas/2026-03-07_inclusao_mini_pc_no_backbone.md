# Inclusao do mini-pc no backbone - 2026-03-07

## Decisao

Adicionar o `mini-pc` como quinto no do ecossistema Tailscale para absorver os testes de desenvolvimento da solucao de portaria inteligente.

## Motivacao

- O `note-limdev` deixou de suportar com folga a carga dos testes mais pesados.
- A estacao principal passa a atuar prioritariamente como interface de trabalho e acesso remoto aos demais equipamentos.

## Impactos operacionais

- `note-limdev` fica focado em VS Code Remote, observabilidade, browser e operacao manual.
- `mini-pc` passa a ser o alvo preferencial para novos testes de desenvolvimento e para a futura migracao do ciclo de voz local.
- O inventario do backbone foi atualizado com o MagicDNS `mini-pc.tailed51fe.ts.net`, IPv4 `100.87.104.42` e IPv6 `fd7a:115c:a1e0::5d3b:682a`.
- O `mini-pc` entrou no inventario inicialmente com `check_ssh=0` e `check_https=0`, e depois foi promovido para `check_ssh=1` apos concluir o bootstrap e a mudanca para `22022`.

## Proximos passos

1. Realizar o primeiro acesso em `limadev@100.87.104.42` com senha.
2. Migrar gradualmente os componentes locais mais pesados do `note-limdev` para o `mini-pc`.
