#!/usr/bin/env bash
# ============================================================
# Controle VPN ReforcePro - L2TP/IPSec
# USO: sudo vpn-reforcopro [on|off|status]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="$SCRIPT_DIR/credenciais.conf"
[[ -f "$CRED_FILE" ]] && source "$CRED_FILE" || true

# fallback se chamado via /usr/local/bin
VPN_SERVER="${VPN_SERVER:-177.105.240.90}"
VPN_INTERNAL_NET="${VPN_INTERNAL_NET:-192.168.0.0/24}"
VPN_GATEWAY="${VPN_GATEWAY:-192.168.8.1}"

ACAO="${1:-on}"

conectar() {
  echo "[VPN] Iniciando IPSec..."
  ipsec up L2TP-PSK 2>/dev/null || true
  sleep 2
  echo "[VPN] Conectando L2TP..."
  echo "c vpn" | tee /var/run/xl2tpd/l2tp-control
  sleep 3
  # adiciona rota para rede interna (workaround bug rota default)
  echo "[VPN] Adicionando rota interna: $VPN_INTERNAL_NET via $VPN_GATEWAY dev ppp0"
  ip route add "$VPN_INTERNAL_NET" via "$VPN_GATEWAY" dev ppp0 2>/dev/null || true
  echo "[OK] VPN ReforcePro conectada."
}

desconectar() {
  echo "[VPN] Desconectando L2TP..."
  echo "d vpn" | tee /var/run/xl2tpd/l2tp-control 2>/dev/null || true
  sleep 1
  echo "[VPN] Parando IPSec..."
  ipsec down L2TP-PSK 2>/dev/null || true
  # remove rota
  ip route del "$VPN_INTERNAL_NET" dev ppp0 2>/dev/null || true
  echo "[OK] VPN ReforcePro desconectada."
}

status() {
  echo "=== IPSec ==="
  ipsec status 2>/dev/null | grep -E "L2TP|ESTABLISHED|no match" || echo "ipsec nao ativo"
  echo "=== Interface ppp0 ==="
  ip addr show ppp0 2>/dev/null || echo "ppp0: nao existe (VPN desligada)"
  echo "=== Rota interna ==="
  ip route show "$VPN_INTERNAL_NET" 2>/dev/null || echo "sem rota para $VPN_INTERNAL_NET"
}

case "$ACAO" in
  on|conectar)   conectar   ;;
  off|desconectar) desconectar ;;
  status)        status     ;;
  *)
    echo "Uso: sudo vpn-reforcopro [on|off|status]"
    exit 1 ;;
esac
