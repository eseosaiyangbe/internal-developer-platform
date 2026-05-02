#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/k8s-dev-verify.sh [options]

Run the MemFlip Phase 7 dev verification path against the current Kubernetes context.

Options:
  --hostname HOST  Override ingress hostname target (default: memflip.devops.local)
  -h, --help       Show this help message
EOF
}

HOSTNAME_OVERRIDE="memflip.devops.local"
PORT_FORWARD_PID=""

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  fi
}

cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]]; then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
    wait "${PORT_FORWARD_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

require_command kubectl
require_command curl

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hostname)
      HOSTNAME_OVERRIDE="${2:?Missing hostname value}"
      shift 2
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

TRAEFIK_ADDR="$(kubectl get ingress -n memflip-dev memflip -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
if [[ -z "$TRAEFIK_ADDR" ]]; then
  TRAEFIK_ADDR="$(kubectl get ingress -n memflip-dev memflip -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
fi

if [[ -z "$TRAEFIK_ADDR" ]]; then
  echo "ERROR: Could not determine MemFlip ingress address." >&2
  exit 1
fi

echo "[memflip-k8s] Traefik address: $TRAEFIK_ADDR"
echo "[memflip-k8s] Verifying Kubernetes objects"
kubectl get pods -n memflip-dev
kubectl get svc -n memflip-dev
kubectl get ingress -n memflip-dev

echo "[memflip-k8s] Verifying ingress endpoints"
curl -fsS -H "Host: ${HOSTNAME_OVERRIDE}" "http://${TRAEFIK_ADDR}/health" >/dev/null
curl -fsS -H "Host: ${HOSTNAME_OVERRIDE}" "http://${TRAEFIK_ADDR}/api/health" >/dev/null

echo "[memflip-k8s] Running end-to-end backend validation via port-forward"
kubectl port-forward -n memflip-dev svc/memflip-backend 33001:3001 >/tmp/memflip-k8s-port-forward.log 2>&1 &
PORT_FORWARD_PID="$!"
for _ in {1..20}; do
  if curl -fsS http://127.0.0.1:33001/health >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo
echo "MemFlip Validation — environment: dev"
echo "Base URL: http://127.0.0.1:33001"
echo "─────────────────────────────────────────"
echo

curl -fsS http://127.0.0.1:33001/health >/dev/null
curl -fsS http://127.0.0.1:33001/metrics | grep -q '^http_requests_total'

echo "[memflip-k8s] Verifying PostgreSQL and Redis connectivity"
kubectl exec -n memflip-dev statefulset/memflip-postgres -- sh -lc 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null
kubectl exec -n memflip-dev statefulset/memflip-redis -- sh -lc 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping | grep -q PONG' >/dev/null

echo "[memflip-k8s] Verification passed"
