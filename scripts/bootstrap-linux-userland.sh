#!/usr/bin/env bash
set -euo pipefail

if [[ "${OSTYPE:-}" != linux* ]]; then
  echo "This script is intended for Linux."
  exit 1
fi

ARCH_RAW="$(uname -m)"
case "${ARCH_RAW}" in
  x86_64|amd64)
    ARCH="amd64"
    NODE_ARCH="x64"
    COMPOSE_ARCH="x86_64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    NODE_ARCH="arm64"
    COMPOSE_ARCH="aarch64"
    ;;
  *)
    echo "Unsupported Linux architecture: ${ARCH_RAW}"
    exit 1
    ;;
esac

LOCAL_BIN="${HOME}/.local/bin"
LOCAL_OPT="${HOME}/.local/opt"
DOCKER_PLUGINS_DIR="${HOME}/.docker/cli-plugins"
AZURE_VENV="${HOME}/.local/venvs/azure-cli"
AWS_VENV="${HOME}/.local/venvs/aws-cli"
PROFILE_FILE="${HOME}/.profile"

mkdir -p "${LOCAL_BIN}" "${LOCAL_OPT}" "${DOCKER_PLUGINS_DIR}" "${HOME}/.local/venvs"

have_sudo() {
  command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1
}

ensure_path_setup() {
  local marker="# DevOps Easy Learning userland tools"
  if ! grep -Fq "${marker}" "${PROFILE_FILE}" 2>/dev/null; then
    cat >> "${PROFILE_FILE}" <<'EOF'

# DevOps Easy Learning userland tools
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.docker/cli-plugins:$PATH"
EOF
  fi
}

sanitize_docker_config() {
  local docker_config="${HOME}/.docker/config.json"
  [[ -f "${docker_config}" ]] || return 0

  python3 - "${docker_config}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
if data.get("credsStore") == "desktop":
    data.pop("credsStore", None)
    path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

download() {
  local url="$1"
  local out="$2"
  rm -f "${out}"
  curl -fsSL "${url}" -o "${out}"
}

github_latest_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name'
}

github_asset_url() {
  local repo="$1"
  local pattern="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | jq -r --arg pattern "${pattern}" '[.assets[]?.browser_download_url | select(test($pattern; "i"))][0] // empty'
}

install_executable() {
  local source_file="$1"
  local target_name="$2"
  install -m 0755 "${source_file}" "${LOCAL_BIN}/${target_name}"
}

install_from_tgz_single_binary() {
  local url="$1"
  local binary_path_inside_tar="$2"
  local target_name="$3"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "${url}" "${tmp_dir}/archive.tgz"
  tar -xzf "${tmp_dir}/archive.tgz" -C "${tmp_dir}"
  install_executable "${tmp_dir}/${binary_path_inside_tar}" "${target_name}"
  trap - RETURN
  rm -rf "${tmp_dir}"
}

install_base_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    if ! have_sudo; then
      echo "apt-based system detected, but passwordless sudo is not available."
      echo "Please install base packages manually: curl jq python3 python3-venv python3-pip unzip tar xz-utils git make ca-certificates"
      return 0
    fi
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl jq python3 python3-venv python3-pip unzip tar xz-utils git make
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    if ! have_sudo; then
      echo "dnf-based system detected, but passwordless sudo is not available."
      echo "Please install base packages manually: curl jq python3 python3-pip unzip tar xz git make ca-certificates"
      return 0
    fi
    sudo dnf install -y ca-certificates curl jq python3 python3-pip unzip tar xz git make
    return 0
  fi

  echo "No supported package manager detected automatically."
  echo "Install these manually before rerunning if anything is missing:"
  echo "  curl jq python3 python3-venv python3-pip unzip tar xz git make ca-certificates"
}

install_docker_engine() {
  if command -v docker >/dev/null 2>&1; then
    return 0
  fi

  if ! have_sudo; then
    echo "Docker is not installed and passwordless sudo is not available."
    echo "Install Docker Engine manually, then rerun this script."
    return 0
  fi

  curl -fsSL https://get.docker.com | sudo sh
  sudo systemctl enable --now docker 2>/dev/null || true
  sudo usermod -aG docker "${USER}" 2>/dev/null || true
}

install_docker_compose_plugin() {
  local url
  url="$(github_asset_url docker/compose "docker-compose-linux-${COMPOSE_ARCH}$")"
  download "${url}" "${DOCKER_PLUGINS_DIR}/docker-compose"
  chmod +x "${DOCKER_PLUGINS_DIR}/docker-compose"
  ln -sf "${DOCKER_PLUGINS_DIR}/docker-compose" "${LOCAL_BIN}/docker-compose"
}

install_docker_buildx_plugin() {
  local url
  url="$(github_asset_url docker/buildx "buildx-v.*\\.linux-${ARCH}$")"
  download "${url}" "${DOCKER_PLUGINS_DIR}/docker-buildx"
  chmod +x "${DOCKER_PLUGINS_DIR}/docker-buildx"
}

install_kubectl() {
  local version
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  download "https://dl.k8s.io/release/${version}/bin/linux/${ARCH}/kubectl" "${LOCAL_BIN}/kubectl"
  chmod +x "${LOCAL_BIN}/kubectl"
}

