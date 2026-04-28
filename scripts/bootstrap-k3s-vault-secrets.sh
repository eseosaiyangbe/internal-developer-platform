#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-k3s-vault-secrets.sh [options]

Install or reconcile the shared k3s Vault and External Secrets platform,
configure Vault Kubernetes auth, and seed workspace secrets for MemFlip and SwiftPay.

Options:
  --rotate-secrets  Overwrite existing seeded app secrets in Vault
  --skip-helm       Reuse existing Vault and External Secrets installations
  -h, --help        Show this help message
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/devops-easy-learning"
VAULT_INIT_FILE="${STATE_DIR}/k3s-vault-init.json"
VALUES_FILE="${ROOT_DIR}/scripts/vault-k3s-values.yaml"
ROTATE_SECRETS=0
SKIP_HELM=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rotate-secrets)
      ROTATE_SECRETS=1
      shift
      ;;
    --skip-helm)
      SKIP_HELM=1
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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  fi
}

vault_exec() {
  kubectl exec -n vault vault-0 -- sh -lc "$1"
}

vault_exec_with_token() {
  local command="$1"
  vault_exec "export VAULT_TOKEN='${ROOT_TOKEN}'; ${command}"
}

write_policy() {
  local name="$1"
  local rules="$2"
  printf '%s\n' "$rules" | kubectl exec -i -n vault vault-0 -- sh -lc \
    "export VAULT_TOKEN='${ROOT_TOKEN}'; vault policy write '${name}' - >/dev/null"
}

ensure_vault_path() {
  local path="$1"
  local command="$2"

  if [[ "$ROTATE_SECRETS" -eq 0 ]] && vault_exec_with_token "vault kv get '${path}' >/dev/null 2>&1"; then
    echo "[vault-bootstrap] Reusing existing secret at ${path}"
    return 0
  fi

  echo "[vault-bootstrap] Writing secret at ${path}"
  vault_exec_with_token "${command}"
}

require_command kubectl
require_command helm
require_command jq
require_command openssl

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

if [[ "$SKIP_HELM" -eq 0 ]]; then
  echo "[vault-bootstrap] Installing or upgrading Vault"
  helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null 2>&1 || true
  helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
  helm repo update >/dev/null

  helm upgrade --install vault hashicorp/vault \
    --namespace vault \
    --create-namespace \
    -f "$VALUES_FILE" \
    --wait >/dev/null

  echo "[vault-bootstrap] Installing or upgrading External Secrets Operator"
  helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace \
    --wait >/dev/null
fi

kubectl wait --for=condition=Established crd/externalsecrets.external-secrets.io --timeout=180s >/dev/null
kubectl wait --for=condition=Established crd/secretstores.external-secrets.io --timeout=180s >/dev/null
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-0 -n vault --timeout=300s >/dev/null

status_json="$(vault_exec 'vault status -format=json || true')"
if [[ -z "$status_json" ]]; then
  echo "ERROR: Vault status could not be retrieved from the cluster." >&2
  exit 1
fi

initialized="$(printf '%s' "$status_json" | jq -r '.initialized')"
sealed="$(printf '%s' "$status_json" | jq -r '.sealed')"

if [[ "$initialized" == "false" ]]; then
  echo "[vault-bootstrap] Initializing cluster Vault"
  init_json="$(vault_exec 'vault operator init -key-shares=1 -key-threshold=1 -format=json')"
  umask 077
  printf '%s\n' "$init_json" > "$VAULT_INIT_FILE"
  initialized="true"
  sealed="$(printf '%s' "$init_json" | jq -r '.sealed // "true"')"
fi

if [[ ! -f "$VAULT_INIT_FILE" ]]; then
  echo "ERROR: Vault is already initialized but ${VAULT_INIT_FILE} is missing." >&2
  echo "Restore the init file or re-bootstrap Vault intentionally before continuing." >&2
  exit 1
fi

ROOT_TOKEN="$(jq -r '.root_token' "$VAULT_INIT_FILE")"
UNSEAL_KEY="$(jq -r '.unseal_keys_b64[0]' "$VAULT_INIT_FILE")"

