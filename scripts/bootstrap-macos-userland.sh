#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${OSTYPE:-}" != darwin* ]]; then
  echo "This script is intended for macOS."
  exit 1
fi

ARCH="$(uname -m)"
if [[ "${ARCH}" != "arm64" ]]; then
  echo "This script currently supports Apple Silicon only."
  exit 1
fi

LOCAL_BIN="${HOME}/.local/bin"
LOCAL_OPT="${HOME}/.local/opt"
LOCAL_SHARE="${HOME}/.local/share"
DOCKER_PLUGINS_DIR="${HOME}/.docker/cli-plugins"
AZURE_VENV="${HOME}/.local/venvs/azure-cli"
AWS_VENV="${HOME}/.local/venvs/aws-cli"
ZPROFILE="${HOME}/.zprofile"

mkdir -p "${LOCAL_BIN}" "${LOCAL_OPT}" "${LOCAL_SHARE}" "${DOCKER_PLUGINS_DIR}" "${HOME}/.local/venvs"

ensure_path_setup() {
  local marker="# DevOps Easy Learning userland tools"
  if ! grep -Fq "${marker}" "${ZPROFILE}" 2>/dev/null; then
    cat >> "${ZPROFILE}" <<'EOF'

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

install_kubectl() {
  local version
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  download "https://dl.k8s.io/release/${version}/bin/darwin/arm64/kubectl" "${LOCAL_BIN}/kubectl"
  chmod +x "${LOCAL_BIN}/kubectl"
}

install_helm() {
  local tag version tmp_dir
  tag="$(github_latest_tag helm/helm)"
  version="${tag#v}"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "https://get.helm.sh/helm-v${version}-darwin-arm64.tar.gz" "${tmp_dir}/helm.tgz"
  tar -xzf "${tmp_dir}/helm.tgz" -C "${tmp_dir}"
  install_executable "${tmp_dir}/darwin-arm64/helm" helm
  trap - RETURN
  rm -rf "${tmp_dir}"
}

install_promtool() {
  local tag version tmp_dir archive_root
  tag="$(github_latest_tag prometheus/prometheus)"
  version="${tag#v}"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "https://github.com/prometheus/prometheus/releases/download/${tag}/prometheus-${version}.darwin-arm64.tar.gz" "${tmp_dir}/prometheus.tgz"
  tar -xzf "${tmp_dir}/prometheus.tgz" -C "${tmp_dir}"
  archive_root="${tmp_dir}/prometheus-${version}.darwin-arm64"
  install_executable "${archive_root}/promtool" promtool
  trap - RETURN
  rm -rf "${tmp_dir}"
}

install_kustomize() {
  local url
  url="$(github_asset_url kubernetes-sigs/kustomize 'kustomize_v.*_darwin_arm64\.tar\.gz$')"
  install_from_tgz_single_binary "${url}" "kustomize" kustomize
}

install_kind() {
  local url
  url="$(github_asset_url kubernetes-sigs/kind 'darwin-arm64$')"
  download "${url}" "${LOCAL_BIN}/kind"
  chmod +x "${LOCAL_BIN}/kind"
}

install_yq() {
  local url
  url="$(github_asset_url mikefarah/yq 'yq_darwin_arm64$')"
  download "${url}" "${LOCAL_BIN}/yq"
  chmod +x "${LOCAL_BIN}/yq"
}

install_cloudflared() {
  local url tmp_dir
  url="$(github_asset_url cloudflare/cloudflared 'darwin-arm64\.tgz$')"
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
  url="$(github_asset_url argoproj/argo-cd 'darwin-arm64$')"
  download "${url}" "${LOCAL_BIN}/argocd"
  chmod +x "${LOCAL_BIN}/argocd"
}

install_terraform() {
  local version tmp_dir
  version="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_darwin_arm64.zip" "${tmp_dir}/terraform.zip"
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
  download "https://nodejs.org/dist/${version}/node-${version}-darwin-arm64.tar.gz" "${tmp_dir}/node.tgz"
  tar -xzf "${tmp_dir}/node.tgz" -C "${LOCAL_OPT}"
  mv "${LOCAL_OPT}/node-${version}-darwin-arm64" "${node_root}"
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

install_lima() {
  local url tmp_dir lima_root
  url="$(github_asset_url lima-vm/lima 'lima-.*-Darwin-arm64\.tar\.gz$')"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "${url}" "${tmp_dir}/lima.tgz"
  tar -xzf "${tmp_dir}/lima.tgz" -C "${tmp_dir}"
  lima_root="${LOCAL_OPT}/lima"
  rm -rf "${lima_root}"
  mkdir -p "${lima_root}"
  cp -R "${tmp_dir}/bin" "${lima_root}/"
  cp -R "${tmp_dir}/share" "${lima_root}/"
  cp -R "${tmp_dir}/libexec" "${lima_root}/"
  ln -sf "${lima_root}/bin/lima" "${LOCAL_BIN}/lima"
  ln -sf "${lima_root}/bin/limactl" "${LOCAL_BIN}/limactl"
  trap - RETURN
  rm -rf "${tmp_dir}"
}

install_colima() {
  local url
  url="$(github_asset_url abiosoft/colima 'colima-Darwin-arm64$')"
  download "${url}" "${LOCAL_BIN}/colima"
  chmod +x "${LOCAL_BIN}/colima"
}

install_docker_cli() {
  local version tmp_dir
  version="$(curl -fsSL https://download.docker.com/mac/static/stable/aarch64/ \
    | python3 -c 'import re, sys; text=sys.stdin.read(); versions=set(re.findall(r"docker-([0-9.]+)\.tgz", text)); key=lambda s: tuple(int(x) for x in s.split(".")); print(sorted(versions, key=key)[-1])')"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  download "https://download.docker.com/mac/static/stable/aarch64/docker-${version}.tgz" "${tmp_dir}/docker.tgz"
  tar -xzf "${tmp_dir}/docker.tgz" -C "${tmp_dir}"
  install_executable "${tmp_dir}/docker/docker" docker
  trap - RETURN
  rm -rf "${tmp_dir}"
}

install_docker_compose_plugin() {
  local url
  url="$(github_asset_url docker/compose 'docker-compose-darwin-aarch64$')"
  download "${url}" "${DOCKER_PLUGINS_DIR}/docker-compose"
  chmod +x "${DOCKER_PLUGINS_DIR}/docker-compose"
  ln -sf "${DOCKER_PLUGINS_DIR}/docker-compose" "${LOCAL_BIN}/docker-compose"
}

install_docker_buildx_plugin() {
  local url
  url="$(github_asset_url docker/buildx 'buildx-v.*\\.darwin-arm64$')"
  download "${url}" "${DOCKER_PLUGINS_DIR}/docker-buildx"
  chmod +x "${DOCKER_PLUGINS_DIR}/docker-buildx"
}

main() {
  ensure_path_setup
  sanitize_docker_config

  echo "Installing Docker CLI and local runtime tooling..."
  install_docker_cli
  install_docker_compose_plugin
  install_docker_buildx_plugin
  install_lima
  install_colima

  echo "Installing Kubernetes and platform tooling..."
  install_kubectl
  install_helm
  install_promtool
  install_kustomize
  install_kind
  install_argocd

  echo "Installing infrastructure and helper tooling..."
  install_terraform
  install_node
  install_awscli
  install_yq
  install_cloudflared

  echo "Installing Azure CLI into a local virtual environment..."
  install_azure_cli

  echo "Provisioning the local k3s runtime..."
  "${SCRIPT_DIR}/ensure-k3s-runtime.sh"

  cat <<'EOF'

Bootstrap complete.

Next shell setup:
  source ~/.zprofile

Container runtime:
  export IDP_RUNTIME_CPU=6
  export IDP_RUNTIME_MEMORY_GIB=12
  export IDP_RUNTIME_DISK_GIB=100
  colima start --runtime docker --cpu "$IDP_RUNTIME_CPU" --memory "$IDP_RUNTIME_MEMORY_GIB" --disk "$IDP_RUNTIME_DISK_GIB" --kubernetes --network-address
  docker context use colima

Verification:
  docker version
  docker compose version
  kubectl version --client
  kubectl get nodes
  helm version
  promtool --version
  terraform version
  node --version
  npm --version
  aws --version
  az version
EOF
}

main "$@"
