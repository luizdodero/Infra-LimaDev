# VPN Grupo ReforcePro — note-limdev

Documentação da instalação realizada em `2026-03-16` no host `note-limdev` (Luiz-Vaio).

## Dados da conexão

| Campo            | Valor                        |
|------------------|------------------------------|
| Servidor         | 177.105.240.90               |
| Usuário PPP      | luiz.dodero                  |
| Protocolo        | L2TP (sem IPSec ativo)       |
| IP local (ppp0)  | 172.16.100.39                |
| IP remoto (ppp0) | 172.16.100.40                |
| Guia de referência | SAAD VPN Client v1.0 (13/02/2026) |

---

## Pacotes instalados

```bash
sudo apt install xl2tpd ppp strongswan -y
```

> `strongswan` instalado mas **IPSec não está ativo** — o servidor aceita L2TP
> direto. O serviço correto no Ubuntu 22.04 é `ipsec restart` (não `strongswan.service`).

---

## Arquivos de configuração

### /etc/ipsec.conf
```
config setup
    uniqueids=no

conn L2TP-PSK
    keyexchange=ikev1
    authby=secret
    type=transport
    left=%defaultroute
    leftprotoport=17/1701
    right=177.105.240.90
    rightprotoport=17/1701
    auto=add
```

### /etc/ipsec.secrets
```
%any 177.105.240.90 : PSK "CHAVE_PSK"
```
> PSK não foi fornecido pelo admin — campo preenchido mas IPSec não negociou.
> Conexão estabelecida via L2TP puro mesmo assim.
> Permissão: `chmod 600 /etc/ipsec.secrets`

### /etc/xl2tpd/xl2tpd.conf
```
[lac vpn]
lns = 177.105.240.90
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
```

### /etc/ppp/options.l2tpd.client
```
ipcp-accept-local
ipcp-accept-remote
require-mschap-v2
refuse-eap
noccp
noauth
mtu 1450
mru 1450
persist
maxfail 0
user "luiz.dodero"
```

### /etc/ppp/chap-secrets
```
luiz.dodero * SENHA *
```
> Permissão: `chmod 600 /etc/ppp/chap-secrets`

### /etc/sudoers.d/vpn-reforcopro
```
luiz ALL=(ALL) NOPASSWD: /usr/bin/tee /var/run/xl2tpd/l2tp-control
```
> Permite conectar/desconectar sem digitar senha root.

---

## Aliases no ~/.bashrc

```bash
alias vpn-on='echo c vpn | sudo tee /var/run/xl2tpd/l2tp-control'
alias vpn-off='echo d vpn | sudo tee /var/run/xl2tpd/l2tp-control'
```

Recarregar: `source ~/.bashrc`

---

## Como usar

### Conectar
```bash
vpn-on
```
Ou pelo perfil `VPN ON` no GNOME Terminal (☰ → seta ao lado do +).

### Desconectar
```bash
vpn-off
```
Ou pelo perfil `VPN OFF` no GNOME Terminal.

### Verificar se está ativa
```bash
ip link show ppp0
```
> `UP` = conectada | erro/ausente = desconectada

### Ver IPs atribuídos
```bash
ip addr show ppp0
```

---

## Rota para rede interna

A rota default via ppp0 **não funciona** (bug documentado no guia SAAD).
Usar rota específica:

```bash
sudo ip route add 192.168.0.0/16 dev ppp0
```

> Esta rota é **temporária** — some após reboot ou reconexão.
> Confirmar com admin da ReforcePró os ranges internos reais para ajustar.

---

## Manutenção

### VPN não conecta após reboot
```bash
sudo systemctl start xl2tpd
vpn-on
```

### Verificar logs em tempo real
```bash
sudo journalctl -u xl2tpd -f
```

### Reconfigurar senha (luiz.dodero mudou a senha)
```bash
sudo nano /etc/ppp/chap-secrets
# alterar: luiz.dodero * NOVA_SENHA *
sudo systemctl restart xl2tpd
```

### Adicionar PSK quando fornecido pelo admin
```bash
sudo nano /etc/ipsec.secrets
# alterar: %any 177.105.240.90 : PSK "PSK_REAL"
sudo ipsec restart
```

### Reinstalação completa
```bash
sudo apt install --reinstall xl2tpd ppp strongswan
```
Recriar os arquivos de configuração conforme seção acima.

---

## Perfis GNOME Terminal configurados

| Perfil   | Comando                                                      |
|----------|--------------------------------------------------------------|
| VPN ON   | `bash -c 'echo c vpn \| sudo tee /var/run/xl2tpd/l2tp-control; echo "--- VPN CONECTADA ---"; read'` |
| VPN OFF  | `bash -c 'echo d vpn \| sudo tee /var/run/xl2tpd/l2tp-control; echo "--- VPN DESCONECTADA ---"; read'` |

Acesso: seta (▾) ao lado do botão **+** de nova aba no terminal.

---

## Observações

- IPSec (strongswan) instalado mas não negociou — servidor aceita L2TP sem encriptação IPSec.
- Confirmar com admin ReforcePró se IPSec é obrigatório para acesso a todos os recursos.
- PSK pendente de confirmação com o admin.
- VPN persiste em background após fechar o terminal.
