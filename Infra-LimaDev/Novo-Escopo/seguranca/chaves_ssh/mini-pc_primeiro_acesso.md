# Bootstrap SSH do mini-pc

## Contexto

Host adicionado em `2026-03-07` para testes de desenvolvimento mais pesados da solucao de portaria inteligente.

- Usuario inicial: `limadev`
- IPv4 Tailscale: `100.87.104.42`
- MagicDNS: `mini-pc.tailed51fe.ts.net`
- IPv6 Tailscale: `fd7a:115c:a1e0::5d3b:682a`

## Chave dedicada gerada

- Chave privada local: `~/.ssh/id_mini_pc_limalab`
- Chave publica: `~/.ssh/id_mini_pc_limalab.pub`
- Fingerprint: `SHA256:Xp6gaheRDd8fxYp67cmYJqa/rE5owAfn0iXtZSmyfWs`

Conteudo da chave publica a instalar no `mini-pc`:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHc2yO8/Qt1zpw2XMEYdwnW4D3IUXY1UWM5wtOFJxvsW mini-pc-bootstrap-2026-03-07
```

## Primeiro acesso

Se o host ainda aceitar senha no SSH padrao:

```bash
ssh limadev@100.87.104.42
```

Depois de autenticar, instalar a chave manualmente:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHc2yO8/Qt1zpw2XMEYdwnW4D3IUXY1UWM5wtOFJxvsW mini-pc-bootstrap-2026-03-07' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Alternativa automatizada a partir desta maquina:

```bash
ssh-copy-id -i ~/.ssh/id_mini_pc_limalab.pub limadev@100.87.104.42
```

## Validacao apos instalar a chave

```bash
ssh -i ~/.ssh/id_mini_pc_limalab limadev@100.87.104.42
ssh -i ~/.ssh/id_mini_pc_limalab limadev@mini-pc.tailed51fe.ts.net
```

## Estado atual

Bootstrap concluido em `2026-03-07`:

- chave instalada em `~/.ssh/authorized_keys`
- SSH padronizado para a porta `22022`
- porta `22` desativada no host

Acesso atual recomendado:

```bash
ssh -p 22022 -i ~/.ssh/id_mini_pc_limalab limadev@100.87.104.42
```

## Pendencia apos bootstrap

Padronizar o host para usar a mesma politica do backbone:

- atualizar UFW/hardening
- trocar `check_ssh` para `1` no `01_infra_backbone/checklists/hosts.csv`
