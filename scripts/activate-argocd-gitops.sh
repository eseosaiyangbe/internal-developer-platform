#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARGOCD_VERSION="${ARGOCD_VERSION:-v3.3.7}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
ROOT_APPLICATION="${ROOT_DIR}/gitops/argocd/root/internal-developer-platform-dev-root-application.yaml"

log() {
  printf '[idp-gitops] %s\n' "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

require_cmd kubectl

log "Installing ArgoCD ${ARGOCD_VERSION} into namespace ${ARGOCD_NAMESPACE}"
kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "${ARGOCD_NAMESPACE}" --server-side --force-conflicts -f "${INSTALL_URL}"

log "Waiting for ArgoCD pods to become Ready"
kubectl wait --for=condition=Ready pod --all -n "${ARGOCD_NAMESPACE}" --timeout=600s

log "Applying root GitOps application"
kubectl apply -f "${ROOT_APPLICATION}"

log "Waiting for root application object to appear"
kubectl wait --for=create "application/internal-developer-platform-dev-root" -n "${ARGOCD_NAMESPACE}" --timeout=120s

log "Current application status snapshot"
kubectl get application -n "${ARGOCD_NAMESPACE}" -o wide
