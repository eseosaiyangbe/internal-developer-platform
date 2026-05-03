#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/install-cert-manager.sh --email EMAIL [options]

Install cert-manager into the current Kubernetes context and apply the shared
Let's Encrypt ClusterIssuer manifests for this workspace.

Options:
  --email EMAIL      ACME registration email for both staging and prod issuers
  --namespace NAME   cert-manager namespace (default: cert-manager)
  --chart-version V  cert-manager chart version (default: v1.18.2)
  --skip-install     Do not install/upgrade the Helm release; only apply issuers
  -h, --help         Show this help message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CERT_MANAGER_NAMESPACE="cert-manager"
CERT_MANAGER_CHART_VERSION="v1.18.2"
ACME_EMAIL=""
SKIP_INSTALL="false"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}

trap cleanup EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email)
      ACME_EMAIL="${2:?Missing email value}"
      shift 2
      ;;
    --namespace)
      CERT_MANAGER_NAMESPACE="${2:?Missing namespace value}"
      shift 2
      ;;
    --chart-version)
      CERT_MANAGER_CHART_VERSION="${2:?Missing chart version value}"
      shift 2
      ;;
    --skip-install)
      SKIP_INSTALL="true"
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

if [[ -z "${ACME_EMAIL}" ]]; then
  echo "ERROR: --email is required." >&2
  usage
  exit 1
fi

require_command kubectl
require_command helm

if [[ "${SKIP_INSTALL}" != "true" ]]; then
  helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
  helm repo update >/dev/null

  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace "${CERT_MANAGER_NAMESPACE}" \
    --create-namespace \
    --version "${CERT_MANAGER_CHART_VERSION}" \
    --set crds.enabled=true >/dev/null

  kubectl rollout status deployment/cert-manager -n "${CERT_MANAGER_NAMESPACE}" --timeout=180s >/dev/null
  kubectl rollout status deployment/cert-manager-cainjector -n "${CERT_MANAGER_NAMESPACE}" --timeout=180s >/dev/null
  kubectl rollout status deployment/cert-manager-webhook -n "${CERT_MANAGER_NAMESPACE}" --timeout=180s >/dev/null
fi

cp "${ROOT_DIR}/k8s/platform/cert-manager/clusterissuer-letsencrypt-staging.yaml" "${TMP_DIR}/clusterissuer-letsencrypt-staging.yaml"
cp "${ROOT_DIR}/k8s/platform/cert-manager/clusterissuer-letsencrypt-prod.yaml" "${TMP_DIR}/clusterissuer-letsencrypt-prod.yaml"

sed -i.bak "s/platform@example.com/${ACME_EMAIL}/g" "${TMP_DIR}/clusterissuer-letsencrypt-staging.yaml" "${TMP_DIR}/clusterissuer-letsencrypt-prod.yaml"
rm -f "${TMP_DIR}"/*.bak

kubectl apply -f "${TMP_DIR}/clusterissuer-letsencrypt-staging.yaml" >/dev/null
kubectl apply -f "${TMP_DIR}/clusterissuer-letsencrypt-prod.yaml" >/dev/null

echo "cert-manager install path is ready."
echo "Namespace: ${CERT_MANAGER_NAMESPACE}"
echo "ClusterIssuers applied:"
echo "  - letsencrypt-staging"
echo "  - letsencrypt-prod"
