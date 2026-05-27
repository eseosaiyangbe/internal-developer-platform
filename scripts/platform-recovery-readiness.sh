#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/platform-recovery-readiness.sh [options]

Verify that the local host-side recovery controls for Vault and the broader k3s
platform are present and ready to be used as documented.

Options:
  --quiet       Print only machine-readable status lines
  -h, --help    Show this help message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-identity.sh"

QUIET=0
STATE_FILE="$(idp_resolve_state_file "k3s-vault-init.json")"
VAULT_LABEL="com.${IDP_PLATFORM_SLUG}.vault-recovery"
PLATFORM_LABEL="com.${IDP_PLATFORM_SLUG}.k3s-platform-recovery"
VAULT_PLIST="${HOME}/Library/LaunchAgents/${VAULT_LABEL}.plist"
PLATFORM_PLIST="${HOME}/Library/LaunchAgents/${PLATFORM_LABEL}.plist"
VAULT_RUNTIME_ROOT="${HOME}/.local/share/${IDP_PLATFORM_SLUG}/vault-recovery"
PLATFORM_RUNTIME_ROOT="${HOME}/.local/share/${IDP_PLATFORM_SLUG}/k3s-platform-recovery"

log() {
  if [[ "${QUIET}" -eq 0 ]]; then
    printf '[idp-recovery-readiness] %s\n' "$*"
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

launchagent_loaded() {
  local label="$1"
  launchctl print "gui/$(id -u)/${label}" >/dev/null 2>&1
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
require_cmd helm
require_cmd launchctl

if command -v colima >/dev/null 2>&1; then
  colima_present="true"
  if colima status >/dev/null 2>&1; then
    colima_running="true"
  else
    colima_running="false"
  fi
else
  colima_present="false"
  colima_running="false"
fi

if [[ -f "${STATE_FILE}" ]]; then
  state_present="true"
  state_mode="$(file_mode "${STATE_FILE}")"
else
  state_present="false"
  state_mode="missing"
fi

if [[ -f "${VAULT_PLIST}" ]]; then
  vault_plist_present="true"
else
  vault_plist_present="false"
fi

if [[ -f "${PLATFORM_PLIST}" ]]; then
  platform_plist_present="true"
else
  platform_plist_present="false"
fi

if launchagent_loaded "${VAULT_LABEL}"; then
  vault_agent_loaded="true"
else
  vault_agent_loaded="false"
fi

if launchagent_loaded "${PLATFORM_LABEL}"; then
  platform_agent_loaded="true"
else
  platform_agent_loaded="false"
fi

vault_runtime_script="${VAULT_RUNTIME_ROOT}/scripts/recover-k3s-vault.sh"
platform_runtime_script="${PLATFORM_RUNTIME_ROOT}/scripts/recover-k3s-platform.sh"

if [[ -x "${vault_runtime_script}" ]]; then
  vault_runtime_ready="true"
else
  vault_runtime_ready="false"
fi

if [[ -x "${platform_runtime_script}" ]]; then
  platform_runtime_ready="true"
else
  platform_runtime_ready="false"
fi

if kubectl get namespace vault >/dev/null 2>&1; then
  vault_namespace_present="true"
else
  vault_namespace_present="false"
fi

if kubectl get namespace argocd >/dev/null 2>&1; then
  argocd_namespace_present="true"
else
  argocd_namespace_present="false"
fi

log "Host-side recovery readiness snapshot"
printf 'host-runtime|colima_present=%s|colima_running=%s\n' "${colima_present}" "${colima_running}"
printf 'vault-init-material|path=%s|present=%s|mode=%s\n' "${STATE_FILE}" "${state_present}" "${state_mode}"
printf 'launchagent|name=%s|plist_present=%s|loaded=%s|runtime_script=%s|runtime_ready=%s\n' \
  "${VAULT_LABEL}" "${vault_plist_present}" "${vault_agent_loaded}" "${vault_runtime_script}" "${vault_runtime_ready}"
printf 'launchagent|name=%s|plist_present=%s|loaded=%s|runtime_script=%s|runtime_ready=%s\n' \
  "${PLATFORM_LABEL}" "${platform_plist_present}" "${platform_agent_loaded}" "${platform_runtime_script}" "${platform_runtime_ready}"
printf 'cluster-surfaces|vault_namespace=%s|argocd_namespace=%s\n' "${vault_namespace_present}" "${argocd_namespace_present}"
