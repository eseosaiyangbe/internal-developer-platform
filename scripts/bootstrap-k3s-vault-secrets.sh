#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-k3s-vault-secrets.sh [options]

Install or reconcile the shared k3s Vault and External Secrets platform,
configure Vault Kubernetes auth, and seed workspace secrets for the migrated
workspace applications.

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

  if [[ "$ROTATE_SECRETS" -eq 0 ]] && vault_exec_with_token "vault kv get '${path}' >/dev/null 2>&1" >/dev/null 2>&1; then
    echo "[vault-bootstrap] Reusing existing secret at ${path}"
    return 0
  fi

  echo "[vault-bootstrap] Writing secret at ${path}"
  vault_exec_with_token "${command}" >/dev/null
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
write_policy "foodpulse-dev" 'path "kv/data/devops-easy-learning/foodpulse/dev/*" { capabilities = ["read"] }'
write_policy "foodpulse-prod" 'path "kv/data/devops-easy-learning/foodpulse/prod/*" { capabilities = ["read"] }'
write_policy "opensis-dev" 'path "kv/data/devops-easy-learning/opensis/dev/*" { capabilities = ["read"] }'
write_policy "opensis-prod" 'path "kv/data/devops-easy-learning/opensis/prod/*" { capabilities = ["read"] }'
write_policy "observability-dev" 'path "kv/data/devops-easy-learning/observability/dev/*" { capabilities = ["read"] }'
write_policy "observability-prod" 'path "kv/data/devops-easy-learning/observability/prod/*" { capabilities = ["read"] }'

