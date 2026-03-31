#!/usr/bin/env bash

set -u

TARGET_NAME="${TARGET_NAME:-vps-assist}"
TARGET_HOST="${TARGET_HOST:-vps-assist.tailed51fe.ts.net}"
TARGET_IP="${TARGET_IP:-100.65.159.1}"
SSH_PORT="${SSH_PORT:-22022}"
SSH_USER="${SSH_USER:-root}"
SSH_TARGET="${SSH_TARGET:-${SSH_USER}@${TARGET_IP}}"
SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-5}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_UI_PORT="${OPENCLAW_UI_PORT:-18790}"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

section() {
  printf "\n== %s ==\n" "$1"
}

show_cmd() {
  printf "\n$ %s\n" "$*"
  "$@"
}

show_or_note() {
  local label="$1"
  shift

  printf "\n- %s\n" "$label"
  "$@" || true
}

show_port_status() {
  local label="$1"
  local host="$2"
  local port="$3"

  printf "\n- %s\n" "$label"
  if probe_port "$host" "$port" >/dev/null 2>&1; then
    printf "OK (%s:%s)\n" "$host" "$port"
  else
    printf "FAIL (%s:%s)\n" "$host" "$port"
  fi
}

probe_port() {
  local host="$1"
  local port="$2"
  if command_exists nc; then
    nc -z -w "$TIMEOUT_SECONDS" "$host" "$port"
    return $?
  fi

  timeout "$TIMEOUT_SECONDS" bash -c "cat < /dev/null > /dev/tcp/${host}/${port}"
}

probe_https() {
  local path="$1"
  curl -sS -o /dev/null -w '%{http_code}\n' \
    --max-time "$TIMEOUT_SECONDS" \
    --resolve "${TARGET_HOST}:443:${TARGET_IP}" \
    "https://${TARGET_HOST}${path}"
}

run_remote() {
  local ssh_args=(
    -p "$SSH_PORT"
    -o BatchMode=yes
    -o ConnectTimeout="$TIMEOUT_SECONDS"
  )

  if [[ -n "$SSH_IDENTITY_FILE" ]]; then
    ssh_args+=(-i "$SSH_IDENTITY_FILE" -o IdentitiesOnly=yes)
  fi

  ssh \
    "${ssh_args[@]}" \
    "$SSH_TARGET" \
    "$@"
}

section "Alvo"
printf "Nome: %s\n" "$TARGET_NAME"
printf "Host: %s\n" "$TARGET_HOST"
printf "IP tailnet: %s\n" "$TARGET_IP"
printf "SSH: %s (porta %s)\n" "$SSH_TARGET" "$SSH_PORT"
if [[ -n "$SSH_IDENTITY_FILE" ]]; then
  printf "SSH key: %s\n" "$SSH_IDENTITY_FILE"
fi

section "Checagens Externas"
if command_exists getent; then
  show_or_note "Resolucao local do host" bash -lc "getent hosts '$TARGET_HOST' || echo sem-resolucao-local"
fi

if command_exists tailscale; then
  show_or_note "Tailscale ping" tailscale ping -c 1 "$TARGET_IP"
fi

if command_exists nc || command_exists timeout; then
  show_port_status "Porta SSH ${SSH_PORT}" "$TARGET_IP" "$SSH_PORT"
  show_port_status "Porta HTTP 80" "$TARGET_IP" 80
  show_port_status "Porta HTTPS 443" "$TARGET_IP" 443
  show_port_status "Porta Openclaw gateway ${OPENCLAW_GATEWAY_PORT}" "$TARGET_IP" "$OPENCLAW_GATEWAY_PORT"
  show_port_status "Porta Openclaw UI ${OPENCLAW_UI_PORT}" "$TARGET_IP" "$OPENCLAW_UI_PORT"
fi

if command_exists curl; then
  show_or_note "HTTP em :80" curl -sS -I --max-time "$TIMEOUT_SECONDS" "http://${TARGET_IP}/"
  show_or_note "HTTPS em /" probe_https "/"
  show_or_note "HTTPS em /webhook/comando-voz" probe_https "/webhook/comando-voz"
fi

section "Checagens Remotas"
if ! run_remote "printf 'ssh ok\n'" >/dev/null 2>&1; then
  printf "Sem acesso SSH em %s.\n" "$SSH_TARGET"
  printf "Use credencial valida ou ajuste SSH_TARGET/SSH_PORT para continuar a inspecao interna.\n"
  exit 0
fi

run_remote 'bash -s' <<'EOF'
set -u

section() {
  printf "\n== %s ==\n" "$1"
}

note() {
  printf "\n- %s\n" "$1"
}

section "Host"
hostname
date

section "Openclaw"
if command -v openclaw >/dev/null 2>&1; then
  command -v openclaw
  openclaw --version || true
else
  echo "Binario openclaw nao encontrado no PATH."
fi

note "Servicos relacionados"
systemctl --no-pager --type=service --all | grep -Ei "openclaw|n8n|tailscale" || true

note "Processos relacionados"
ps -ef | grep -Ei "openclaw|n8n|tailscaled" | grep -v grep || true

note "Portas 443/18789/18790"
ss -ltnp | grep -E ":443|:18789|:18790" || true

note "Tailscale serve"
tailscale serve status || true

note "Firewall 18789"
iptables -S INPUT | grep 18789 || true
iptables -S OUTPUT | grep 18789 || true

note "Arquivos de configuracao Openclaw"
find /root /etc -maxdepth 4 \( -name 'openclaw.json' -o -name '*openclaw*.json' \) 2>/dev/null || true

for cfg in /root/openclaw.json /root/.config/openclaw/openclaw.json /etc/openclaw/openclaw.json; do
  if [[ -f "$cfg" ]]; then
    echo
    echo "# $cfg"
    grep -nE "gateway\\.|controlUi|allowInsecureAuth|tailscale|bind|remote\\.url" "$cfg" || true
  fi
done

note "Health local do gateway"
curl -sS --max-time 5 -o /dev/null -w 'http://127.0.0.1:18789/ => %{http_code}\n' http://127.0.0.1:18789/ || true
curl -sS --max-time 5 -o /dev/null -w 'http://127.0.0.1:18789/__openclaw__/canvas/ => %{http_code}\n' http://127.0.0.1:18789/__openclaw__/canvas/ || true
EOF
