#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/vault-raft-snapshot-save.sh [options]

Capture a host-side backup of the local shared Vault integrated Raft state.

Options:
  --name <label>        Optional label suffix for the snapshot filename
  --output-dir <path>   Override the host-side snapshot directory
  -h, --help            Show this help message
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
VAULT_INIT_FILE="$(idp_resolve_state_file "k3s-vault-init.json")"
SNAPSHOT_ROOT_DEFAULT="${IDP_STATE_DIR}/vault-raft-snapshots"
SNAPSHOT_ROOT="${SNAPSHOT_ROOT_DEFAULT}"
NAME_LABEL=""

log() {
  printf '[vault-raft-snapshot] %s\n' "$*"
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      NAME_LABEL="${2:-}"
      [[ -n "${NAME_LABEL}" ]] || {
        printf 'ERROR: --name requires a value.\n' >&2
        exit 1
      }
      shift 2
      ;;
    --output-dir)
      SNAPSHOT_ROOT="${2:-}"
      [[ -n "${SNAPSHOT_ROOT}" ]] || {
        printf 'ERROR: --output-dir requires a value.\n' >&2
        exit 1
      }
      shift 2
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

require_command jq
require_command sha256sum
require_command stat

idp_migrate_legacy_state_dir_if_needed
idp_ensure_state_dir

[[ -f "${VAULT_INIT_FILE}" ]] || {
  printf 'ERROR: required init material is missing at %s\n' "${VAULT_INIT_FILE}" >&2
  exit 1
}

root_token="$(jq -r '.root_token // empty' "${VAULT_INIT_FILE}")"
[[ -n "${root_token}" ]] || {
  printf 'ERROR: root_token is missing in %s\n' "${VAULT_INIT_FILE}" >&2
  exit 1
}

vault_status_json="$(kubectl_cmd exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc 'vault status -format=json' 2>/dev/null || true)"
[[ -n "${vault_status_json}" ]] || {
  printf 'ERROR: unable to retrieve Vault status from %s/%s\n' "${VAULT_NAMESPACE}" "${VAULT_POD}" >&2
  exit 1
}

storage_type="$(printf '%s' "${vault_status_json}" | jq -r '.storage_type // "unknown"')"
sealed="$(printf '%s' "${vault_status_json}" | jq -r 'if .sealed == true then "true" else "false" end')"
[[ "${storage_type}" == "raft" ]] || {
  printf 'ERROR: expected raft storage, found %s\n' "${storage_type}" >&2
  exit 1
}
[[ "${sealed}" == "false" ]] || {
  printf 'ERROR: Vault is sealed; unseal before taking a snapshot.\n' >&2
  exit 1
}

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
safe_label=""
if [[ -n "${NAME_LABEL}" ]]; then
  safe_label="-$(printf '%s' "${NAME_LABEL}" | tr -cs 'A-Za-z0-9._-' '-')"
fi
snapshot_dir="${SNAPSHOT_ROOT}/${timestamp}"
snapshot_file="${snapshot_dir}/vault-raft-${timestamp}${safe_label}.snap"
metadata_file="${snapshot_dir}/vault-raft-${timestamp}${safe_label}.metadata.json"
remote_file="/tmp/vault-raft-${timestamp}.snap"

mkdir -p "${snapshot_dir}"
chmod 700 "${snapshot_dir}"

log "Capturing Vault Raft snapshot to ${snapshot_file}"
kubectl_cmd exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc "export VAULT_TOKEN='${root_token}'; vault operator raft snapshot save '${remote_file}' >/dev/null"
kubectl_cmd cp "${VAULT_NAMESPACE}/${VAULT_POD}:${remote_file}" "${snapshot_file}" >/dev/null
kubectl_cmd exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc "rm -f '${remote_file}'" >/dev/null

sha256="$(sha256sum "${snapshot_file}" | awk '{print $1}')"
size_bytes="$(stat -f '%z' "${snapshot_file}" 2>/dev/null || stat -c '%s' "${snapshot_file}")"

printf '%s\n' "${vault_status_json}" | jq \
  --arg snapshot_file "${snapshot_file}" \
  --arg created_at "${timestamp}" \
  --arg sha256 "${sha256}" \
  --argjson size_bytes "${size_bytes}" \
  '{
     created_at: $created_at,
     snapshot_file: $snapshot_file,
     sha256: $sha256,
     size_bytes: $size_bytes,
     vault_status: {
       version: .version,
       storage_type: .storage_type,
       cluster_name: .cluster_name,
       cluster_id: .cluster_id,
       ha_enabled: .ha_enabled,
       ha_mode: .ha_mode,
       raft_committed_index: .raft_committed_index,
       raft_applied_index: .raft_applied_index
     }
   }' > "${metadata_file}"
chmod 600 "${snapshot_file}" "${metadata_file}"

log "Snapshot saved successfully."
printf 'snapshot|file=%s|sha256=%s|size_bytes=%s\n' "${snapshot_file}" "${sha256}" "${size_bytes}"
