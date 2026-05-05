#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${WORKSPACE_SCRIPT_DIR}/.." && pwd)"
WORKSPACE_PARENT="$(cd "${WORKSPACE_ROOT}/.." && pwd)"

workspace_repo_override_var() {
  local repo_key="$1"
  printf 'IDP_%s_DIR' "$(printf '%s' "${repo_key}" | tr '[:lower:]-' '[:upper:]_')"
}

workspace_repo_canonical_dir_name() {
  local repo_key="$1"
  printf '%s\n' "${repo_key//_/-}"
}

workspace_repo_candidates() {
  local repo_name="$1"
  local repo_key="$2"
  local override_var="$3"
  local override_value="${!override_var:-}"
  local canonical_dir_name

  canonical_dir_name="$(workspace_repo_canonical_dir_name "${repo_key}")"

  if [[ -n "${override_value}" ]]; then
    printf '%s\n' "${override_value}"
  fi

  printf '%s/%s\n' "${WORKSPACE_ROOT}" "${repo_name}"
  printf '%s/%s\n' "${WORKSPACE_PARENT}" "${repo_name}"
  printf '%s/%s\n' "${WORKSPACE_PARENT}" "${canonical_dir_name}"
}

resolve_repo_dir() {
  local repo_name="$1"
  local repo_key="$2"
  local marker_path="$3"
  local override_var
  local candidate

  override_var="$(workspace_repo_override_var "${repo_key}")"

  while IFS= read -r candidate; do
    [[ -n "${candidate}" ]] || continue
    if [[ -e "${candidate}/${marker_path}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done < <(workspace_repo_candidates "${repo_name}" "${repo_key}" "${override_var}")

  printf 'Unable to locate %s. Checked current-platform and sibling paths for %s. Override with %s.\n' \
    "${repo_name}" "${marker_path}" "${override_var}" >&2
  return 1
}

resolve_observability_stack_dir() {
  resolve_repo_dir "Obervability-Stack" "observability_stack" "docker-compose.yml"
}

resolve_swiftpay_dir() {
  resolve_repo_dir "SwiftPay" "swiftpay" "docker-compose.yml"
}

resolve_opensis_dir() {
  resolve_repo_dir "OpenSIS" "opensis" "scripts/compose-start.sh"
}

resolve_foodpulse_dir() {
  resolve_repo_dir "FoodPulse" "foodpulse" "scripts/start.sh"
}

resolve_memflip_dir() {
  resolve_repo_dir "MemFlip" "memflip" "docker-compose.yml"
}
