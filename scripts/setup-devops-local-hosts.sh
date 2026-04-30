#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/setup-devops-local-hosts.sh [options]

Populate /etc/hosts with the local Traefik browser hostnames used by the
DevOps Easy Learning k3s slices.

Options:
  --ip ADDRESS  Override the detected Traefik address
  --print       Print the host entry and exit without changing /etc/hosts
  -h, --help    Show this help message
EOF
}

HOSTS_FILE="/etc/hosts"
TRAEFIK_NAMESPACE="traefik"
TRAEFIK_SERVICE="traefik"
TRAEFIK_ADDR=""
PRINT_ONLY=0
DOMAINS=(
  controlplane.devops.local
  grafana.devops.local
  vault.devops.local
  memflip.devops.local
  opensis.devops.local
  www.swiftpay.devops.local
  swiftpay.devops.local
  api.swiftpay.devops.local
  foodpulse.devops.local
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ip)
      [[ $# -lt 2 ]] && { echo "ERROR: --ip requires an address" >&2; exit 1; }
      TRAEFIK_ADDR="$2"
      shift 2
      ;;
    --print)
      PRINT_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  fi
}

remove_existing_entries() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sudo sed -i '' '/devops\.local/d' "$HOSTS_FILE"
  else
    sudo sed -i '/devops\.local/d' "$HOSTS_FILE"
  fi
}

require_command kubectl

if [[ -z "$TRAEFIK_ADDR" ]]; then
  TRAEFIK_ADDR="$(kubectl get svc -n "$TRAEFIK_NAMESPACE" "$TRAEFIK_SERVICE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
fi

if [[ -z "$TRAEFIK_ADDR" ]]; then
  TRAEFIK_ADDR="$(kubectl get svc -n "$TRAEFIK_NAMESPACE" "$TRAEFIK_SERVICE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
fi

if [[ -z "$TRAEFIK_ADDR" ]]; then
  echo "ERROR: Could not detect a Traefik ingress address from service ${TRAEFIK_NAMESPACE}/${TRAEFIK_SERVICE}." >&2
  echo "Run ./scripts/ensure-k3s-runtime.sh first or pass --ip ADDRESS." >&2
  exit 1
fi

HOST_ENTRY="${TRAEFIK_ADDR} ${DOMAINS[*]}"

if [[ "$PRINT_ONLY" -eq 1 ]]; then
  printf '%s\n' "$HOST_ENTRY"
  exit 0
fi

echo "Traefik address: $TRAEFIK_ADDR"
echo "Updating $HOSTS_FILE with DevOps Easy Learning local hostnames"

remove_existing_entries
printf '%s\n' "$HOST_ENTRY" | sudo tee -a "$HOSTS_FILE" >/dev/null

echo
echo "Current DevOps Easy Learning host entry:"
grep 'devops\.local' "$HOSTS_FILE"
echo
echo "You can now open:"
echo "  http://controlplane.devops.local"
echo "  http://grafana.devops.local"
echo "  http://vault.devops.local"
echo "  http://memflip.devops.local"
echo "  http://opensis.devops.local"
echo "  http://www.swiftpay.devops.local"
echo "  http://foodpulse.devops.local"
