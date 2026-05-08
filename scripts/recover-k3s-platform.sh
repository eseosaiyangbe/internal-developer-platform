#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/recover-k3s-platform.sh [options]

Recover the local k3s platform after a raw runtime restart. This script is a
broader post-runtime reconcile than Vault recovery alone: it ensures Traefik is
healthy, reuses the host-side Vault recovery path, and nudges core platform pods
that are stuck after a Colima restart.

Options:
  --quiet                 Minimize log output
  --timeout <seconds>     Wait timeout for platform recovery
  -h, --help              Show this help message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-identity.sh"

QUIET=0
TIMEOUT_SECONDS=300
TARGET_NAMESPACES=(
  kube-system
  traefik
  cert-manager
  external-secrets
  cnpg-system
  platform-observability-dev
)

log() {
  if [[ "${QUIET}" -eq 0 ]]; then
    echo "[platform-recovery] $*"
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)
      QUIET=1
      shift
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
      if [[ -z "${TIMEOUT_SECONDS}" ]]; then
        echo "ERROR: --timeout requires a value." >&2
        exit 1
      fi
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

require_command kubectl
require_command helm
require_command jq

if [[ "${OSTYPE:-}" == darwin* ]] && command -v colima >/dev/null 2>&1; then
  if ! colima status >/dev/null 2>&1; then
    log "Colima is not running; skipping platform recovery."
    exit 0
  fi
fi

if ! kubectl get nodes >/dev/null 2>&1; then
  log "Kubernetes API is not ready yet; skipping this recovery interval."
  exit 0
fi

if ! kubectl get namespace traefik >/dev/null 2>&1; then
  log "Traefik namespace is not present; skipping platform recovery."
  exit 0
fi

traefik_ready() {
  kubectl -n traefik get deployment traefik -o json 2>/dev/null \
    | jq -e '(.status.availableReplicas // 0) >= 1' >/dev/null 2>&1
}

portfolio_origin_healthy() {
  curl -fsSI -H 'Host: portfolio.eseosadevbox.com' http://192.168.64.2 >/dev/null 2>&1
}

count_unhealthy_target_pods() {
  local namespaces_json
  namespaces_json="$(printf '%s\n' "${TARGET_NAMESPACES[@]}" | jq -R . | jq -s .)"
  kubectl get pods -A -o json | jq --argjson target "${namespaces_json}" '
    [.items[]
     | select(.metadata.namespace as $ns | $target | index($ns))
     | select(
         (.status.phase != "Running" and .status.phase != "Succeeded")
         or
         ((.status.containerStatuses // []) | any(
           (.ready == false) and (
             (.state.waiting.reason // "") == "CrashLoopBackOff"
             or (.state.waiting.reason // "") == "CreateContainerConfigError"
             or (.state.waiting.reason // "") == "ErrImagePull"
             or (.state.waiting.reason // "") == "ImagePullBackOff"
           )
         ))
       )] | length'
}

delete_stuck_target_pods() {
  local namespaces_json
  namespaces_json="$(printf '%s\n' "${TARGET_NAMESPACES[@]}" | jq -R . | jq -s .)"
  while read -r namespace pod; do
    [[ -n "${namespace}" && -n "${pod}" ]] || continue
    kubectl -n "${namespace}" delete pod "${pod}" --wait=false >/dev/null 2>&1 || true
  done < <(
    kubectl get pods -A -o json | jq -r --argjson target "${namespaces_json}" '
      .items[]
      | select(.metadata.namespace as $ns | $target | index($ns))
      | select(.metadata.ownerReferences | length > 0)
      | select(
          (.status.phase == "Failed")
          or
          ((.status.containerStatuses // []) | any(
            (.ready == false) and (
              (.state.waiting.reason // "") == "CrashLoopBackOff"
              or (.state.waiting.reason // "") == "CreateContainerConfigError"
              or (.state.waiting.reason // "") == "ErrImagePull"
              or (.state.waiting.reason // "") == "ImagePullBackOff"
            )
          ))
        )
      | [.metadata.namespace, .metadata.name] | @tsv'
  )
}

ensure_traefik_with_helm() {
  helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
  helm upgrade --install traefik traefik/traefik \
    --namespace traefik \
    --create-namespace \
    --set service.type=LoadBalancer \
    --set ingressClass.enabled=true \
    --set ingressClass.isDefaultClass=true >/dev/null
  kubectl rollout status deployment/traefik -n traefik --timeout=180s >/dev/null
}

vault_and_platform_healthy() {
  local unhealthy_pods
  unhealthy_pods="$(count_unhealthy_target_pods)"
  traefik_ready && "${SCRIPT_DIR}/recover-k3s-vault.sh" --quiet --timeout 180 >/dev/null 2>&1 && [[ "${unhealthy_pods}" -eq 0 ]] && portfolio_origin_healthy
}

if vault_and_platform_healthy; then
  log "Local k3s platform is already healthy."
  exit 0
fi

log "Reconciling Traefik and core platform namespaces after runtime restart..."
ensure_traefik_with_helm
"${SCRIPT_DIR}/recover-k3s-vault.sh" --quiet --timeout 180 >/dev/null
delete_stuck_target_pods

deadline=$((SECONDS + TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  if vault_and_platform_healthy; then
    log "Local k3s platform recovery completed successfully."
    exit 0
  fi
  sleep 5
done

echo "ERROR: Local k3s platform recovery timed out after ${TIMEOUT_SECONDS}s." >&2
echo "Traefik ready: $(traefik_ready && echo true || echo false)" >&2
echo "Unhealthy target pods: $(count_unhealthy_target_pods)" >&2
echo "Portfolio origin healthy: $(portfolio_origin_healthy && echo true || echo false)" >&2
exit 1