install_helm() {
  local tag version tmp_dir
  tag="$(github_latest_tag helm/helm)"
  version="${tag#v}"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "https://get.helm.sh/helm-v${version}-linux-${ARCH}.tar.gz" "${tmp_dir}/helm.tgz"
  tar -xzf "${tmp_dir}/helm.tgz" -C "${tmp_dir}"
  install_executable "${tmp_dir}/linux-${ARCH}/helm" helm
  trap - RETURN
  rm -rf "${tmp_dir}"
}

install_kustomize() {
  local url
  url="$(github_asset_url kubernetes-sigs/kustomize "kustomize_v.*_linux_${ARCH}\\.tar\\.gz$")"
  install_from_tgz_single_binary "${url}" "kustomize" kustomize
}

install_kind() {
  local url
  url="$(github_asset_url kubernetes-sigs/kind "kind-linux-${ARCH}$")"
  download "${url}" "${LOCAL_BIN}/kind"
  chmod +x "${LOCAL_BIN}/kind"
}

install_k3d() {
  local url
  url="$(github_asset_url k3d-io/k3d "k3d-linux-${ARCH}$")"
  download "${url}" "${LOCAL_BIN}/k3d"
  chmod +x "${LOCAL_BIN}/k3d"
}

install_yq() {
  local url
  url="$(github_asset_url mikefarah/yq "yq_linux_${ARCH}$")"
  download "${url}" "${LOCAL_BIN}/yq"
  chmod +x "${LOCAL_BIN}/yq"
}

install_cloudflared() {
  local url tmp_dir
  url="$(github_asset_url cloudflare/cloudflared "cloudflared-linux-${ARCH}\\.tgz$")"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "${url}" "${tmp_dir}/cloudflared.tgz"
  tar -xzf "${tmp_dir}/cloudflared.tgz" -C "${tmp_dir}"
  install_executable "${tmp_dir}/cloudflared" cloudflared
  trap - RETURN
  rm -rf "${tmp_dir}"
}

install_argocd() {
  local url
  url="$(github_asset_url argoproj/argo-cd "linux-${ARCH}$")"
  download "${url}" "${LOCAL_BIN}/argocd"
  chmod +x "${LOCAL_BIN}/argocd"
}

install_terraform() {
  local version tmp_dir
  version="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_${ARCH}.zip" "${tmp_dir}/terraform.zip"
  unzip -q "${tmp_dir}/terraform.zip" -d "${tmp_dir}"
  install_executable "${tmp_dir}/terraform" terraform
  trap - RETURN
  rm -rf "${tmp_dir}"
}

install_node() {
  local version tmp_dir node_root
  version="$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version')"
  node_root="${LOCAL_OPT}/node-${version}"
  rm -rf "${node_root}"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "https://nodejs.org/dist/${version}/node-${version}-linux-${NODE_ARCH}.tar.xz" "${tmp_dir}/node.tar.xz"
  tar -xJf "${tmp_dir}/node.tar.xz" -C "${LOCAL_OPT}"
  mv "${LOCAL_OPT}/node-${version}-linux-${NODE_ARCH}" "${node_root}"
  ln -sf "${node_root}/bin/node" "${LOCAL_BIN}/node"
  ln -sf "${node_root}/bin/npm" "${LOCAL_BIN}/npm"
  ln -sf "${node_root}/bin/npx" "${LOCAL_BIN}/npx"
  if [[ -x "${node_root}/bin/corepack" ]]; then
    ln -sf "${node_root}/bin/corepack" "${LOCAL_BIN}/corepack"
  fi
  trap - RETURN
  rm -rf "${tmp_dir}"
}

install_awscli() {
  python3 -m venv "${AWS_VENV}"
  "${AWS_VENV}/bin/pip" install --upgrade pip
  "${AWS_VENV}/bin/pip" install --upgrade awscli
  ln -sf "${AWS_VENV}/bin/aws" "${LOCAL_BIN}/aws"
}

install_azure_cli() {
  python3 -m venv "${AZURE_VENV}"
  "${AZURE_VENV}/bin/pip" install --upgrade pip
  "${AZURE_VENV}/bin/pip" install --upgrade azure-cli
  ln -sf "${AZURE_VENV}/bin/az" "${LOCAL_BIN}/az"
}

main() {
  ensure_path_setup
  sanitize_docker_config
  install_base_packages

  echo "Installing Docker Engine and Compose tooling..."
  install_docker_engine
  install_docker_compose_plugin
  install_docker_buildx_plugin

  echo "Installing Kubernetes and platform tooling..."
  install_kubectl
  install_helm
  install_kustomize
  install_kind
  install_k3d
  install_argocd

  echo "Installing infrastructure and helper tooling..."
  install_terraform
  install_node
  install_awscli
  install_yq
  install_cloudflared

  echo "Installing Azure CLI into a local virtual environment..."
  install_azure_cli

  cat <<'EOF'

Bootstrap complete.

Next shell setup:
  source ~/.profile

Docker on Linux:
  If Docker was installed during this run, you may need to log out and back in
  before `docker` works without sudo because group membership changes do not
  apply to the current shell automatically.

Verification:
  docker version
  docker compose version
  kubectl version --client
  helm version
  terraform version
  node --version
  npm --version
  aws --version
  az version
EOF
}

main "$@"
