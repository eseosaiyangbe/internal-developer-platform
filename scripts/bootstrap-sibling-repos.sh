#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./workspace-lib.sh
source "${SCRIPT_DIR}/workspace-lib.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-sibling-repos.sh [options]

Clone or refresh the authoritative child workload repositories beside the
central platform repo using the recommended lowercase sibling layout.

Options:
  --refresh         If a sibling repo already exists, fetch and fast-forward it
                    instead of leaving it untouched
  --print-exports   Print the IDP_*_DIR exports for the sibling layout
  -h, --help        Show this help message
EOF
}

log() {
  printf '[sibling-bootstrap] %s\n' "$1"
}

fail() {
  printf '[sibling-bootstrap] ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

clone_or_refresh_repo() {
  local remote_url="$1"
  local target_dir="$2"
  local refresh_existing="$3"

  if [[ -d "${target_dir}/.git" ]]; then
    if [[ "${refresh_existing}" == "1" ]]; then
      log "Refreshing existing sibling repo at ${target_dir}"
      (
        cd "${target_dir}"
        git remote set-url origin "${remote_url}"
        git fetch origin
        current_branch="$(git symbolic-ref --quiet --short HEAD || true)"
        if [[ -n "${current_branch}" && "${current_branch}" == "main" ]]; then
          git pull --ff-only origin main
        else
          log "Skipped fast-forward in ${target_dir} because the current branch is not main"
        fi
      )
    else
      log "Sibling repo already exists at ${target_dir}; leaving it unchanged"
    fi
    return 0
  fi

  if [[ -e "${target_dir}" ]]; then
    fail "Target path exists but is not a Git repo: ${target_dir}"
  fi

  log "Cloning ${remote_url} -> ${target_dir}"
  git clone "${remote_url}" "${target_dir}" >/dev/null
}

seed_env_file_if_present() {
  local repo_dir="$1"

  if [[ -f "${repo_dir}/.env" ]]; then
    return 0
  fi

  if [[ -f "${repo_dir}/.env.example" ]]; then
    cp "${repo_dir}/.env.example" "${repo_dir}/.env"
    log "Created ${repo_dir}/.env from .env.example"
  fi
}

print_exports() {
  cat <<EOF
export IDP_OBSERVABILITY_STACK_DIR="${WORKSPACE_PARENT}/observability-stack"
export IDP_SWIFTPAY_DIR="${WORKSPACE_PARENT}/swiftpay"
export IDP_OPENSIS_DIR="${WORKSPACE_PARENT}/opensis"
export IDP_FOODPULSE_DIR="${WORKSPACE_PARENT}/foodpulse"
export IDP_MEMFLIP_DIR="${WORKSPACE_PARENT}/memflip"
EOF
}

main() {
  local refresh_existing=0
  local print_only=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --refresh)
        refresh_existing=1
        shift
        ;;
      --print-exports)
        print_only=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown option: $1"
        ;;
    esac
  done

  require_command git

  if [[ "${print_only}" == "1" ]]; then
    print_exports
    exit 0
  fi

  clone_or_refresh_repo "https://github.com/eseosaiyangbe/Obervability-Stack.git" "${WORKSPACE_PARENT}/observability-stack" "${refresh_existing}"
  clone_or_refresh_repo "https://github.com/eseosaiyangbe/SwiftPay.git" "${WORKSPACE_PARENT}/swiftpay" "${refresh_existing}"
  clone_or_refresh_repo "https://github.com/eseosaiyangbe/OpenSIS.git" "${WORKSPACE_PARENT}/opensis" "${refresh_existing}"
  clone_or_refresh_repo "https://github.com/eseosaiyangbe/FoodPulse.git" "${WORKSPACE_PARENT}/foodpulse" "${refresh_existing}"
  clone_or_refresh_repo "https://github.com/eseosaiyangbe/MemFlip.git" "${WORKSPACE_PARENT}/memflip" "${refresh_existing}"

  seed_env_file_if_present "${WORKSPACE_PARENT}/observability-stack"
  seed_env_file_if_present "${WORKSPACE_PARENT}/swiftpay"
  seed_env_file_if_present "${WORKSPACE_PARENT}/opensis"
  seed_env_file_if_present "${WORKSPACE_PARENT}/foodpulse"
  seed_env_file_if_present "${WORKSPACE_PARENT}/memflip"

  log "Sibling checkout bootstrap complete"
  print_exports
}

main "$@"
