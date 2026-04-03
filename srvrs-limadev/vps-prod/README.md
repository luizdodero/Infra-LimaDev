# 04_producao_vps2

## Objetivo
Manter ambiente estavel para projetos maduros e separar uma camada de infra compartilhada do servidor.

## Pastas

- `projetos/voxgate`: deploy e artefatos do VoxGate.
- `projetos/picfound`: deploy e artefatos do PicFound.
- `deploy`: scripts e pipeline de publicacao.
- `monitoramento`: healthchecks, alertas e metricas.
- `infra_compartilhada`: componentes comuns do servidor (nginx, TLS, firewall, observabilidade).

## Checklist inicial

- [ ] Definir convencao de deploy por projeto.
- [ ] Padronizar healthcheck e logs por servico.
- [ ] Consolidar configuracao compartilhada em `infra_compartilhada/`.
- [ ] Garantir isolamento entre runtime de projeto e camada de infra base.
