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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOSTNAME_OVERRIDE="memflip.devops.local"

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

echo "[memflip-k8s] Verifying frontend and backend health"
curl -fsS -H "Host: ${HOSTNAME_OVERRIDE}" "http://${TRAEFIK_ADDR}/health" >/dev/null
curl -fsS -H "Host: ${HOSTNAME_OVERRIDE}" "http://${TRAEFIK_ADDR}/api/health" >/dev/null

echo "[memflip-k8s] Verifying backend metrics"
kubectl exec -n memflip-dev deploy/memflip-backend -- sh -lc 'wget -qO- http://127.0.0.1:3001/metrics | head -n 5' >/dev/null

echo "[memflip-k8s] Verifying PostgreSQL and Redis connectivity"
kubectl exec -n memflip-dev statefulset/memflip-postgres -- sh -lc 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null
kubectl exec -n memflip-dev statefulset/memflip-redis -- sh -lc 'redis-cli -a "$REDIS_PASSWORD" ping | grep -q PONG' >/dev/null

echo "[memflip-k8s] Verification passed"
