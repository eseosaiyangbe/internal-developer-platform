#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/workspace-start.sh [options]

Start the full DevOps Easy Learning workspace in the recommended order.

Options:
  --rebuild          Force image rebuilds for local-build services before startup
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
  require_command curl
  docker info >/dev/null 2>&1 || fail "Docker daemon is not reachable"
  docker compose version >/dev/null 2>&1 || fail "Docker Compose is not available"
}

json_field() {
  local payload="$1"
  local python_expr="$2"

  JSON_PAYLOAD="$payload" python3 - "$python_expr" <<'PY'
import json
import os
import sys

payload = json.loads(os.environ["JSON_PAYLOAD"])
expr = sys.argv[1]

if expr == "downApps":
    print(payload.get("summary", {}).get("downApps", ""))
elif expr == "totalApps":
    print(payload.get("summary", {}).get("totalApps", ""))
else:
    raise SystemExit(1)
PY
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

repair_memflip_env_defaults() {
  local env_file="${WORKSPACE_ROOT}/MemFlip/.env"

  if [[ ! -f "${env_file}" ]]; then
    return 0
  fi

  if grep -q '^DB_PASSWORD=your_database_password_here$' "${env_file}" || grep -q '^REDIS_PASSWORD=your_redis_password_here$' "${env_file}"; then
    perl -0pi -e 's/^DB_PASSWORD=your_database_password_here$/DB_PASSWORD=gamepass123/mg; s/^REDIS_PASSWORD=your_redis_password_here$/REDIS_PASSWORD=gamepass123/mg' "${env_file}"
    log "Repaired MemFlip placeholder credentials in MemFlip/.env"
  fi
}

start_observability_stack() {
  log "Starting Obervability-Stack"
  (
    cd "${WORKSPACE_ROOT}/Obervability-Stack"
    if [[ "${FORCE_REBUILD}" == "1" ]]; then
      docker compose up -d --build
    else
      docker compose up -d
    fi
  )
}

start_swiftpay() {
  log "Starting SwiftPay"
  (
    cd "${WORKSPACE_ROOT}/SwiftPay"
    if [[ "${FORCE_REBUILD}" == "1" ]]; then
      docker compose up -d --build
    else
      docker compose up -d
    fi
  )
}

start_opensis() {
  local -a opensis_cmd=(./scripts/compose-start.sh)
  local arch

  arch="$(uname -m)"

  if [[ "${arch}" == "arm64" || "${arch}" == "aarch64" ]]; then
    opensis_cmd+=(--build-local)
  fi

  if [[ "${FORCE_REBUILD}" == "1" ]]; then
    opensis_cmd+=(--build)
  fi

  if [[ "${OPENSIS_PULL_IMAGE}" == "1" ]]; then
    opensis_cmd+=(--pull-image)
  fi

  if [[ "${OPENSIS_EDGE}" == "1" ]]; then
    opensis_cmd+=(--edge)
  fi

  log "Starting OpenSIS"
  (
    cd "${WORKSPACE_ROOT}/OpenSIS"
    "${opensis_cmd[@]}"
  )
}

start_foodpulse() {
  log "Starting FoodPulse"
  ensure_env_file "${WORKSPACE_ROOT}/FoodPulse"
  (
    cd "${WORKSPACE_ROOT}/FoodPulse"
    if [[ "${FORCE_REBUILD}" == "1" ]]; then
      ./scripts/start.sh --build
    else
      ./scripts/start.sh
    fi
  )
}

start_memflip() {
  log "Starting MemFlip"
  ensure_env_file "${WORKSPACE_ROOT}/MemFlip"
  repair_memflip_env_defaults
  (
    cd "${WORKSPACE_ROOT}/MemFlip"
    if [[ "${FORCE_REBUILD}" == "1" ]]; then
      docker compose up -d --build
    else
      docker compose up -d
    fi
  )
}

wait_for_workspace_apps() {
  local attempts=18
  local sleep_seconds=5
  local url="http://localhost:4000/api/apps/health"
  local payload=""
  local total_apps=""
  local down_apps=""
  local attempt

  log "Waiting for control-plane app snapshot to stabilize"

  for ((attempt=1; attempt<=attempts; attempt++)); do
    payload="$(curl -fsS --max-time 15 "${url}" || true)"

    if [[ -n "${payload}" ]]; then
      total_apps="$(json_field "${payload}" "totalApps" 2>/dev/null || true)"
      down_apps="$(json_field "${payload}" "downApps" 2>/dev/null || true)"

      if [[ "${total_apps}" =~ ^[0-9]+$ ]] && [[ "${down_apps}" =~ ^[0-9]+$ ]] && [[ "${total_apps}" -gt 0 ]] && [[ "${down_apps}" -eq 0 ]]; then
        log "Control-plane app snapshot is healthy"
        return 0
      fi

      log "App snapshot not ready yet (attempt ${attempt}/${attempts}, total=${total_apps:-unknown}, down=${down_apps:-unknown})"
    else
      log "App snapshot endpoint not ready yet (attempt ${attempt}/${attempts})"
    fi

    sleep "${sleep_seconds}"
  done

  log "App snapshot did not fully stabilize before verification; continuing to operator check"
}

run_final_verify() {
  wait_for_workspace_apps
  log "Running shared operator verification"
  (
    cd "${WORKSPACE_ROOT}"
    ./Obervability-Stack/scripts/devops-monitor.sh operator
  )
}

main() {
  local skip_verify=0
  FORCE_REBUILD=0
  OPENSIS_EDGE=0
  OPENSIS_PULL_IMAGE=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --rebuild)
        FORCE_REBUILD=1
        shift
        ;;
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
