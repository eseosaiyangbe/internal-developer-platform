# DevOps Easy Learning Workstation Bootstrap

## Purpose

This guide is the starting point for setting up a fresh machine to work on this monorepo.

It exists so contributors do not have to reverse-engineer tool requirements from five different repos.

Use this guide when:

- you are joining the project on a new machine
- you want the minimum toolchain needed for local Docker, Kubernetes, and Terraform work
- you want one repeatable setup path before touching any repo-specific docs

## What This Installs

The bootstrap scripts are designed to prepare a workstation for the main workflows in this repo:

- Docker and Docker Compose
- Docker Buildx
- Kubernetes CLI tooling
- local k3s runtime provisioning
- Prometheus rule tooling (`promtool`)
- Terraform
- Node.js and npm
- AWS CLI
- Azure CLI
- `yq`
- `cloudflared`
- `argocd`

## Choose Your OS

### macOS

Use:

```bash
./scripts/bootstrap-macos-userland.sh
```

Notes:

- this script targets Apple Silicon macOS
- it installs tools into user-space locations instead of relying on Homebrew
- it uses Colima and Lima for the local Docker runtime
- it provisions a local k3s cluster through Colima and installs Traefik as the ingress controller
- after bootstrap, the main Docker context should be `colima`

### Linux

Use:

```bash
./scripts/bootstrap-linux-userland.sh
```

Notes:

- this script targets Linux
- it installs most tools into user-space locations
- it uses Docker Engine directly instead of Colima/Lima
- it provisions a local k3s cluster with the official installer when passwordless sudo is available
- it detects `apt-get` and `dnf` for base package installation
- if Docker is newly installed, you may need to log out and back in before the `docker` group membership applies cleanly

## After Running A Bootstrap Script

### macOS shell refresh

```bash
source ~/.zprofile
docker context use colima
kubectl get nodes
```

### Linux shell refresh

```bash
source ~/.profile
```

## Verification

Run these commands after bootstrap:

```bash
docker version
docker compose version
docker buildx version
kubectl version --client
kubectl get nodes
helm version
promtool --version
terraform version
node --version
npm --version
aws --version
az version
yq --version
cloudflared version
argocd version --client
```

To verify Docker can actually pull and run containers:

```bash
docker pull hello-world
docker run --rm hello-world
```

## Local Browser Hostnames

The local `k3s` path uses Traefik and friendly `.devops.local` hostnames.

After bootstrap and after `./scripts/ensure-k3s-runtime.sh` is healthy, get the current Traefik address:

```bash
kubectl get svc -n traefik traefik
```

Then populate `/etc/hosts` with the workspace helper:

```bash
./scripts/setup-devops-local-hosts.sh
```

These hosts map the main local browser paths for:

- the observability control plane
- Grafana
- Vault UI
- MemFlip
- SwiftPay
- FoodPulse

If you want to preview the generated host line before applying it:

```bash
./scripts/setup-devops-local-hosts.sh --print
```

## Expected Runtime Direction

### macOS

The intended local runtime is:

```text
Docker CLI -> Colima -> Lima VM -> Docker Engine
                                 -> k3s control plane
```

That means these two checks matter:

- `docker context ls`
- `colima status`
- `kubectl config current-context`
- `kubectl get nodes`
- `docker buildx version`

### Linux

The intended local runtime is:

```text
Docker CLI -> Docker Engine
          -> k3s service
```

That means these two checks matter:

- `docker version`
- `systemctl status docker` if Docker daemon access is failing
- `systemctl status k3s` if Kubernetes access is failing
- `kubectl get nodes`
- `docker buildx version`

## Why This Guide Exists

This project is being built with Kubernetes in mind, but the daily proving ground is still local development.

If workstation setup is inconsistent, everything downstream becomes noisy:

- Compose validation
- k3s runtime usage
- Terraform workflows
- cloud CLI commands
- onboarding for other contributors

This guide keeps the machine bootstrap aligned with the workspace roadmap and runbook.

## Related Files

- [bootstrap-macos-userland.sh](/Users/raymond/Documents/DevOps-Easy-Learning/scripts/bootstrap-macos-userland.sh)
- [bootstrap-linux-userland.sh](/Users/raymond/Documents/DevOps-Easy-Learning/scripts/bootstrap-linux-userland.sh)
- [ensure-k3s-runtime.sh](/Users/raymond/Documents/DevOps-Easy-Learning/scripts/ensure-k3s-runtime.sh)
- [PROJECT-ROADMAP.md](/Users/raymond/Documents/DevOps-Easy-Learning/PROJECT-ROADMAP.md)
- [JOURNEY-RUNBOOK.md](/Users/raymond/Documents/DevOps-Easy-Learning/JOURNEY-RUNBOOK.md)