status_json="$(vault_exec 'vault status -format=json || true')"
sealed="$(printf '%s' "$status_json" | jq -r '.sealed')"
if [[ "$sealed" == "true" ]]; then
  echo "[vault-bootstrap] Unsealing cluster Vault"
  vault_exec "vault operator unseal '${UNSEAL_KEY}' >/dev/null"
fi

echo "[vault-bootstrap] Enabling Vault engines and Kubernetes auth"
vault_exec_with_token "vault secrets enable -path=kv kv-v2 >/dev/null 2>&1 || true"
vault_exec_with_token "vault auth enable kubernetes >/dev/null 2>&1 || true"
vault_exec_with_token 'vault write auth/kubernetes/config kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT" >/dev/null'

write_policy "memflip-dev" 'path "kv/data/devops-easy-learning/memflip/dev/*" { capabilities = ["read"] }'
write_policy "memflip-prod" 'path "kv/data/devops-easy-learning/memflip/prod/*" { capabilities = ["read"] }'
write_policy "swiftpay-dev" 'path "kv/data/devops-easy-learning/swiftpay/dev/*" { capabilities = ["read"] }'
write_policy "swiftpay-prod" 'path "kv/data/devops-easy-learning/swiftpay/prod/*" { capabilities = ["read"] }'

echo "[vault-bootstrap] Configuring Vault Kubernetes roles"
vault_exec_with_token "vault write auth/kubernetes/role/memflip-dev bound_service_account_names=memflip-vault-reader bound_service_account_namespaces=memflip-dev audience=vault token_policies=memflip-dev ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/memflip-prod bound_service_account_names=memflip-vault-reader bound_service_account_namespaces=memflip-prod audience=vault token_policies=memflip-prod ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/swiftpay-dev bound_service_account_names=swiftpay-vault-reader bound_service_account_namespaces=swiftpay-dev audience=vault token_policies=swiftpay-dev ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/swiftpay-prod bound_service_account_names=swiftpay-vault-reader bound_service_account_namespaces=swiftpay-prod audience=vault token_policies=swiftpay-prod ttl=1h >/dev/null"

MEMFLIP_DEV_DB_PASSWORD="gamepass123"
MEMFLIP_DEV_REDIS_PASSWORD="gamepass123"
MEMFLIP_DEV_JWT_SECRET="memflip-dev-jwt-change-before-shared-dev"

SWIFTPAY_DEV_DB_USER="swiftpay"
SWIFTPAY_DEV_DB_PASSWORD="swiftpay123"
SWIFTPAY_DEV_DB_HOST="postgres"
SWIFTPAY_DEV_DB_PORT="5432"
SWIFTPAY_DEV_REDIS_URL="redis://redis:6379"
SWIFTPAY_DEV_RABBITMQ_USER="swiftpay"
SWIFTPAY_DEV_RABBITMQ_PASSWORD="swiftpay123"
SWIFTPAY_DEV_RABBITMQ_URL="amqp://swiftpay:swiftpay123@rabbitmq:5672"
SWIFTPAY_DEV_JWT_SECRET="J8vmoWX/NIIcBunMHhkMmok7ZViKS/OaQovGmp9ETm2+puxFEL/lt+egqTNRLM3J"

MEMFLIP_PROD_DB_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
MEMFLIP_PROD_REDIS_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
MEMFLIP_PROD_JWT_SECRET="$(openssl rand -base64 32 | tr -d '\n')"

SWIFTPAY_PROD_DB_USER="swiftpay"
SWIFTPAY_PROD_DB_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
SWIFTPAY_PROD_DB_HOST="swiftpay-postgres-rw.prod.internal"
SWIFTPAY_PROD_DB_PORT="5432"
SWIFTPAY_PROD_REDIS_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
SWIFTPAY_PROD_RABBITMQ_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
SWIFTPAY_PROD_JWT_SECRET="$(openssl rand -base64 32 | tr -d '\n')"
SWIFTPAY_PROD_REDIS_URL="rediss://:${SWIFTPAY_PROD_REDIS_PASSWORD}@swiftpay-redis.prod.internal:6380"
SWIFTPAY_PROD_RABBITMQ_USER="swiftpay"
SWIFTPAY_PROD_RABBITMQ_URL="amqps://swiftpay:${SWIFTPAY_PROD_RABBITMQ_PASSWORD}@swiftpay-rabbitmq.prod.internal:5671"

