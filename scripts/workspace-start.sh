#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/workspace-start.sh [options]

Start the full DevOps Easy Learning workspace in the recommended order.

Options:
  --skip-verify      Skip the final shared operator check
  --opensis-edge     Start OpenSIS with edge services enabled
  --opensis-pull     Start OpenSIS with the published UI image instead of the local build path
  -h, --help         Show this help message
EOF
}

log() {
  printf '[workspace-start] %s\n' "$1"
}

fail() {
  printf '[workspace-start] ERROR: %s\n' "$1" >&2
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

ensure_env_file() {
  local repo_dir="$1"

  if [[ -f "${repo_dir}/.env" ]]; then
    return 0
  fi

  if [[ ! -f "${repo_dir}/.env.example" ]]; then
    fail "Missing ${repo_dir}/.env and ${repo_dir}/.env.example"
  fi

  cp "${repo_dir}/.env.example" "${repo_dir}/.env"
  log "Created ${repo_dir}/.env from .env.example"
}

start_observability_stack() {
  log "Starting Obervability-Stack"
  (
    cd "${WORKSPACE_ROOT}/Obervability-Stack"
    docker compose up -d
  )
}

start_swiftpay() {
  log "Starting SwiftPay"
  (
    cd "${WORKSPACE_ROOT}/SwiftPay"
    docker compose up -d
  )
}

start_opensis() {
  local opensis_mode=()
  local arch

  arch="$(uname -m)"

  if [[ "${arch}" == "arm64" || "${arch}" == "aarch64" ]]; then
    opensis_mode+=(--build-local)
  fi

  if [[ "${OPENSIS_PULL_IMAGE}" == "1" ]]; then
    opensis_mode+=(--pull-image)
  fi

  if [[ "${OPENSIS_EDGE}" == "1" ]]; then
    opensis_mode+=(--edge)
  fi

  log "Starting OpenSIS"
  (
    cd "${WORKSPACE_ROOT}/OpenSIS"
    ./scripts/compose-start.sh "${opensis_mode[@]}"
  )
}

start_foodpulse() {
  log "Starting FoodPulse"
  ensure_env_file "${WORKSPACE_ROOT}/FoodPulse"
  (
    cd "${WORKSPACE_ROOT}/FoodPulse"
    ./scripts/start.sh
  )
}

start_memflip() {
  log "Starting MemFlip"
  ensure_env_file "${WORKSPACE_ROOT}/MemFlip"
  (
    cd "${WORKSPACE_ROOT}/MemFlip"
    docker compose up -d
  )
}

run_final_verify() {
  log "Running shared operator verification"
  (
    cd "${WORKSPACE_ROOT}"
    ./Obervability-Stack/scripts/devops-monitor.sh operator
  )
}

main() {
  local skip_verify=0
  OPENSIS_EDGE=0
  OPENSIS_PULL_IMAGE=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-verify)
        skip_verify=1
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

  start_observability_stack
  start_swiftpay
  start_opensis
  start_foodpulse
  start_memflip

  if [[ "${skip_verify}" -eq 0 ]]; then
    run_final_verify
  else
    log "Skipped shared operator verification"
  fi

  log "Workspace startup complete"
}

main "$@"
