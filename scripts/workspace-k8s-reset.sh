#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./workspace-lib.sh
source "${SCRIPT_DIR}/workspace-lib.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/workspace-k8s-reset.sh [options]

Destructively reset managed dev overlays from the current Kubernetes context.

This is the workspace-level equivalent of each repo's k8s-reset.sh. It removes
namespaces and persistent state intentionally. Use workspace-k8s-stop.sh for a
safe pause that preserves data.

Options:
  --app NAME   Reset only one app: observability-stack, opensis, swiftpay, memflip, foodpulse
  --yes        Skip the interactive confirmation prompt
  --wait       Wait for namespace deletion before returning
  -h, --help   Show this help message
EOF
}

TARGET_APP="all"
AUTO_APPROVE=0
WAIT_FOR_DELETE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      TARGET_APP="${2:?Missing app name}"
      shift 2
      ;;
    --yes)
      AUTO_APPROVE=1
      shift
      ;;
    --wait)
      WAIT_FOR_DELETE=1
      shift
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

validate_target_app() {
  case "$1" in
    all|observability-stack|opensis|swiftpay|memflip|foodpulse)
      ;;
    *)
      echo "ERROR: Unsupported app '$1'." >&2
      echo "Supported values: observability-stack, opensis, swiftpay, memflip, foodpulse" >&2
      exit 1
      ;;
  esac
}

should_run_app() {
  local app_name="$1"
  [[ "${TARGET_APP}" == "all" || "${TARGET_APP}" == "${app_name}" ]]
}

run_reset() {
  local label="$1"
  local repo_dir="$2"
  local cmd=("${repo_dir}/scripts/k8s-reset.sh")

  if [[ "${AUTO_APPROVE}" -eq 1 ]]; then
    cmd+=(--yes)
  fi
  if [[ "${WAIT_FOR_DELETE}" -eq 1 ]]; then
    cmd+=(--wait)
  fi

  echo
  echo "==> Resetting ${label}"
  "${cmd[@]}"
}

validate_target_app "${TARGET_APP}"

observability_dir="$(resolve_observability_stack_dir)"
opensis_dir="$(resolve_opensis_dir)"
swiftpay_dir="$(resolve_swiftpay_dir)"
memflip_dir="$(resolve_memflip_dir)"
foodpulse_dir="$(resolve_foodpulse_dir)"

if should_run_app "foodpulse"; then
  run_reset "FoodPulse" "${foodpulse_dir}"
fi
if should_run_app "memflip"; then
  run_reset "MemFlip" "${memflip_dir}"
fi
if should_run_app "swiftpay"; then
  run_reset "SwiftPay" "${swiftpay_dir}"
fi
if should_run_app "opensis"; then
  run_reset "OpenSIS" "${opensis_dir}"
fi
if should_run_app "observability-stack"; then
  run_reset "observability-stack" "${observability_dir}"
fi

echo
echo "Kubernetes workspace reset completed for target: ${TARGET_APP}."
