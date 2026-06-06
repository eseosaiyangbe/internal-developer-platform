#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/vault-access-status.sh [status|break-glass-check] [options]

Print the current Vault operator-access posture or run an explicit break-glass
verification without disclosing secret material.

Commands:
  status               Show the safe day-two status snapshot (default)
  break-glass-check    Verify the host-side init material and root-token access path

Options:
  --quiet              Suppress commentary lines
  -h, --help           Show this help message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-identity.sh"

QUIET=0
ACTION="status"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
VAULT_UI_URL="${VAULT_UI_URL:-http://vault.devops.local/ui/}"
VAULT_INIT_FILE="$(idp_resolve_state_file "k3s-vault-init.json")"

log() {
  if [[ "${QUIET}" -eq 0 ]]; then
    printf '[idp-vault-access] %s\n' "$*"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

file_mode() {
  local target="$1"
  if stat -f '%Sp' "${target}" >/dev/null 2>&1; then
    stat -f '%Sp' "${target}"
  else
    stat -c '%A' "${target}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    status|break-glass-check)
      ACTION="$1"
      shift
      ;;
    --quiet)
      QUIET=1
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

require_cmd kubectl
require_cmd jq
require_cmd stat

vault_status_json="$(kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc 'vault status -format=json' 2>/dev/null || true)"
vault_phase="$(kubectl get pod "${VAULT_POD}" -n "${VAULT_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
vault_ready="$(kubectl get pod "${VAULT_POD}" -n "${VAULT_NAMESPACE}" -o jsonpath='{range .status.conditions[*]}{.type}={.status}{";"}{end}' 2>/dev/null || true)"
secretstores_not_ready="$(kubectl get secretstore -A -o json 2>/dev/null | jq '[.items[] | select(((.status.conditions // []) | map(select(.type == "Ready" and .status == "True")) | length) == 0)] | length' 2>/dev/null || printf 'unknown')"
externalsecrets_not_ready="$(kubectl get externalsecret -A -o json 2>/dev/null | jq '[.items[] | select(((.status.conditions // []) | map(select(.type == "Ready" and .status == "True")) | length) == 0)] | length' 2>/dev/null || printf 'unknown')"

if [[ -n "${vault_status_json}" ]]; then
  vault_sealed="$(printf '%s' "${vault_status_json}" | jq -r '.sealed')"
  vault_version="$(printf '%s' "${vault_status_json}" | jq -r '.version // "unknown"')"
  vault_storage_type="$(printf '%s' "${vault_status_json}" | jq -r '.storage_type // "unknown"')"
else
  vault_sealed="unknown"
  vault_version="unknown"
  vault_storage_type="unknown"
fi

if [[ -f "${VAULT_INIT_FILE}" ]]; then
  init_present="true"
  init_mode="$(file_mode "${VAULT_INIT_FILE}")"
else
  init_present="false"
  init_mode="missing"
fi

log "Vault operator access status"
printf 'vault-ui|url=%s\n' "${VAULT_UI_URL}"
printf 'vault-runtime|phase=%s|sealed=%s|version=%s|conditions=%s\n' \
  "${vault_phase:-missing}" "${vault_sealed}" "${vault_version}" "${vault_ready:-missing}"
printf 'vault-storage|type=%s\n' "${vault_storage_type}"
printf 'vault-init-material|path=%s|present=%s|mode=%s\n' \
  "${VAULT_INIT_FILE}" "${init_present}" "${init_mode}"
printf 'external-secrets|secretstores_not_ready=%s|externalsecrets_not_ready=%s\n' \
  "${secretstores_not_ready}" "${externalsecrets_not_ready}"

if [[ "${ACTION}" == "status" ]]; then
  exit 0
fi

if [[ "${init_present}" != "true" ]]; then
  printf 'ERROR: break-glass check requested but init material is missing at %s\n' "${VAULT_INIT_FILE}" >&2
  exit 1
fi

root_token="$(jq -r '.root_token // empty' "${VAULT_INIT_FILE}")"
if [[ -z "${root_token}" ]]; then
  printf 'ERROR: root_token is missing in %s\n' "${VAULT_INIT_FILE}" >&2
  exit 1
fi

log "Running Vault break-glass verification"

token_lookup_json="$(kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc "export VAULT_TOKEN='${root_token}'; vault token lookup -format=json" 2>/dev/null || true)"
if [[ -z "${token_lookup_json}" ]]; then
  printf 'ERROR: Vault root-token lookup failed during break-glass verification.\n' >&2
  exit 1
fi

auth_list_json="$(kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc "export VAULT_TOKEN='${root_token}'; vault auth list -format=json" 2>/dev/null || true)"
if [[ -z "${auth_list_json}" ]]; then
  printf 'ERROR: Vault auth mount lookup failed during break-glass verification.\n' >&2
  exit 1
fi

userpass_enabled="$(printf '%s' "${auth_list_json}" | jq -r 'has("userpass/")')"

admin_user_ok="false"
readonly_user_ok="false"
if [[ "${userpass_enabled}" == "true" ]]; then
  if kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc "export VAULT_TOKEN='${root_token}'; vault read -format=json auth/userpass/users/admin" >/dev/null 2>&1; then
    admin_user_ok="true"
  fi
  if kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc "export VAULT_TOKEN='${root_token}'; vault read -format=json auth/userpass/users/readonly" >/dev/null 2>&1; then
    readonly_user_ok="true"
  fi
fi

printf 'vault-break-glass|token_lookup=true|userpass_enabled=%s|admin_user=%s|readonly_user=%s\n' \
  "${userpass_enabled}" "${admin_user_ok}" "${readonly_user_ok}"
