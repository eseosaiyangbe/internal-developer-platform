#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/migrate-k3s-vault-file-to-raft.sh [options]

Perform an in-place offline migration of the local shared Vault release from the
file storage backend to integrated Raft storage while preserving the existing
cluster data and host-side Shamir recovery material.

Options:
  --prepare-only        Perform the offline PVC migration only; do not run Helm or post-migration bootstrap
  --skip-backup         Skip the host-side PVC backup artifact
  --timeout <seconds>   Wait timeout for scale, helper pods, and post-migration recovery
  -h, --help            Show this help message
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-identity.sh"

VAULT_NAMESPACE="vault"
VAULT_RELEASE="vault"
VAULT_STATEFULSET="vault"
VAULT_POD="vault-0"
VAULT_CONFIGMAP="vault-config"
VAULT_VALUES_FILE="${ROOT_DIR}/scripts/vault-k3s-values.yaml"
VAULT_INIT_FILE="$(idp_resolve_state_file "k3s-vault-init.json")"
BACKUP_ROOT="${IDP_STATE_DIR}/vault-storage-migrations"
HELPER_POD="vault-storage-migrator"
BACKUP_POD="vault-storage-backup"
PREPARE_ONLY=0
SKIP_BACKUP=0
TIMEOUT_SECONDS=600

