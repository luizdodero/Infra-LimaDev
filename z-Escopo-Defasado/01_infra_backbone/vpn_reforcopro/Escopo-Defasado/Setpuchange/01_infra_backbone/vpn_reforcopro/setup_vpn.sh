#!/usr/bin/env bash
# ============================================================
# SETUP VPN ReforcePro - note-limdev
# Protocolo : L2TP/IPSec (strongswan + xl2tpd + ppp)
# Guia      : SAAD VPN Client v1.0
# Servidor  : 177.105.240.90 | Usuario: luiz.dodero
#
# USO: sudo bash setup_vpn.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="$SCRIPT_DIR/credenciais.conf"

# --- carrega credenciais ---
if [[ ! -f "$CRED_FILE" ]]; then
  echo "[ERRO] Arquivo credenciais.conf nao encontrado em: $CRED_FILE"
  exit 1
fi
source "$CRED_FILE"

# --- valida campos obrigatorios ---
ERROS=0
[[ "$VPN_PASS" == "SENHA_AQUI" || -z "$VPN_PASS" ]]   && echo "[ERRO] VPN_PASS nao definida em credenciais.conf" && ERROS=1
[[ "$VPN_PSK"  == "PSK_AQUI"   || -z "$VPN_PSK" ]]    && echo "[ERRO] VPN_PSK nao definida em credenciais.conf"  && ERROS=1
[[ $ERROS -eq 1 ]] && exit 1

echo "============================================"
echo " Setup VPN ReforcePro - L2TP/IPSec"
echo " Servidor : $VPN_SERVER"
echo " Usuario  : $VPN_USER"
echo "============================================"

# ---- 1. INSTALAR PACOTES ----
echo "[1/6] Instalando pacotes..."
apt update -qq
apt install -y xl2tpd ppp strongswan
systemctl stop xl2tpd 2>/dev/null || true

# ---- 2. CONFIGURAR IPSEC (/etc/ipsec.conf) ----
echo "[2/6] Configurando IPSec..."
cat > /etc/ipsec.conf << EOF
config setup
    uniqueids=no

conn L2TP-PSK
    keyexchange=ikev1
    authby=secret
    type=transport
    left=%defaultroute
    leftprotoport=17/1701
    right=$VPN_SERVER
    rightprotoport=17/1701
    auto=add
EOF

# ---- 3. CONFIGURAR PSK (/etc/ipsec.secrets) ----
echo "[3/6] Configurando chave PSK..."
cat > /etc/ipsec.secrets << EOF
%any $VPN_SERVER : PSK "$VPN_PSK"
EOF
chmod 600 /etc/ipsec.secrets

# ---- 4. CONFIGURAR XL2TPD (/etc/xl2tpd/xl2tpd.conf) ----
echo "[4/6] Configurando xl2tpd..."
cat > /etc/xl2tpd/xl2tpd.conf << EOF
[lac vpn]
lns = $VPN_SERVER
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
EOF

# ---- 5. CONFIGURAR PPP OPTIONS ----
echo "[5/6] Configurando PPP..."
cat > /etc/ppp/options.l2tpd.client << EOF
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
user "$VPN_USER"
EOF

# credenciais PPP
# remove entrada anterior se existir
sed -i "/^$VPN_USER /d" /etc/ppp/chap-secrets 2>/dev/null || true
echo "$VPN_USER * $VPN_PASS *" >> /etc/ppp/chap-secrets
chmod 600 /etc/ppp/chap-secrets

# ---- 6. REINICIAR SERVICOS ----
echo "[6/6] Iniciando servicos..."
systemctl restart strongswan
systemctl start xl2tpd
systemctl enable xl2tpd 2>/dev/null || true

# ---- INSTALAR SCRIPTS DE ATALHO ----
CONNECT_SCRIPT="$SCRIPT_DIR/conectar_vpn.sh"
cp "$CONNECT_SCRIPT" /usr/local/bin/vpn-reforcopro
chmod +x /usr/local/bin/vpn-reforcopro

echo ""
echo "============================================"
echo " Setup concluido!"
echo ""
echo " Para CONECTAR  : sudo vpn-reforcopro on"
echo " Para DESCONECT.: sudo vpn-reforcopro off"
echo " Ou use o atalho no Desktop"
echo "============================================"
