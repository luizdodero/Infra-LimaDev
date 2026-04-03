# Plano de Acao - Pos Ocorrencia VPS-DEV

Data: 2026-03-30
Origem: vps-dev/Ocorrencia_diag.md
Responsavel: Operacoes / DevOps

## 1) Avaliacao Tecnica

A ocorrencia confirma um incidente composto por:
- degradacao severa de desempenho por pressao de memoria (RAM limitada + swap em 93% + evento OOM);
- indisponibilidade intermitente de SSH por latencia de resposta em momentos de swap alto;
- superficie de ataque maior que o necessario (falta de hardening inicial em SSH/firewall/banimento);
- risco de recorrencia enquanto nao houver contenção do consumo de memoria no processo Node.js e/ou upgrade de RAM.

Conclusao operacional:
- mitigacao emergencial foi efetiva (SSH + UFW + Fail2ban),
- causa estrutural de capacidade ainda permanece (memoria),
- risco residual: medio ate a acao de capacidade e ajuste de aplicacao.

## 2) Providencias Imediatas (Hoje)

1. Aplicar hardening automatizado via Ansible no host afetado:
   - `cd vps-assist-ansible-setup`
   - `./run-playbook.sh security`

2. Validar protecoes no host:
   - `sudo ufw status verbose`
   - `sudo fail2ban-client status sshd`
   - `sudo sshd -T | egrep 'clientaliveinterval|clientalivecountmax|x11forwarding'`

3. Congelar exposicao de portas internas:
   - manter publicacao externa apenas em 22022/tcp, 80/tcp e 443/tcp;
   - bloquear qualquer porta de servico interno sem justificativa documentada.

## 3) Providencias de Curto Prazo (Esta Semana)

1. Capacidade:
   - aprovar upgrade de RAM para 8 GB (minimo) / 16 GB (recomendado);
   - confirmar reducao sustentada de swap para abaixo de 30% em carga normal.

2. Aplicacao Node.js:
   - mapear processo e aplicacao responsavel por pico de memoria;
   - instrumentar limite e restart controlado (ex.: policy de supervisor/process manager);
   - registrar perfil de uso de memoria por janela de 24h.

3. Observabilidade minima:
   - publicar baseline diario (RAM, swap, load, falhas ssh, bans fail2ban).

4. SSL publico com Let's Encrypt:
   - criar DNS A records para `infra.reforce.pro.br` e `onb-mkt.reforce.pro.br` apontando para `129.121.36.133`;
   - instalar emissor de certificados: `sudo apt install -y certbot python3-certbot-nginx`;
   - emitir certificados: `sudo certbot --nginx -d infra.reforce.pro.br -d onb-mkt.reforce.pro.br`;
   - validar renovacao automatica: `sudo certbot renew --dry-run`.

## 4) Criterios de Saida

A ocorrencia sera considerada encerrada quando:
- swap permanecer abaixo de 40% por 7 dias consecutivos;
- nenhum novo evento OOM no periodo;
- SSH estavel sem timeout em testes operacionais;
- portas internas mantidas fechadas por politica e comprovadas por varredura;
- certificados SSL publicos ativos e validos para os subdominios definidos.

## 5) Evidencias a anexar

- output do stage de hardening (Ansible);
- snapshot de `ufw status numbered`;
- snapshot de `fail2ban-client status sshd`;
- resumo de `journalctl -k | grep -i -E 'out of memory|oom'` (ultima semana);
- comparativo de uso de swap antes/depois;
- output de `sudo certbot renew --dry-run` sem erros;
- output de `nginx -t` com status OK apos configuracao dos vhosts.