log() {
  printf '[vault-storage-migration] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

cleanup_pods() {
  kubectl delete pod "${HELPER_POD}" -n "${VAULT_NAMESPACE}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete pod "${BACKUP_POD}" -n "${VAULT_NAMESPACE}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

wait_for_pod_phase() {
  local pod="$1"
  local phase="$2"
  local deadline
  deadline=$((SECONDS + TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    local current_phase
    current_phase="$(kubectl get pod "${pod}" -n "${VAULT_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "${current_phase}" == "${phase}" ]]; then
      return 0
    fi
    sleep 3
  done
  printf 'ERROR: pod %s did not reach phase %s within %ss.\n' "${pod}" "${phase}" "${TIMEOUT_SECONDS}" >&2
  return 1
}

wait_for_statefulset_replicas() {
  local replicas="$1"
  local deadline
  deadline=$((SECONDS + TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    local ready_replicas current_replicas
    ready_replicas="$(kubectl get statefulset "${VAULT_STATEFULSET}" -n "${VAULT_NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
    current_replicas="$(kubectl get statefulset "${VAULT_STATEFULSET}" -n "${VAULT_NAMESPACE}" -o jsonpath='{.status.replicas}' 2>/dev/null || true)"
    ready_replicas="${ready_replicas:-0}"
    current_replicas="${current_replicas:-0}"
    if [[ "${ready_replicas}" == "${replicas}" && "${current_replicas}" == "${replicas}" ]]; then
      return 0
    fi
    sleep 3
  done
  printf 'ERROR: statefulset/%s did not converge to %s replicas within %ss.\n' "${VAULT_STATEFULSET}" "${replicas}" "${TIMEOUT_SECONDS}" >&2
  return 1
}

current_storage_type() {
  kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc 'vault status -format=json' 2>/dev/null | jq -r '.storage_type // "unknown"'
}

current_config_storage() {
  kubectl get configmap "${VAULT_CONFIGMAP}" -n "${VAULT_NAMESPACE}" -o jsonpath='{.data.extraconfig-from-values\.hcl}' 2>/dev/null || true
}

desired_values_support_raft() {
  grep -q 'storage "raft"' "${VAULT_VALUES_FILE}"
}

current_vault_image() {
  kubectl get statefulset "${VAULT_STATEFULSET}" -n "${VAULT_NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[?(@.name=="vault")].image}'
}

backup_current_state() {
  local timestamp backup_dir backup_file
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_dir="${BACKUP_ROOT}/${timestamp}"
  backup_file="${backup_dir}/vault-file-backend-pvc.tgz"

  idp_migrate_legacy_state_dir_if_needed
  idp_ensure_state_dir
  mkdir -p "${backup_dir}"
  chmod 700 "${backup_dir}"

  log "Writing host-side migration backup under ${backup_dir}"
  kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc 'vault status -format=json' > "${backup_dir}/vault-status-before.json"
  kubectl get configmap "${VAULT_CONFIGMAP}" -n "${VAULT_NAMESPACE}" -o yaml > "${backup_dir}/vault-configmap-before.yaml"
  helm get values "${VAULT_RELEASE}" -n "${VAULT_NAMESPACE}" -a > "${backup_dir}/vault-helm-values-before.yaml"
  cp "${VAULT_VALUES_FILE}" "${backup_dir}/vault-k3s-values-target.yaml"
  if [[ -f "${VAULT_INIT_FILE}" ]]; then
    cp "${VAULT_INIT_FILE}" "${backup_dir}/k3s-vault-init.json"
    chmod 600 "${backup_dir}/k3s-vault-init.json"
  fi

  kubectl delete pod "${BACKUP_POD}" -n "${VAULT_NAMESPACE}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${BACKUP_POD}
  namespace: ${VAULT_NAMESPACE}
spec:
  restartPolicy: Never
  containers:
    - name: backup
      image: alpine:3.20
      command: ["/bin/sh", "-ec", "sleep 3600"]
      volumeMounts:
        - name: vault-data
          mountPath: /vault/data
  volumes:
    - name: vault-data
      persistentVolumeClaim:
        claimName: data-vault-0
EOF
  wait_for_pod_phase "${BACKUP_POD}" Running
  kubectl exec -n "${VAULT_NAMESPACE}" "${BACKUP_POD}" -- sh -lc 'tar -C /vault/data -czf - .' > "${backup_file}"
  chmod 600 "${backup_file}"
  log "Backup artifact written to ${backup_file}"
  kubectl delete pod "${BACKUP_POD}" -n "${VAULT_NAMESPACE}" --ignore-not-found --wait=true >/dev/null
}

perform_offline_migration() {
  local vault_image
  vault_image="$(current_vault_image)"
  if [[ -z "${vault_image}" ]]; then
    printf 'ERROR: unable to determine current Vault image from statefulset/%s.\n' "${VAULT_STATEFULSET}" >&2
    exit 1
  fi

  log "Scaling Vault down for offline storage migration"
  kubectl scale statefulset "${VAULT_STATEFULSET}" -n "${VAULT_NAMESPACE}" --replicas=0 >/dev/null
  wait_for_statefulset_replicas 0

  kubectl delete pod "${HELPER_POD}" -n "${VAULT_NAMESPACE}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${HELPER_POD}
  namespace: ${VAULT_NAMESPACE}
spec:
  restartPolicy: Never
  containers:
    - name: migrator
      image: ${vault_image}
      command: ["/bin/sh", "-ec", "sleep 3600"]
      volumeMounts:
        - name: vault-data
          mountPath: /vault/data
  volumes:
    - name: vault-data
      persistentVolumeClaim:
        claimName: data-vault-0
EOF
  wait_for_pod_phase "${HELPER_POD}" Running

  log "Rehoming current file-backend data under /vault/data/file-backend"
  kubectl exec -n "${VAULT_NAMESPACE}" "${HELPER_POD}" -- sh -lc '
    mkdir -p /vault/data/file-backend /vault/data/raft
    for entry in /vault/data/* /vault/data/.[!.]* /vault/data/..?*; do
      [ -e "${entry}" ] || continue
      base="$(basename "${entry}")"
      case "${base}" in
        file-backend|raft) continue ;;
      esac
      mv "${entry}" /vault/data/file-backend/
    done
  '

  log "Running Vault offline storage migration from file to Raft"
  kubectl exec -n "${VAULT_NAMESPACE}" "${HELPER_POD}" -- sh -lc '
    cat > /tmp/migrate.hcl <<EOF
storage_source "file" {
  path = "/vault/data/file-backend"
}

storage_destination "raft" {
  path    = "/vault/data/raft"
  node_id = "vault-0"
}

cluster_addr = "https://vault-0.vault-internal:8201"
EOF
    vault operator migrate -config=/tmp/migrate.hcl
  '

  kubectl delete pod "${HELPER_POD}" -n "${VAULT_NAMESPACE}" --ignore-not-found --wait=true >/dev/null
  log "Offline storage migration completed"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prepare-only)
      PREPARE_ONLY=1
      shift
      ;;
    --skip-backup)
      SKIP_BACKUP=1
      shift
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
      if [[ -z "${TIMEOUT_SECONDS}" ]]; then
        printf 'ERROR: --timeout requires a value.\n' >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

trap cleanup_pods EXIT

require_command kubectl
require_command helm
require_command jq

if ! helm status "${VAULT_RELEASE}" -n "${VAULT_NAMESPACE}" >/dev/null 2>&1; then
  log "Vault release is not installed; nothing to migrate."
  exit 0
fi

if ! desired_values_support_raft; then
  printf 'ERROR: %s does not yet declare integrated Raft storage.\n' "${VAULT_VALUES_FILE}" >&2
  exit 1
fi

if [[ ! -f "${VAULT_INIT_FILE}" ]]; then
  printf 'ERROR: required host-side init material is missing at %s.\n' "${VAULT_INIT_FILE}" >&2
  exit 1
fi

ROOT_TOKEN="$(jq -r '.root_token // empty' "${VAULT_INIT_FILE}")"
if [[ -z "${ROOT_TOKEN}" ]]; then
  printf 'ERROR: root_token is missing in %s.\n' "${VAULT_INIT_FILE}" >&2
  exit 1
fi

current_config="$(current_config_storage)"
if grep -q 'storage "raft"' <<<"${current_config}"; then
  log "Vault is already configured for integrated Raft storage."
  exit 0
fi

storage_type="$(current_storage_type)"
if [[ "${storage_type}" != "file" ]]; then
  printf 'ERROR: expected current Vault storage type to be file, found %s.\n' "${storage_type}" >&2
  exit 1
fi

if [[ "${SKIP_BACKUP}" -eq 0 ]]; then
  backup_current_state
fi

perform_offline_migration

if [[ "${PREPARE_ONLY}" -eq 1 ]]; then
  log "Prepare-only mode completed. Run Helm upgrade and bootstrap next."
  exit 0
fi

log "Upgrading Vault release to the integrated Raft storage values"
helm upgrade --install "${VAULT_RELEASE}" hashicorp/vault \
  --namespace "${VAULT_NAMESPACE}" \
  --create-namespace \
  -f "${VAULT_VALUES_FILE}" \
  --wait >/dev/null

log "Re-running Vault bootstrap against the migrated Raft backend"
"${SCRIPT_DIR}/bootstrap-k3s-vault-secrets.sh" --skip-helm >/dev/null

log "Validating post-migration Vault status"
post_storage_type="$(current_storage_type)"
if [[ "${post_storage_type}" != "raft" ]]; then
  printf 'ERROR: expected post-migration Vault storage type to be raft, found %s.\n' "${post_storage_type}" >&2
  exit 1
fi

kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- sh -lc "export VAULT_TOKEN='${ROOT_TOKEN}'; vault operator raft list-peers" >/dev/null
log "Vault is now running on integrated Raft storage."
