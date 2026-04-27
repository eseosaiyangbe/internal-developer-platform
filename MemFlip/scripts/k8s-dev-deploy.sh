#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/k8s-dev-deploy.sh [options]

Build and deploy the MemFlip Phase 7 dev overlay to the current Kubernetes context.

Options:
  --skip-build     Reuse existing local images
  --skip-apply     Only build and validate; do not apply manifests
  --hostname HOST  Override ingress hostname validation target
  -h, --help       Show this help message
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOSTNAME_OVERRIDE="memflip.devops.local"
SKIP_BUILD=0
SKIP_APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --skip-apply)
      SKIP_APPLY=1
      shift
      ;;
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

cd "$ROOT_DIR"

echo "[memflip-k8s] Validating kustomize overlay"
kubectl kustomize k8s/overlays/dev >/dev/null
kubectl apply --dry-run=client -k k8s/overlays/dev >/dev/null

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "[memflip-k8s] Building local images"
  docker build -t memflip-backend:dev backend
  docker build -t memflip-frontend:dev frontend
fi

if [[ "$SKIP_APPLY" -eq 1 ]]; then
  echo "[memflip-k8s] Skipping apply by request"
  exit 0
fi

echo "[memflip-k8s] Applying overlay"
kubectl apply -k k8s/overlays/dev

echo "[memflip-k8s] Waiting for workloads"
kubectl rollout status deployment/memflip-backend -n memflip-dev --timeout=180s
kubectl rollout status deployment/memflip-frontend -n memflip-dev --timeout=180s
kubectl rollout status statefulset/memflip-postgres -n memflip-dev --timeout=180s
kubectl rollout status statefulset/memflip-redis -n memflip-dev --timeout=180s

echo "[memflip-k8s] Verifying live path"
"$ROOT_DIR/scripts/k8s-dev-verify.sh" --hostname "$HOSTNAME_OVERRIDE"
