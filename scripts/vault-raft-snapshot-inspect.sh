#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/vault-raft-snapshot-inspect.sh [options]

Inspect locally stored Vault Raft snapshots captured by vault-raft-snapshot-save.sh.

Options:
  --latest              Show only the newest snapshot record
  --snapshot <path>     Inspect one specific metadata or snapshot file
  -h, --help            Show this help message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-identity.sh"

SNAPSHOT_ROOT="${IDP_STATE_DIR}/vault-raft-snapshots"
LATEST_ONLY=0
TARGET_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --latest)
      LATEST_ONLY=1
      shift
      ;;
    --snapshot)
      TARGET_PATH="${2:-}"
      [[ -n "${TARGET_PATH}" ]] || {
        printf 'ERROR: --snapshot requires a value.\n' >&2
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

require_command jq

resolve_metadata_file() {
  local path="$1"
  if [[ "${path}" == *.metadata.json ]]; then
    printf '%s\n' "${path}"
    return 0
  fi
  if [[ "${path}" == *.snap ]]; then
    local metadata_candidate
    metadata_candidate="${path%.snap}.metadata.json"
    [[ -f "${metadata_candidate}" ]] || {
      printf 'ERROR: metadata file not found for snapshot %s\n' "${path}" >&2
      exit 1
    }
    printf '%s\n' "${metadata_candidate}"
    return 0
  fi
  printf 'ERROR: unsupported snapshot path: %s\n' "${path}" >&2
  exit 1
}

print_metadata() {
  local metadata_file="$1"
  jq -r '
    "snapshot|created_at=\(.created_at)|file=\(.snapshot_file)|sha256=\(.sha256)|size_bytes=\(.size_bytes)|cluster_name=\(.vault_status.cluster_name)|cluster_id=\(.vault_status.cluster_id)|version=\(.vault_status.version)|raft_committed_index=\(.vault_status.raft_committed_index)|raft_applied_index=\(.vault_status.raft_applied_index)"' "${metadata_file}"
}

if [[ -n "${TARGET_PATH}" ]]; then
  metadata_file="$(resolve_metadata_file "${TARGET_PATH}")"
  print_metadata "${metadata_file}"
  exit 0
fi

[[ -d "${SNAPSHOT_ROOT}" ]] || {
  printf 'No Vault Raft snapshots found at %s\n' "${SNAPSHOT_ROOT}"
  exit 0
}

metadata_listing="$(find "${SNAPSHOT_ROOT}" -type f -name '*.metadata.json' | sort)"

if [[ -z "${metadata_listing}" ]]; then
  printf 'No Vault Raft snapshots found at %s\n' "${SNAPSHOT_ROOT}"
  exit 0
fi

if [[ "${LATEST_ONLY}" -eq 1 ]]; then
  latest_metadata_file="$(printf '%s\n' "${metadata_listing}" | tail -n 1)"
  print_metadata "${latest_metadata_file}"
  exit 0
fi

while IFS= read -r metadata_file; do
  print_metadata "${metadata_file}"
done <<EOF
${metadata_listing}
EOF
