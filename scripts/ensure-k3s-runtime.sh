#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/devops-easy-learning"
VAULT_INIT_FILE="${STATE_DIR}/k3s-vault-init.json"

have_sudo() {
  command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1
}

tune_inotify_limits_linux() {
  have_sudo || return 0

  sudo tee /etc/sysctl.d/90-devops-easy-learning-k3s.conf >/dev/null <<'EOF'
fs.inotify.max_user_instances = 1024
fs.inotify.max_user_watches = 1048576
fs.inotify.max_queued_events = 32768
EOF
  sudo sysctl --system >/dev/null
}

tune_inotify_limits_colima() {
  colima ssh -- sudo tee /etc/sysctl.d/90-devops-easy-learning-k3s.conf >/dev/null <<'EOF'
fs.inotify.max_user_instances = 1024
fs.inotify.max_user_watches = 1048576
fs.inotify.max_queued_events = 32768
EOF
  colima ssh -- sudo sysctl --system >/dev/null
}

ensure_traefik_with_helm() {
  command -v helm >/dev/null 2>&1 || {
    echo "Helm is required to install Traefik for the local k3s runtime."
    return 1
  }

  helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
  helm repo update >/dev/null

  if kubectl get deployment traefik -n traefik >/dev/null 2>&1; then
    helm upgrade --install traefik traefik/traefik \
      --namespace traefik \
      --create-namespace \
      --set service.type=LoadBalancer \
      --set ingressClass.enabled=true \
      --set ingressClass.isDefaultClass=true >/dev/null
  else
    helm upgrade --install traefik traefik/traefik \
      --namespace traefik \
      --create-namespace \
      --set service.type=LoadBalancer \
      --set ingressClass.enabled=true \
      --set ingressClass.isDefaultClass=true >/dev/null
  fi

  kubectl rollout status deployment/traefik -n traefik --timeout=180s >/dev/null
}

reconcile_shared_vault_platform() {
  if [[ ! -f "${VAULT_INIT_FILE}" ]]; then
    return 0
  fi

  if ! kubectl get namespace vault >/dev/null 2>&1; then
    return 0
  fi

  if ! kubectl get namespace external-secrets >/dev/null 2>&1; then
    return 0
  fi

  echo "Reconciling shared Vault and External Secrets platform..."
  "${SCRIPT_DIR}/bootstrap-k3s-vault-secrets.sh" --skip-helm >/dev/null
}

ensure_macos_k3s() {
  command -v colima >/dev/null 2>&1 || {
    echo "Colima is required for the macOS k3s runtime."
    return 1
  }
  command -v kubectl >/dev/null 2>&1 || {
    echo "kubectl is required for the macOS k3s runtime."
    return 1
  }

  colima start --runtime docker --cpu 4 --memory 8 --disk 60 --kubernetes --network-address >/dev/null
  tune_inotify_limits_colima
  kubectl config use-context colima >/dev/null 2>&1 || true
  kubectl get nodes >/dev/null
  ensure_traefik_with_helm
}

ensure_linux_k3s() {
  command -v kubectl >/dev/null 2>&1 || {
    echo "kubectl is required for the Linux k3s runtime."
    return 1
  }

  if ! command -v k3s >/dev/null 2>&1; then
    if ! have_sudo; then
      echo "k3s is not installed and passwordless sudo is unavailable."
      echo "Install k3s manually with the official installer, then rerun this script."
      return 0
    fi
    curl -sfL https://get.k3s.io | sudo sh - >/dev/null
  fi

  if have_sudo; then
    sudo systemctl enable --now k3s >/dev/null 2>&1 || true
    mkdir -p "${HOME}/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/config"
    sudo chown "${USER}":"$(id -gn)" "${HOME}/.kube/config"
  fi

  export KUBECONFIG="${HOME}/.kube/config"
  tune_inotify_limits_linux
  kubectl get nodes >/dev/null
  ensure_traefik_with_helm
}

main() {
  local ingress_address

  case "${OSTYPE:-}" in
    darwin*)
      ensure_macos_k3s
      ;;
    linux*)
      ensure_linux_k3s
      ;;
    *)
      echo "Unsupported OS for local k3s runtime bootstrap: ${OSTYPE:-unknown}"
      exit 1
      ;;
  esac

  echo "k3s runtime is ready."
  kubectl config current-context
  kubectl get nodes

  reconcile_shared_vault_platform

  ingress_address="$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  if [[ -z "${ingress_address}" ]]; then
    ingress_address="$(kubectl get svc traefik -n traefik -o jsonpath='{.spec.externalIPs[0]}' 2>/dev/null || true)"
  fi

  if [[ -n "${ingress_address}" ]]; then
    echo "Traefik ingress address: ${ingress_address}"
  else
    echo "Traefik ingress address is not yet assigned."
  fi
}

main "$@"
