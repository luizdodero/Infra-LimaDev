#!/usr/bin/env bash

set -uo pipefail

SSH_PORT="${SSH_PORT:-22022}"
HTTPS_PORT="${HTTPS_PORT:-443}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-5}"
ASSISTANT_EDGE_PORT="${ASSISTANT_EDGE_PORT:-18789}"
ASSISTANT_EDGE_HOST="${ASSISTANT_EDGE_HOST:-}"
ASSISTANT_EDGE_PATH="${ASSISTANT_EDGE_PATH:-/health}"
ASSISTANT_EDGE_URL="${ASSISTANT_EDGE_URL:-}"
ASSISTANT_EDGE_AUTH_HEADER="${ASSISTANT_EDGE_AUTH_HEADER:-}"
ASSISTANT_EDGE_CHECK_MODE="${ASSISTANT_EDGE_CHECK_MODE:-http}"
HOSTS_FILE_DEFAULT="01_infra_backbone/checklists/hosts.csv"

usage() {
  cat <<'EOF'
Uso:
  bash 99_shared/scripts/validate_backbone.sh [hosts.csv]

Formatos aceitos para hosts.csv:
  nome,host,check_ssh,check_https
  nome;host;check_ssh;check_https
  nome;host;ipv4;ipv6;

Observacao:
  quando as colunas 3/4 nao forem 0/1, o script assume check_ssh=1 e check_https=1.
  se ASSISTANT_EDGE_URL/ASSISTANT_EDGE_HOST nao forem informados, a checagem do edge fica SKIP.

Variaveis opcionais:
  SSH_PORT=22022
  HTTPS_PORT=443
  TIMEOUT_SECONDS=5
  ASSISTANT_EDGE_PORT=18789
  ASSISTANT_EDGE_HOST="vps1-assist.tailnet"
  ASSISTANT_EDGE_PATH="/health"
  ASSISTANT_EDGE_URL="https://host:18789/health"
  ASSISTANT_EDGE_CHECK_MODE="http"  # http | tcp
  ASSISTANT_EDGE_AUTH_HEADER="Authorization: Bearer <token>"
EOF
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf "%s" "$s"
}

is_binary_flag() {
  [[ "$1" == "0" || "$1" == "1" ]]
}

check_tcp_port() {
  local host="$1"
  local port="$2"

  if command_exists nc; then
    nc -z -w "$TIMEOUT_SECONDS" "$host" "$port" >/dev/null 2>&1
    return $?
  fi

  if command_exists timeout; then
    timeout "$TIMEOUT_SECONDS" bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" >/dev/null 2>&1
    return $?
  fi

  bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" >/dev/null 2>&1
}

check_https() {
  local host="$1"
  local url="https://${host}:${HTTPS_PORT}/"

  if command_exists curl; then
    local code
    code="$(curl -k -sS --connect-timeout "$TIMEOUT_SECONDS" --max-time "$TIMEOUT_SECONDS" -o /dev/null -w "%{http_code}" "$url" || true)"
    [[ -n "$code" && "$code" != "000" ]]
    return $?
  fi

  check_tcp_port "$host" "$HTTPS_PORT"
}

check_tailscale_ping() {
  local host="$1"
  if ! command_exists tailscale; then
    return 2
  fi
  tailscale ping -c 1 "$host" >/dev/null 2>&1
}

extract_host_from_url() {
  local url="$1"
  echo "$url" | sed -E 's#^[a-zA-Z]+://([^/:]+).*$#\1#'
}

extract_port_from_url() {
  local url="$1"
  local port
  port="$(echo "$url" | sed -nE 's#^[a-zA-Z]+://[^/:]+:([0-9]+).*$#\1#p')"
  if [[ -z "$port" ]]; then
    port="$ASSISTANT_EDGE_PORT"
  fi
  echo "$port"
}

