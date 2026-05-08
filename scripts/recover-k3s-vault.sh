#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/recover-k3s-vault.sh [options]

Recover the local k3s Vault and External Secrets platform after a runtime restart.
This script is intentionally host-side: it keeps unseal material outside Kubernetes
while making local restarts recoverable and repeatable.

Options:
  --quiet                 Minimize log output
  --timeout <seconds>     Wait timeout for SecretStore and ExternalSecret recovery
  -h, --help              Show this help message
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-identity.sh"

VAULT_INIT_FILE="$(idp_resolve_state_file "k3s-vault-init.json")"
BOOTSTRAP_SCRIPT="${SCRIPT_DIR}/bootstrap-k3s-vault-secrets.sh"
QUIET=0
TIMEOUT_SECONDS=180

log() {
  if [[ "${QUIET}" -eq 0 ]]; then
    echo "[vault-recovery] $*"
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
require_command jq
require_command helm

if [[ "${OSTYPE:-}" == darwin* ]] && command -v colima >/dev/null 2>&1; then
  if ! colima status >/dev/null 2>&1; then
    log "Colima is not running; skipping Vault recovery."
    exit 0
  fi
fi

if ! kubectl get namespace vault >/dev/null 2>&1; then
  log "Vault namespace is not present; nothing to recover."
  exit 0
fi

if ! kubectl get pod vault-0 -n vault >/dev/null 2>&1; then
  log "Vault pod vault-0 is not present; nothing to recover."
  exit 0
fi

vault_status_json="$(kubectl exec -n vault vault-0 -- sh -lc 'vault status -format=json || true' 2>/dev/null || true)"
if [[ -z "${vault_status_json}" ]]; then
  echo "ERROR: Unable to retrieve Vault status from vault-0." >&2
  exit 1
fi

vault_sealed="$(printf '%s' "${vault_status_json}" | jq -r '.sealed // "true"')"
secretstore_json="$(kubectl get secretstore -A -o json 2>/dev/null || true)"
externalsecret_json="$(kubectl get externalsecret -A -o json 2>/dev/null || true)"

secretstores_not_ready=0
externalsecrets_not_ready=0

if [[ -n "${secretstore_json}" ]]; then
  secretstores_not_ready="$(printf '%s' "${secretstore_json}" | jq '[.items[] | select(((.status.conditions // []) | map(select(.type == "Ready" and .status == "True")) | length) == 0)] | length')"
fi

if [[ -n "${externalsecret_json}" ]]; then
  externalsecrets_not_ready="$(printf '%s' "${externalsecret_json}" | jq '[.items[] | select(((.status.conditions // []) | map(select(.type == "Ready" and .status == "True")) | length) == 0)] | length')"
fi

if [[ "${vault_sealed}" != "true" && "${secretstores_not_ready}" -eq 0 && "${externalsecrets_not_ready}" -eq 0 ]]; then
  log "Vault and External Secrets are already healthy."
  exit 0
fi

if [[ "${vault_sealed}" == "true" && ! -f "${VAULT_INIT_FILE}" ]]; then
  echo "ERROR: Vault is sealed and ${VAULT_INIT_FILE} is missing." >&2
  echo "Restore the host-side init file before attempting recovery." >&2
  exit 1
fi

log "Reconciling Vault and External Secrets through the host-side recovery path..."
"${BOOTSTRAP_SCRIPT}" --skip-helm >/dev/null

timestamp="$(date +%s)"

while read -r namespace name; do
  [[ -n "${namespace}" && -n "${name}" ]] || continue
  kubectl -n "${namespace}" annotate secretstore "${name}" "force-sync=${timestamp}" --overwrite >/dev/null 2>&1 || true
done < <(kubectl get secretstore -A -o json | jq -r '.items[] | [.metadata.namespace, .metadata.name] | @tsv')

while read -r namespace name; do
  [[ -n "${namespace}" && -n "${name}" ]] || continue
  kubectl -n "${namespace}" annotate externalsecret "${name}" "force-sync=${timestamp}" --overwrite >/dev/null 2>&1 || true
done < <(kubectl get externalsecret -A -o json | jq -r '.items[] | [.metadata.namespace, .metadata.name] | @tsv')

deadline=$((SECONDS + TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  secretstores_not_ready="$(kubectl get secretstore -A -o json | jq '[.items[] | select(((.status.conditions // []) | map(select(.type == "Ready" and .status == "True")) | length) == 0)] | length')"
  externalsecrets_not_ready="$(kubectl get externalsecret -A -o json | jq '[.items[] | select(((.status.conditions // []) | map(select(.type == "Ready" and .status == "True")) | length) == 0)] | length')"

  if [[ "${secretstores_not_ready}" -eq 0 && "${externalsecrets_not_ready}" -eq 0 ]]; then
    log "Vault and External Secrets recovery completed successfully."
    exit 0
  fi

  sleep 3
done

echo "ERROR: Vault recovery timed out after ${TIMEOUT_SECONDS}s." >&2
echo "SecretStores not ready: ${secretstores_not_ready}" >&2
echo "ExternalSecrets not ready: ${externalsecrets_not_ready}" >&2
exit 1
