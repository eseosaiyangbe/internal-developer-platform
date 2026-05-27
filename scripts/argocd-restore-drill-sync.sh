#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/argocd-restore-drill-sync.sh suspend --app <child-application>
  ./scripts/argocd-restore-drill-sync.sh resume --app <child-application>
  ./scripts/argocd-restore-drill-sync.sh status --app <child-application>
  ./scripts/argocd-restore-drill-sync.sh --help

Supported child applications:
  observability-dev
  swiftpay-dev
  foodpulse-dev
  memflip-dev
  opensis-dev

Behavior:
  suspend  Removes automated sync from the root app and the selected child app.
  resume   Restores automated sync on the root app and the selected child app.
  status   Prints the current automated sync posture for the root app and child app.

Notes:
  - The root application is always included because child restore drills can be
    reverted by root reconciliation even if only the child app is modified.
  - This helper is intended for controlled restore drills, not for normal day-two
    GitOps operation.
EOF
}

log() {
  printf '[idp-argocd-drill] %s\n' "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

validate_child_app() {
  case "$1" in
    observability-dev|swiftpay-dev|foodpulse-dev|memflip-dev|opensis-dev)
      ;;
    *)
      printf 'ERROR: unsupported child application: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
}

application_exists() {
  local app_name="$1"
  kubectl get application "$app_name" -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1
}

sync_policy_present() {
  local app_name="$1"
  local value
  value="$(kubectl get application "$app_name" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.syncPolicy.automated.prune}' 2>/dev/null || true)"
  [ -n "$value" ]
}

patch_suspend() {
  local app_name="$1"
  if sync_policy_present "$app_name"; then
    kubectl patch application "$app_name" -n "$ARGOCD_NAMESPACE" \
      --type json \
      -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]' >/dev/null
    log "suspended automated sync for ${app_name}"
  else
    log "automated sync already absent for ${app_name}"
  fi
}

patch_resume_root() {
  kubectl patch application "$ROOT_APP" -n "$ARGOCD_NAMESPACE" \
    --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null
  log "restored automated sync for ${ROOT_APP}"
}

patch_resume_child() {
  local app_name="$1"
  kubectl patch application "$app_name" -n "$ARGOCD_NAMESPACE" \
    --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true"]}}}' >/dev/null
  log "restored automated sync for ${app_name}"
}

print_status() {
  local app_name="$1"
  kubectl get application "$ROOT_APP" "$app_name" -n "$ARGOCD_NAMESPACE" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|automated="}{.spec.syncPolicy.automated.prune}{","}{.spec.syncPolicy.automated.selfHeal}{"|syncOptions="}{.spec.syncPolicy.syncOptions}{"|sync="}{.status.sync.status}{"|health="}{.status.health.status}{"\n"}{end}'
}

require_cmd kubectl

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ROOT_APP="${ROOT_APP:-internal-developer-platform-dev-root}"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] || [ "$#" -eq 0 ]; then
  usage
  exit 0
fi

ACTION="$1"
shift

CHILD_APP=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --app)
      CHILD_APP="${2:-}"
      shift 2
      ;;
    *)
      printf 'ERROR: unexpected argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$CHILD_APP" ]; then
  echo "ERROR: --app is required" >&2
  usage >&2
  exit 1
fi

validate_child_app "$CHILD_APP"

application_exists "$ROOT_APP" || {
  printf 'ERROR: root application not found: %s\n' "$ROOT_APP" >&2
  exit 1
}

application_exists "$CHILD_APP" || {
  printf 'ERROR: child application not found: %s\n' "$CHILD_APP" >&2
  exit 1
}

case "$ACTION" in
  suspend)
    patch_suspend "$ROOT_APP"
    patch_suspend "$CHILD_APP"
    print_status "$CHILD_APP"
    ;;
  resume)
    patch_resume_root
    patch_resume_child "$CHILD_APP"
    kubectl annotate application "$CHILD_APP" -n "$ARGOCD_NAMESPACE" \
      argocd.argoproj.io/refresh=hard --overwrite >/dev/null
    log "triggered hard refresh for ${CHILD_APP}"
    print_status "$CHILD_APP"
    ;;
  status)
    print_status "$CHILD_APP"
    ;;
  *)
    printf 'ERROR: unsupported action: %s\n' "$ACTION" >&2
    usage >&2
    exit 1
    ;;
esac
