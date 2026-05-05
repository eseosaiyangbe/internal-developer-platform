#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./workspace-lib.sh
source "${SCRIPT_DIR}/workspace-lib.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/workspace-layout.sh

Show how the central platform repo currently resolves workload repository paths.

Environment overrides:
  IDP_OBSERVABILITY_STACK_DIR
  IDP_SWIFTPAY_DIR
  IDP_OPENSIS_DIR
  IDP_FOODPULSE_DIR
  IDP_MEMFLIP_DIR
EOF
}

print_path() {
  local label="$1"
  local path="$2"
  printf '%-22s %s\n' "${label}:" "${path}"
}

main() {
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "")
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac

  print_path "Platform repo" "${WORKSPACE_ROOT}"
  print_path "Parent directory" "${WORKSPACE_PARENT}"
  print_path "Observability" "$(resolve_observability_stack_dir)"
  print_path "SwiftPay" "$(resolve_swiftpay_dir)"
  print_path "OpenSIS" "$(resolve_opensis_dir)"
  print_path "FoodPulse" "$(resolve_foodpulse_dir)"
  print_path "MemFlip" "$(resolve_memflip_dir)"
}

main "$@"