echo "[vault-bootstrap] Configuring Vault Kubernetes roles"
vault_exec_with_token "vault write auth/kubernetes/role/memflip-dev bound_service_account_names=memflip-vault-reader bound_service_account_namespaces=memflip-dev audience=vault token_policies=memflip-dev ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/memflip-prod bound_service_account_names=memflip-vault-reader bound_service_account_namespaces=memflip-prod audience=vault token_policies=memflip-prod ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/swiftpay-dev bound_service_account_names=swiftpay-vault-reader bound_service_account_namespaces=swiftpay-dev audience=vault token_policies=swiftpay-dev ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/swiftpay-prod bound_service_account_names=swiftpay-vault-reader bound_service_account_namespaces=swiftpay-prod audience=vault token_policies=swiftpay-prod ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/foodpulse-dev bound_service_account_names=foodpulse-vault-reader bound_service_account_namespaces=foodpulse-dev audience=vault token_policies=foodpulse-dev ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/foodpulse-prod bound_service_account_names=foodpulse-vault-reader bound_service_account_namespaces=foodpulse-prod audience=vault token_policies=foodpulse-prod ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/opensis-dev bound_service_account_names=opensis-vault-reader bound_service_account_namespaces=opensis-dev audience=vault token_policies=opensis-dev ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/opensis-prod bound_service_account_names=opensis-vault-reader bound_service_account_namespaces=opensis-prod audience=vault token_policies=opensis-prod ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/observability-dev bound_service_account_names=observability-vault-reader bound_service_account_namespaces=platform-observability-dev audience=vault token_policies=observability-dev ttl=1h >/dev/null"
vault_exec_with_token "vault write auth/kubernetes/role/observability-prod bound_service_account_names=observability-vault-reader bound_service_account_namespaces=platform-observability-prod audience=vault token_policies=observability-prod ttl=1h >/dev/null"

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
FOODPULSE_DEV_DB_USER="foodpulse"
FOODPULSE_DEV_DB_PASSWORD="change-me"
FOODPULSE_DEV_REDIS_PASSWORD="admin"
FOODPULSE_DEV_REDIS_SENTINEL_PASSWORD="admin"
OPENSIS_DEV_DB_HOST="opensis-db"
OPENSIS_DEV_DB_PORT="3306"
OPENSIS_DEV_DB_NAME="opensis"
OPENSIS_DEV_DB_USER="opensis"
OPENSIS_DEV_DB_PASSWORD="opensis123"
OPENSIS_DEV_DB_ROOT_PASSWORD="opensis-root-123"
OBSERVABILITY_DEV_DB_USER="observability_app"
OBSERVABILITY_DEV_DB_PASSWORD="observability_dev_password"
OBSERVABILITY_DEV_DB_NAME="observability_dev"
OBSERVABILITY_DEV_NEXTAUTH_SECRET="observability-dev-nextauth-change-before-shared-dev"
OBSERVABILITY_DEV_GRAFANA_ADMIN_USER="admin"
OBSERVABILITY_DEV_GRAFANA_ADMIN_PASSWORD="admin"

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
FOODPULSE_PROD_DB_USER="foodpulse"
FOODPULSE_PROD_DB_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
FOODPULSE_PROD_REDIS_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
FOODPULSE_PROD_REDIS_SENTINEL_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
OPENSIS_PROD_DB_HOST="opensis-db"
OPENSIS_PROD_DB_PORT="3306"
OPENSIS_PROD_DB_NAME="opensis"
OPENSIS_PROD_DB_USER="opensis"
OPENSIS_PROD_DB_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
OPENSIS_PROD_DB_ROOT_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
OBSERVABILITY_PROD_DB_USER="observability_app"
OBSERVABILITY_PROD_DB_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
OBSERVABILITY_PROD_DB_NAME="observability_prod"
OBSERVABILITY_PROD_NEXTAUTH_SECRET="$(openssl rand -base64 32 | tr -d '\n')"
OBSERVABILITY_PROD_GRAFANA_ADMIN_USER="admin"
OBSERVABILITY_PROD_GRAFANA_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"

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
ensure_vault_path "kv/devops-easy-learning/foodpulse/dev/postgres" \
  "vault kv put kv/devops-easy-learning/foodpulse/dev/postgres username='${FOODPULSE_DEV_DB_USER}' password='${FOODPULSE_DEV_DB_PASSWORD}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/foodpulse/dev/app" \
  "vault kv put kv/devops-easy-learning/foodpulse/dev/app FOODPULSE_DB_PASSWORD='${FOODPULSE_DEV_DB_PASSWORD}' FOODPULSE_REDIS_PASSWORD='${FOODPULSE_DEV_REDIS_PASSWORD}' FOODPULSE_REDIS_SENTINEL_PASSWORD='${FOODPULSE_DEV_REDIS_SENTINEL_PASSWORD}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/foodpulse/prod/postgres" \
  "vault kv put kv/devops-easy-learning/foodpulse/prod/postgres username='${FOODPULSE_PROD_DB_USER}' password='${FOODPULSE_PROD_DB_PASSWORD}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/foodpulse/prod/app" \
  "vault kv put kv/devops-easy-learning/foodpulse/prod/app FOODPULSE_DB_PASSWORD='${FOODPULSE_PROD_DB_PASSWORD}' FOODPULSE_REDIS_PASSWORD='${FOODPULSE_PROD_REDIS_PASSWORD}' FOODPULSE_REDIS_SENTINEL_PASSWORD='${FOODPULSE_PROD_REDIS_SENTINEL_PASSWORD}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/opensis/dev/app" \
  "vault kv put kv/devops-easy-learning/opensis/dev/app DB_HOST='${OPENSIS_DEV_DB_HOST}' DB_PORT='${OPENSIS_DEV_DB_PORT}' MYSQL_DATABASE='${OPENSIS_DEV_DB_NAME}' MYSQL_USER='${OPENSIS_DEV_DB_USER}' MYSQL_PASSWORD='${OPENSIS_DEV_DB_PASSWORD}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/opensis/dev/db" \
  "vault kv put kv/devops-easy-learning/opensis/dev/db MYSQL_ROOT_PASSWORD='${OPENSIS_DEV_DB_ROOT_PASSWORD}' MYSQL_DATABASE='${OPENSIS_DEV_DB_NAME}' MYSQL_USER='${OPENSIS_DEV_DB_USER}' MYSQL_PASSWORD='${OPENSIS_DEV_DB_PASSWORD}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/opensis/prod/app" \
  "vault kv put kv/devops-easy-learning/opensis/prod/app DB_HOST='${OPENSIS_PROD_DB_HOST}' DB_PORT='${OPENSIS_PROD_DB_PORT}' MYSQL_DATABASE='${OPENSIS_PROD_DB_NAME}' MYSQL_USER='${OPENSIS_PROD_DB_USER}' MYSQL_PASSWORD='${OPENSIS_PROD_DB_PASSWORD}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/opensis/prod/db" \
  "vault kv put kv/devops-easy-learning/opensis/prod/db MYSQL_ROOT_PASSWORD='${OPENSIS_PROD_DB_ROOT_PASSWORD}' MYSQL_DATABASE='${OPENSIS_PROD_DB_NAME}' MYSQL_USER='${OPENSIS_PROD_DB_USER}' MYSQL_PASSWORD='${OPENSIS_PROD_DB_PASSWORD}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/observability/dev/postgres" \
  "vault kv put kv/devops-easy-learning/observability/dev/postgres username='${OBSERVABILITY_DEV_DB_USER}' password='${OBSERVABILITY_DEV_DB_PASSWORD}' database='${OBSERVABILITY_DEV_DB_NAME}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/observability/dev/ui" \
  "vault kv put kv/devops-easy-learning/observability/dev/ui NEXTAUTH_SECRET='${OBSERVABILITY_DEV_NEXTAUTH_SECRET}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/observability/dev/grafana" \
  "vault kv put kv/devops-easy-learning/observability/dev/grafana admin_user='${OBSERVABILITY_DEV_GRAFANA_ADMIN_USER}' admin_password='${OBSERVABILITY_DEV_GRAFANA_ADMIN_PASSWORD}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/observability/prod/postgres" \
  "vault kv put kv/devops-easy-learning/observability/prod/postgres username='${OBSERVABILITY_PROD_DB_USER}' password='${OBSERVABILITY_PROD_DB_PASSWORD}' database='${OBSERVABILITY_PROD_DB_NAME}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/observability/prod/ui" \
  "vault kv put kv/devops-easy-learning/observability/prod/ui NEXTAUTH_SECRET='${OBSERVABILITY_PROD_NEXTAUTH_SECRET}' >/dev/null"
ensure_vault_path "kv/devops-easy-learning/observability/prod/grafana" \
  "vault kv put kv/devops-easy-learning/observability/prod/grafana admin_user='${OBSERVABILITY_PROD_GRAFANA_ADMIN_USER}' admin_password='${OBSERVABILITY_PROD_GRAFANA_ADMIN_PASSWORD}' >/dev/null"

echo "[vault-bootstrap] Vault and External Secrets platform is ready"
echo "[vault-bootstrap] Init material stored at ${VAULT_INIT_FILE}"
