# infra_compartilhada

Camada de infraestrutura comum do VPS 2 para servicos compartilhados entre projetos.

## Subpastas

- `nginx`: virtual hosts, reverse proxy, regras e includes.
- `certs_tls`: emissao/renovacao de certificados e cadeia TLS.
- `firewall`: regras base para exposicao publica controlada.
- `observabilidade`: stack de logs, metricas e alertas.

## Regra

Toda configuracao aqui deve ser desacoplada de projeto especifico.
Configuracoes dedicadas de um sistema ficam em `projetos/<nome>/`.
