#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$PROJECT_ROOT")"
WORKSPACE_PARENT="$(dirname "$WORKSPACE_ROOT")"

resolve_opensis_dir() {
  if [ -n "${IDP_OPENSIS_DIR:-}" ] && [ -d "${IDP_OPENSIS_DIR}" ]; then
    printf '%s\n' "${IDP_OPENSIS_DIR}"
    return
  fi

  if [ -d "$WORKSPACE_ROOT/OpenSIS" ]; then
    printf '%s\n' "$WORKSPACE_ROOT/OpenSIS"
    return
  fi

  if [ -d "$WORKSPACE_PARENT/OpenSIS" ]; then
    printf '%s\n' "$WORKSPACE_PARENT/OpenSIS"
    return
  fi

  if [ -d "$WORKSPACE_PARENT/opensis" ]; then
    printf '%s\n' "$WORKSPACE_PARENT/opensis"
    return
  fi

  printf '%s\n' "$WORKSPACE_PARENT/opensis"
}

OPENSIS_DIR="$(resolve_opensis_dir)"
OPENSIS_COMPOSE="$OPENSIS_DIR/docker-compose.yaml"
OPENSIS_BUILDLOCAL_COMPOSE="$OPENSIS_DIR/docker-compose.buildlocal.yaml"
OPENSIS_ENV="$OPENSIS_DIR/.env.example"
OPENSIS_README="$OPENSIS_DIR/README.md"
OPENSIS_START_SCRIPT="$OPENSIS_DIR/scripts/compose-start.sh"
OPENSIS_PRECHECK="$OPENSIS_DIR/scripts/precheck.sh"
MONITORED_APPS_FILE="$PROJECT_ROOT/ui-next/lib/monitored-apps.ts"
PROMETHEUS_FILE="$PROJECT_ROOT/prometheus/prometheus.yml"

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

pass() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  PASSED_CHECKS=$((PASSED_CHECKS + 1))
  echo -e "${GREEN}OK${NC}  $1"
}

fail() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
  echo -e "${RED}FAIL${NC} $1"
}

header() {
  echo -e "${PURPLE}$1${NC}"
}

info() {
  echo -e "${BLUE}INFO${NC} $1"
}

require_file() {
  local file="$1"
  if [ -f "$file" ]; then
    pass "Found file: $file"
  else
    fail "Missing file: $file"
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if rg -Fq -- "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

header "OpenSIS Integration Audit"
echo "========================="
echo

require_file "$OPENSIS_COMPOSE"
require_file "$OPENSIS_BUILDLOCAL_COMPOSE"
require_file "$OPENSIS_ENV"
require_file "$OPENSIS_README"
require_file "$OPENSIS_START_SCRIPT"
require_file "$OPENSIS_PRECHECK"
require_file "$MONITORED_APPS_FILE"
require_file "$PROMETHEUS_FILE"

echo
header "Compose And Inventory Alignment"

assert_contains "$OPENSIS_COMPOSE" "opensis-ui" "OpenSIS compose exposes the observability alias"
assert_contains "$OPENSIS_COMPOSE" "127.0.0.1:8088:80" "OpenSIS compose publishes the UI on localhost:8088"
assert_contains "$OPENSIS_COMPOSE" "127.0.0.1:8200:8200" "OpenSIS compose publishes Vault on localhost:8200"
assert_contains "$OPENSIS_BUILDLOCAL_COMPOSE" "image: opensis-ui:local" "OpenSIS build-local compatibility override uses a local image tag"
assert_contains "$OPENSIS_BUILDLOCAL_COMPOSE" "dockerfile: Dockerfile" "OpenSIS build-local compatibility override points at the repo Dockerfile"
assert_contains "$OPENSIS_START_SCRIPT" "--build-local" "OpenSIS startup helper supports the build-local path"
assert_contains "$OPENSIS_START_SCRIPT" "compatibility flag" "OpenSIS startup helper documents the build-local compatibility behavior"
assert_contains "$MONITORED_APPS_FILE" "http://localhost:8088" "Control plane inventory uses the OpenSIS browser URL"
assert_contains "$MONITORED_APPS_FILE" "cd ../opensis && ./scripts/compose-start.sh" "Control plane inventory points to the OpenSIS startup helper"
assert_contains "$MONITORED_APPS_FILE" "curl -I http://localhost:8088" "Control plane inventory uses the OpenSIS health check"
assert_contains "$OPENSIS_README" "http://localhost:8088" "OpenSIS README documents the local browser URL"
assert_contains "$OPENSIS_README" "The default local path now builds \`opensis-ui\` locally" "OpenSIS README documents the default portable local-build path"

echo
header "Prometheus Scrape Contract"

assert_contains "$PROMETHEUS_FILE" "app: opensis" "Prometheus blackbox labels include app=opensis"
assert_contains "$PROMETHEUS_FILE" "http://opensis-ui/" "Prometheus blackbox target present for OpenSIS"

echo
header "Bootstrap Contract"

assert_contains "$OPENSIS_PRECHECK" "docker compose version" "OpenSIS precheck accepts the modern Docker Compose plugin"
assert_contains "$OPENSIS_PRECHECK" "Dockerfile" "OpenSIS precheck validates the repo Dockerfile exists"
assert_contains "$OPENSIS_ENV" "MYSQL_ROOT_PASSWORD" "OpenSIS env contract documents MariaDB root password"
assert_contains "$OPENSIS_ENV" "MYSQL_PASSWORD" "OpenSIS env contract documents MariaDB app password"

echo
header "Audit Summary"
echo "============="
info "Checks passed: $PASSED_CHECKS/$TOTAL_CHECKS"

if [ "$FAILED_CHECKS" -gt 0 ]; then
  fail "Failures: $FAILED_CHECKS"
  exit 1
fi

pass "OpenSIS integration audit passed"
