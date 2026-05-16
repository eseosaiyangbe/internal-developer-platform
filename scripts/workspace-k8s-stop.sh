#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./workspace-lib.sh
source "${SCRIPT_DIR}/workspace-lib.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/workspace-k8s-stop.sh [options]

Safely stop all managed dev overlays from the current Kubernetes context.

This preserves namespaces and persistent data so workloads can be resumed
cleanly with ./scripts/workspace-k8s-start.sh.

Options:
  --app NAME   Stop only one app: observability-stack, opensis, swiftpay, memflip, foodpulse
  --wait       Wait for delete completion before returning
  -h, --help   Show this help message
EOF
}

TARGET_APP="all"
WAIT_FOR_DELETE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      TARGET_APP="${2:?Missing app name}"
      shift 2
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

run_delete() {
  local label="$1"
  local repo_dir="$2"
  local cmd=("${repo_dir}/scripts/k8s-stop.sh")

  echo
  echo "==> Stopping ${label}"
  if [[ "${WAIT_FOR_DELETE}" -eq 1 ]]; then
    cmd+=(--wait)
  fi
  "${cmd[@]}"
}

validate_target_app "${TARGET_APP}"

observability_dir="$(resolve_observability_stack_dir)"
opensis_dir="$(resolve_opensis_dir)"
swiftpay_dir="$(resolve_swiftpay_dir)"
memflip_dir="$(resolve_memflip_dir)"
foodpulse_dir="$(resolve_foodpulse_dir)"

if should_run_app "foodpulse"; then
  run_delete "FoodPulse" "${foodpulse_dir}"
fi
if should_run_app "memflip"; then
  run_delete "MemFlip" "${memflip_dir}"
fi
if should_run_app "swiftpay"; then
  run_delete "SwiftPay" "${swiftpay_dir}"
fi
if should_run_app "opensis"; then
  run_delete "OpenSIS" "${opensis_dir}"
fi
if should_run_app "observability-stack"; then
  run_delete "observability-stack" "${observability_dir}"
fi

echo
echo "Kubernetes workspace stop completed for target: ${TARGET_APP}."
echo "State was preserved for later resume."
