# Correcao acesso Openclaw (gateway) - 2026-02-24

## Sintoma
- TCP aberto via tailnet, mas HTTP/WS em `18789` sem resposta.
- Conexao local a `127.0.0.1:18789` em timeout.

## Diagnostico
Regra `iptables` dropava a porta `18789` para tudo que nao fosse `100.0.0.0/8`, inclusive loopback. O `tailscale serve` encaminha para `127.0.0.1:18789`, entao o drop bloqueava o proxy local.

## Ajuste aplicado
Liberacao de loopback para porta 18789:

```bash
iptables -I INPUT 2 -i lo -p tcp --dport 18789 -j ACCEPT
```

## Validacao
Local (VPS):
```bash
nc -vz -w 3 127.0.0.1 18789
curl -sS --max-time 5 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18789/__openclaw__/canvas/
```
Resultado: `nc` OK, HTTP `200`.

Tailnet (notebook):
```bash
curl -sS --max-time 8 -o /dev/null -w '%{http_code}\n' http://vps-assist.tailed51fe.ts.net:18789/
```
Resultado: HTTP `200`.

## Observacao
Persistencia da regra precisa ser aplicada no baseline de firewall (nao persistido ainda).
