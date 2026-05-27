#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/platform-protected-surface-status.sh [options]

Print a concise status snapshot for the current protected operator surfaces.

Options:
  --quiet       Print only machine-readable status lines
  -h, --help    Show this help message

Current checks:
  - ArgoCD server service exposure
  - ArgoCD root and child application sync posture
  - Vault pod readiness and sealed status
  - SecretStore and ExternalSecret readiness summary
  - Traefik deployment readiness
EOF
}

QUIET=0

log() {
  if [[ "${QUIET}" -eq 0 ]]; then
    printf '[idp-surface-status] %s\n' "$*"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)
      QUIET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd kubectl
require_cmd jq

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"

argocd_service_type="$(kubectl get svc argocd-server -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.spec.type}' 2>/dev/null || true)"
argocd_service_ports="$(kubectl get svc argocd-server -n "${ARGOCD_NAMESPACE}" -o jsonpath='{range .spec.ports[*]}{.port}{"/"}{.protocol}{" "}{end}' 2>/dev/null || true)"

if [[ -n "${argocd_service_type}" ]]; then
  printf 'argocd|service_type=%s|ports=%s\n' "${argocd_service_type}" "${argocd_service_ports:-unknown}"
else
  printf 'argocd|service_type=missing|ports=missing\n'
fi

kubectl get application \
  internal-developer-platform-dev-root \
  observability-dev \
  swiftpay-dev \
  foodpulse-dev \
  memflip-dev \
  opensis-dev \
  -n "${ARGOCD_NAMESPACE}" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|sync="}{.status.sync.status}{"|health="}{.status.health.status}{"|automated="}{.spec.syncPolicy.automated.prune}{","}{.spec.syncPolicy.automated.selfHeal}{"\n"}{end}' 2>/dev/null || true

vault_pod_phase="$(kubectl get pod vault-0 -n "${VAULT_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
vault_ready="$(kubectl get pod vault-0 -n "${VAULT_NAMESPACE}" -o jsonpath='{range .status.conditions[*]}{.type}={.status}{";"}{end}' 2>/dev/null || true)"
vault_sealed="$(kubectl exec -n "${VAULT_NAMESPACE}" vault-0 -- sh -lc 'vault status' 2>/dev/null | awk '/^Sealed[[:space:]]/ {print $2}' || printf 'unknown')"
if kubectl get pod vault-0 -n "${VAULT_NAMESPACE}" >/dev/null 2>&1; then
  :
else
  vault_sealed="missing"
fi
printf 'vault|phase=%s|sealed=%s|conditions=%s\n' "${vault_pod_phase:-missing}" "${vault_sealed}" "${vault_ready:-missing}"

secretstores_not_ready="$(kubectl get secretstore -A -o json 2>/dev/null | jq '[.items[] | select(((.status.conditions // []) | map(select(.type == "Ready" and .status == "True")) | length) == 0)] | length' 2>/dev/null || printf 'unknown')"
externalsecrets_not_ready="$(kubectl get externalsecret -A -o json 2>/dev/null | jq '[.items[] | select(((.status.conditions // []) | map(select(.type == "Ready" and .status == "True")) | length) == 0)] | length' 2>/dev/null || printf 'unknown')"
printf 'external-secrets|secretstores_not_ready=%s|externalsecrets_not_ready=%s\n' "${secretstores_not_ready}" "${externalsecrets_not_ready}"

traefik_available="$(kubectl get deployment traefik -n traefik -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)"
traefik_ready="$(kubectl get deployment traefik -n traefik -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
printf 'traefik|available=%s|ready=%s\n' "${traefik_available:-0}" "${traefik_ready:-0}"
