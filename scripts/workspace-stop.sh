#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./workspace-lib.sh
source "${SCRIPT_DIR}/workspace-lib.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/workspace-stop.sh [options]

Stop the full Internal Developer Platform Compose workspace in reverse order.

This script is Docker Compose only. It does not manage Kubernetes resources.
For Kubernetes, use ./scripts/workspace-k8s-stop.sh instead.

Options:
  --volumes         Remove named volumes where the repo-specific stop path supports it
  --opensis-edge    Include OpenSIS edge services in the stop path
  --opensis-pull    Stop OpenSIS using the published-image compose override
  Environment overrides:
    IDP_OBSERVABILITY_STACK_DIR
    IDP_SWIFTPAY_DIR
    IDP_OPENSIS_DIR
    IDP_FOODPULSE_DIR
    IDP_MEMFLIP_DIR
  -h, --help        Show this help message
EOF
}

log() {
  printf '[workspace-stop] %s\n' "$1"
}

fail() {
  printf '[workspace-stop] ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

ensure_docker_ready() {
  require_command docker
  docker info >/dev/null 2>&1 || fail "Docker daemon is not reachable"
  docker compose version >/dev/null 2>&1 || fail "Docker Compose is not available"
}

stop_memflip() {
  local memflip_dir="$1"
  log "Stopping MemFlip"
  (
    cd "${memflip_dir}"
    if [[ "${REMOVE_VOLUMES}" == "1" ]]; then
      docker compose down --remove-orphans -v
    else
      docker compose down --remove-orphans
    fi
  )
}

stop_foodpulse() {
  local foodpulse_dir="$1"
  log "Stopping FoodPulse"
  (
    cd "${foodpulse_dir}"
    if [[ "${REMOVE_VOLUMES}" == "1" ]]; then
      docker compose down --remove-orphans -v
    else
      ./scripts/stop.sh
    fi
  )
}

stop_opensis() {
  local opensis_dir="$1"
  local -a opensis_cmd=(./scripts/compose-stop.sh)

  if [[ "${OPENSIS_PULL_IMAGE}" == "1" ]]; then
    opensis_cmd+=(--pull-image)
  fi

  if [[ "${OPENSIS_EDGE}" == "1" ]]; then
    opensis_cmd+=(--edge)
  fi

  if [[ "${REMOVE_VOLUMES}" == "1" ]]; then
    opensis_cmd+=(--volumes)
  fi

  log "Stopping OpenSIS"
  (
    cd "${opensis_dir}"
    "${opensis_cmd[@]}"
  )
}

stop_swiftpay() {
  local swiftpay_dir="$1"
  log "Stopping SwiftPay"
  (
    cd "${swiftpay_dir}"
    if [[ "${REMOVE_VOLUMES}" == "1" ]]; then
      docker compose down -v
    else
      docker compose down
    fi
  )
}

stop_observability_stack() {
  local observability_dir="$1"
  log "Stopping Obervability-Stack"
  (
    cd "${observability_dir}"
    if [[ "${REMOVE_VOLUMES}" == "1" ]]; then
      docker compose down -v
    else
      docker compose down
    fi
  )
}

main() {
  REMOVE_VOLUMES=0
  OPENSIS_EDGE=0
  OPENSIS_PULL_IMAGE=0
  local observability_dir=""
  local swiftpay_dir=""
  local opensis_dir=""
  local foodpulse_dir=""
  local memflip_dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --volumes)
        REMOVE_VOLUMES=1
        shift
        ;;
      --opensis-edge)
        OPENSIS_EDGE=1
        shift
        ;;
      --opensis-pull)
        OPENSIS_PULL_IMAGE=1
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

  ensure_docker_ready

  observability_dir="$(resolve_observability_stack_dir)"
  swiftpay_dir="$(resolve_swiftpay_dir)"
  opensis_dir="$(resolve_opensis_dir)"
  foodpulse_dir="$(resolve_foodpulse_dir)"
  memflip_dir="$(resolve_memflip_dir)"

  stop_memflip "${memflip_dir}"
  stop_foodpulse "${foodpulse_dir}"
  stop_opensis "${opensis_dir}"
  stop_swiftpay "${swiftpay_dir}"
  stop_observability_stack "${observability_dir}"

  log "Workspace stop complete"
}

main "$@"
