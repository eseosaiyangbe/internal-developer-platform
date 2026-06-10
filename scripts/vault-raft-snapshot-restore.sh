#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/vault-raft-snapshot-restore.sh --snapshot <path> --yes-really-restore

Restore a locally stored Vault Raft snapshot into the single-node local Vault
release. This is a destructive control-plane recovery action and should only be
used during deliberate break-glass recovery.

Required options:
  --snapshot <path>        Path to a .snap file created by vault-raft-snapshot-save.sh
  --yes-really-restore     Confirm the destructive restore action

Other options:
  --skip-preflight-backup  Skip taking a fresh backup snapshot before restore
  -h, --help               Show this help message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-identity.sh"

export HOME="${HOME:-$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}' | head -n1)}"
export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-colima}"
KUBECTL_REQUEST_TIMEOUT="${KUBECTL_REQUEST_TIMEOUT:-10s}"

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"
VAULT_STATEFULSET="vault"
VAULT_INIT_FILE="$(idp_resolve_state_file "k3s-vault-init.json")"
SNAPSHOT_PATH=""
CONFIRMED=0
SKIP_PREFLIGHT_BACKUP=0

log() {
  printf '[vault-raft-restore] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

kubectl_cmd() {
  if [[ "${OSTYPE:-}" == darwin* ]] && command -v colima >/dev/null 2>&1 && [[ "${KUBECTL_CONTEXT}" == "colima" ]]; then
    colima ssh -- sudo k3s kubectl --request-timeout "${KUBECTL_REQUEST_TIMEOUT}" "$@"
    return
  fi
  if [[ -n "${KUBECTL_CONTEXT}" ]]; then
    kubectl --request-timeout "${KUBECTL_REQUEST_TIMEOUT}" --context "${KUBECTL_CONTEXT}" "$@"
    return
  fi
  kubectl --request-timeout "${KUBECTL_REQUEST_TIMEOUT}" "$@"
}

wait_for_vault_pod_ready() {
  local deadline
  deadline=$((SECONDS + 180))
  while (( SECONDS < deadline )); do
    local ready
    ready="$(kubectl_cmd get pod "${VAULT_POD}" -n "${VAULT_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "${ready}" == "True" ]]; then
      return 0
    fi
    sleep 5
  done
  printf 'ERROR: Vault pod %s/%s did not become Ready within 180s.\n' "${VAULT_NAMESPACE}" "${VAULT_POD}" >&2
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --snapshot)
      SNAPSHOT_PATH="${2:-}"
      [[ -n "${SNAPSHOT_PATH}" ]] || {
        printf 'ERROR: --snapshot requires a value.\n' >&2
        exit 1
      }
      shift 2
      ;;
    --yes-really-restore)
      CONFIRMED=1
      shift
      ;;
    --skip-preflight-backup)
      SKIP_PREFLIGHT_BACKUP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "${SNAPSHOT_PATH}" ]] || {
  printf 'ERROR: --snapshot is required.\n' >&2
  usage >&2
  exit 1
}
[[ "${CONFIRMED}" -eq 1 ]] || {
  printf 'ERROR: --yes-really-restore is required for this destructive action.\n' >&2
  exit 1
}
[[ -f "${SNAPSHOT_PATH}" ]] || {
  printf 'ERROR: snapshot file not found: %s\n' "${SNAPSHOT_PATH}" >&2
  exit 1
}

require_command jq

[[ -f "${VAULT_INIT_FILE}" ]] || {
  printf 'ERROR: required init material is missing at %s\n' "${VAULT_INIT_FILE}" >&2
  exit 1
}

root_token="$(jq -r '.root_token // empty' "${VAULT_INIT_FILE}")"
[[ -n "${root_token}" ]] || {
  printf 'ERROR: root_token is missing in %s\n' "${VAULT_INIT_FILE}" >&2
  exit 1
}

if [[ "${SKIP_PREFLIGHT_BACKUP}" -eq 0 ]]; then
  log "Taking a fresh preflight snapshot before restore"
  "${SCRIPT_DIR}/vault-raft-snapshot-save.sh" --name pre-restore >/dev/null
fi

remote_file="/tmp/restore-$(basename "${SNAPSHOT_PATH}")"
log "Copying snapshot into ${VAULT_NAMESPACE}/${VAULT_POD}"
kubectl_cmd cp "${SNAPSHOT_PATH}" "${VAULT_NAMESPACE}/${VAULT_POD}:${remote_file}" >/dev/null

log "Restoring snapshot into local Vault"
kubectl_cmd exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc "export VAULT_TOKEN='${root_token}'; vault operator raft snapshot restore -force '${remote_file}' >/dev/null"
kubectl_cmd exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc "rm -f '${remote_file}'" >/dev/null || true

log "Restarting Vault to ensure clean post-restore state"
kubectl_cmd delete pod "${VAULT_POD}" -n "${VAULT_NAMESPACE}" --wait=true >/dev/null
wait_for_vault_pod_ready

log "Re-running host-side recovery and readiness reconciliation"
"${SCRIPT_DIR}/recover-k3s-vault.sh" --timeout 180 >/dev/null
log "Vault Raft snapshot restore completed."
