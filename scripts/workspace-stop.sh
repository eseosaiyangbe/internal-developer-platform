#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/workspace-stop.sh [options]

Stop the full DevOps Easy Learning workspace in reverse order.

Options:
  --volumes         Remove named volumes where the repo-specific stop path supports it
  --opensis-edge    Include OpenSIS edge services in the stop path
  --opensis-pull    Stop OpenSIS using the published-image compose override
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
  log "Stopping MemFlip"
  (
    cd "${WORKSPACE_ROOT}/MemFlip"
    if [[ "${REMOVE_VOLUMES}" == "1" ]]; then
      docker compose down --remove-orphans -v
    else
      docker compose down --remove-orphans
    fi
  )
}

stop_foodpulse() {
  log "Stopping FoodPulse"
  (
    cd "${WORKSPACE_ROOT}/FoodPulse"
    if [[ "${REMOVE_VOLUMES}" == "1" ]]; then
      docker compose down --remove-orphans -v
    else
      ./scripts/stop.sh
    fi
  )
}

stop_opensis() {
  local opensis_mode=()

  if [[ "${OPENSIS_PULL_IMAGE}" == "1" ]]; then
    opensis_mode+=(--pull-image)
  fi

  if [[ "${OPENSIS_EDGE}" == "1" ]]; then
    opensis_mode+=(--edge)
  fi

  if [[ "${REMOVE_VOLUMES}" == "1" ]]; then
    opensis_mode+=(--volumes)
  fi

  log "Stopping OpenSIS"
  (
    cd "${WORKSPACE_ROOT}/OpenSIS"
    ./scripts/compose-stop.sh "${opensis_mode[@]}"
  )
}

stop_swiftpay() {
  log "Stopping SwiftPay"
  (
    cd "${WORKSPACE_ROOT}/SwiftPay"
    if [[ "${REMOVE_VOLUMES}" == "1" ]]; then
      docker compose down -v
    else
      docker compose down
    fi
  )
}

stop_observability_stack() {
  log "Stopping Obervability-Stack"
  (
    cd "${WORKSPACE_ROOT}/Obervability-Stack"
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

  stop_memflip
  stop_foodpulse
  stop_opensis
  stop_swiftpay
  stop_observability_stack

  log "Workspace stop complete"
}

main "$@"