check_assistant_edge() {
  local mode
  mode="$(echo "$ASSISTANT_EDGE_CHECK_MODE" | tr '[:upper:]' '[:lower:]')"
  if [[ "$mode" != "http" && "$mode" != "tcp" ]]; then
    echo "FAIL (modo invalido: $ASSISTANT_EDGE_CHECK_MODE)"
    return 1
  fi

  if [[ "$mode" == "tcp" ]]; then
    local edge_host edge_port
    if [[ -n "$ASSISTANT_EDGE_URL" ]]; then
      edge_host="$(extract_host_from_url "$ASSISTANT_EDGE_URL")"
      edge_port="$(extract_port_from_url "$ASSISTANT_EDGE_URL")"
    else
      edge_host="$ASSISTANT_EDGE_HOST"
      edge_port="$ASSISTANT_EDGE_PORT"
    fi

    if [[ -z "$edge_host" ]]; then
      echo "SKIP"
      return 2
    fi

    if check_tcp_port "$edge_host" "$edge_port"; then
      echo "OK (tcp ${edge_host}:${edge_port})"
      return 0
    fi
    echo "FAIL (tcp ${edge_host}:${edge_port})"
    return 1
  fi

  if [[ -z "$ASSISTANT_EDGE_URL" && -n "$ASSISTANT_EDGE_HOST" ]]; then
    ASSISTANT_EDGE_URL="https://${ASSISTANT_EDGE_HOST}:${ASSISTANT_EDGE_PORT}${ASSISTANT_EDGE_PATH}"
  fi

  if [[ -z "$ASSISTANT_EDGE_URL" ]]; then
    echo "SKIP"
    return 2
  fi

  if ! command_exists curl; then
    local edge_host edge_port
    edge_host="$(extract_host_from_url "$ASSISTANT_EDGE_URL")"
    edge_port="$(extract_port_from_url "$ASSISTANT_EDGE_URL")"
    if check_tcp_port "$edge_host" "$edge_port"; then
      echo "OK"
      return 0
    fi
    echo "FAIL"
    return 1
  fi

  local curl_args=(
    -k
    -sS
    --connect-timeout "$TIMEOUT_SECONDS"
    --max-time "$TIMEOUT_SECONDS"
    -o /dev/null
    -w "%{http_code}"
  )

  if [[ -n "$ASSISTANT_EDGE_AUTH_HEADER" ]]; then
    curl_args+=(-H "$ASSISTANT_EDGE_AUTH_HEADER")
  fi

  local code
  code="$(curl "${curl_args[@]}" "$ASSISTANT_EDGE_URL" || true)"
  if [[ -n "$code" && "$code" != "000" ]]; then
    echo "OK (${code})"
    return 0
  fi

  echo "FAIL (${code:-000})"
  return 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

HOSTS_FILE="${1:-$HOSTS_FILE_DEFAULT}"

if [[ ! -f "$HOSTS_FILE" ]]; then
  echo "Arquivo de hosts nao encontrado: $HOSTS_FILE"
  echo "Crie a partir de: 01_infra_backbone/checklists/hosts.example.csv"
  exit 1
fi

echo "=== Validacao de Backbone ==="
echo "Hosts file: $HOSTS_FILE"
echo "SSH port: $SSH_PORT | HTTPS port: $HTTPS_PORT | Timeout: ${TIMEOUT_SECONDS}s"
echo "Assistente edge port padrao (Openclaw): $ASSISTANT_EDGE_PORT"
echo "Assistente edge check mode: $ASSISTANT_EDGE_CHECK_MODE"
echo

printf "%-18s %-36s %-12s %-10s %-10s\n" "NOME" "HOST" "TAILSCALE" "SSH" "HTTPS"
printf "%-18s %-36s %-12s %-10s %-10s\n" "------------------" "------------------------------------" "------------" "----------" "----------"

total_hosts=0
fail_count=0

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  raw_line="${raw_line//$'\r'/}"
  raw_line="$(trim "$raw_line")"

  [[ -z "$raw_line" ]] && continue
  [[ "${raw_line:0:1}" == "#" ]] && continue

  # Aceita tanto CSV com virgula quanto formato com ponto e virgula.
  # Ex.: nome,host,1,1  ou  nome;host;ipv4;ipv6;
  line_normalized="${raw_line//;/,}"

  IFS=',' read -r f1 f2 f3 f4 _extra <<< "$line_normalized"

  name="$(trim "${f1:-}")"
  host="$(trim "${f2:-}")"
  v3="$(trim "${f3:-}")"
  v4="$(trim "${f4:-}")"

  [[ -z "$name" ]] && continue
  [[ -z "$host" ]] && host="$name"

  # Se colunas 3 e 4 forem flags binarias, usa-as.
  # Caso contrario (ex.: ipv4/ipv6), assume checks habilitados.
  check_ssh="1"
  check_https_flag="1"
  if is_binary_flag "$v3" && is_binary_flag "$v4"; then
    check_ssh="$v3"
    check_https_flag="$v4"
  fi

  ((total_hosts++))

  tailscale_status="N/A"
  if check_tailscale_ping "$host"; then
    tailscale_status="OK"
  else
    rc=$?
    if [[ $rc -eq 2 ]]; then
      tailscale_status="N/A"
    else
      tailscale_status="FAIL"
      ((fail_count++))
    fi
  fi

  ssh_status="-"
  if [[ "$check_ssh" == "1" ]]; then
    if check_tcp_port "$host" "$SSH_PORT"; then
      ssh_status="OK"
    else
      ssh_status="FAIL"
      ((fail_count++))
    fi
  fi

  https_status="-"
  if [[ "$check_https_flag" == "1" ]]; then
    if check_https "$host"; then
      https_status="OK"
    else
      https_status="FAIL"
      ((fail_count++))
    fi
  fi

  printf "%-18s %-36s %-12s %-10s %-10s\n" "$name" "$host" "$tailscale_status" "$ssh_status" "$https_status"
done < "$HOSTS_FILE"

echo
assistant_status="$(check_assistant_edge)"
assistant_rc=$?
echo "Assistente edge: $assistant_status"
if [[ $assistant_rc -eq 1 ]]; then
  ((fail_count++))
fi

echo
echo "Hosts avaliados: $total_hosts"
echo "Falhas: $fail_count"

if [[ $fail_count -gt 0 ]]; then
  echo "Resultado: FAIL"
  exit 2
fi

echo "Resultado: PASS"
exit 0