ensure_vault_path "kv/devops-easy-learning/memflip/dev/app" \
  "vault kv put kv/devops-easy-learning/memflip/dev/app DB_PASSWORD='${MEMFLIP_DEV_DB_PASSWORD}' REDIS_PASSWORD='${MEMFLIP_DEV_REDIS_PASSWORD}' JWT_SECRET='${MEMFLIP_DEV_JWT_SECRET}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/memflip/prod/app" \
  "vault kv put kv/devops-easy-learning/memflip/prod/app DB_PASSWORD='${MEMFLIP_PROD_DB_PASSWORD}' REDIS_PASSWORD='${MEMFLIP_PROD_REDIS_PASSWORD}' JWT_SECRET='${MEMFLIP_PROD_JWT_SECRET}' >/dev/null"

ensure_vault_path "kv/devops-easy-learning/swiftpay/dev/postgres" \
  "vault kv put kv/devops-easy-learning/swiftpay/dev/postgres DB_USER='${SWIFTPAY_DEV_DB_USER}' DB_PASSWORD='${SWIFTPAY_DEV_DB_PASSWORD}' DB_HOST='${SWIFTPAY_DEV_DB_HOST}' DB_PORT='${SWIFTPAY_DEV_DB_PORT}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/swiftpay/dev/redis" \
  "vault kv put kv/devops-easy-learning/swiftpay/dev/redis REDIS_URL='${SWIFTPAY_DEV_REDIS_URL}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/swiftpay/dev/rabbitmq" \
  "vault kv put kv/devops-easy-learning/swiftpay/dev/rabbitmq RABBITMQ_USER='${SWIFTPAY_DEV_RABBITMQ_USER}' RABBITMQ_PASSWORD='${SWIFTPAY_DEV_RABBITMQ_PASSWORD}' RABBITMQ_URL='${SWIFTPAY_DEV_RABBITMQ_URL}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/swiftpay/dev/app" \
  "vault kv put kv/devops-easy-learning/swiftpay/dev/app JWT_SECRET='${SWIFTPAY_DEV_JWT_SECRET}' >/dev/null"

ensure_vault_path "kv/devops-easy-learning/swiftpay/prod/postgres" \
  "vault kv put kv/devops-easy-learning/swiftpay/prod/postgres DB_USER='${SWIFTPAY_PROD_DB_USER}' DB_PASSWORD='${SWIFTPAY_PROD_DB_PASSWORD}' DB_HOST='${SWIFTPAY_PROD_DB_HOST}' DB_PORT='${SWIFTPAY_PROD_DB_PORT}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/swiftpay/prod/redis" \
  "vault kv put kv/devops-easy-learning/swiftpay/prod/redis REDIS_URL='${SWIFTPAY_PROD_REDIS_URL}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/swiftpay/prod/rabbitmq" \
  "vault kv put kv/devops-easy-learning/swiftpay/prod/rabbitmq RABBITMQ_USER='${SWIFTPAY_PROD_RABBITMQ_USER}' RABBITMQ_PASSWORD='${SWIFTPAY_PROD_RABBITMQ_PASSWORD}' RABBITMQ_URL='${SWIFTPAY_PROD_RABBITMQ_URL}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/swiftpay/prod/app" \
  "vault kv put kv/devops-easy-learning/swiftpay/prod/app JWT_SECRET='${SWIFTPAY_PROD_JWT_SECRET}' >/dev/null"

echo "[vault-bootstrap] Vault and External Secrets platform is ready"
echo "[vault-bootstrap] Init material stored at ${VAULT_INIT_FILE}"
