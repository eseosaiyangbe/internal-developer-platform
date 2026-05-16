#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./workspace-lib.sh
source "${SCRIPT_DIR}/workspace-lib.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/workspace-k8s-start.sh [options]

Start the shared k3s runtime and resume or deploy all managed dev overlays.

By default, this script reuses existing local images and focuses on a safe
start/resume path. Use --build only when you intentionally want fresh images.

Options:
  --app NAME   Start only one app: observability-stack, opensis, swiftpay, memflip, foodpulse
  --build      Rebuild application images before deploy
  -h, --help   Show this help message
EOF
}

BUILD_IMAGES=0
TARGET_APP="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      TARGET_APP="${2:?Missing app name}"
      shift 2
      ;;
    --build)
      BUILD_IMAGES=1
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

run_step() {
  local label="$1"
  shift

  echo
  echo "==> ${label}"
  "$@"
}

run_app_start() {
  local label="$1"
  local repo_dir="$2"
  shift 2

  local cmd=("${repo_dir}/scripts/k8s-start.sh")
  if [[ "${BUILD_IMAGES}" -eq 1 ]]; then
    cmd+=(--build)
  fi
  if [[ "$#" -gt 0 ]]; then
    cmd+=("$@")
  fi

  run_step "Starting ${label}" "${cmd[@]}"
}

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

validate_target_app "${TARGET_APP}"

platform_dir="$(resolve_internal_developer_platform_dir)"
observability_dir="$(resolve_observability_stack_dir)"
opensis_dir="$(resolve_opensis_dir)"
swiftpay_dir="$(resolve_swiftpay_dir)"
memflip_dir="$(resolve_memflip_dir)"
foodpulse_dir="$(resolve_foodpulse_dir)"

runtime_script="$(resolve_workspace_script "ensure-k3s-runtime.sh")"
secrets_script="$(resolve_workspace_script "bootstrap-k3s-vault-secrets.sh")"

run_step "Ensuring k3s runtime" "${runtime_script}"
run_step "Bootstrapping shared Vault and External Secrets" "${secrets_script}"

if should_run_app "observability-stack"; then
  run_app_start "observability-stack" "${observability_dir}"
fi

if should_run_app "opensis"; then
  run_app_start "OpenSIS" "${opensis_dir}"
fi

if should_run_app "swiftpay"; then
  run_app_start "SwiftPay" "${swiftpay_dir}"
fi

if should_run_app "memflip"; then
  run_app_start "MemFlip" "${memflip_dir}"
fi

if should_run_app "foodpulse"; then
  run_app_start "FoodPulse" "${foodpulse_dir}"
fi

echo
echo "Kubernetes workspace start completed successfully for target: ${TARGET_APP}"
echo "Repos used:"
echo "  platform: ${platform_dir}"
if should_run_app "observability-stack"; then
  echo "  observability-stack: ${observability_dir}"
fi
if should_run_app "opensis"; then
  echo "  opensis: ${opensis_dir}"
fi
if should_run_app "swiftpay"; then
  echo "  swiftpay: ${swiftpay_dir}"
fi
if should_run_app "memflip"; then
  echo "  memflip: ${memflip_dir}"
fi
if should_run_app "foodpulse"; then
  echo "  foodpulse: ${foodpulse_dir}"
fi
