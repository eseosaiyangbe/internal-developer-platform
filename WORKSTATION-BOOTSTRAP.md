# Internal Developer Platform Workstation Bootstrap

## Purpose

This guide is the starting point for setting up a fresh machine to work on the current platform workspace.

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
- optional cert-manager platform install for production-style TLS
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
- the primary platform target is k3s; Docker Compose remains a stable foundation, not the main runtime-sizing driver
- cert-manager is intentionally optional and should be installed only when you are validating the TLS production path
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
- the primary platform target is k3s; Docker Compose remains a stable foundation, not the main runtime-sizing driver
- cert-manager is intentionally optional and should be installed only when you are validating the TLS production path
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

## Repository Layout

The platform is moving toward:

```text
<workspace-root>/
  internal-developer-platform/
  observability-stack/
  memflip/
  swiftpay/
  foodpulse/
  opensis/
```

During the transition, the central platform repo no longer needs embedded
workload directories, and the central operator scripts support:

- a central platform repo with no embedded workload repos
- sibling workload checkouts

To inspect the currently resolved layout:

```bash
./scripts/workspace-layout.sh
```

To create the recommended sibling checkout layout beside the central platform
repo:

```bash
./scripts/bootstrap-sibling-repos.sh
```

If a child repo provides `.env.example`, the bootstrap will also create a local
`.env` automatically. This prevents fresh sibling checkouts from inheriting
hidden assumptions from the older embedded workspace layout.

To override any repo path explicitly:

```bash
export IDP_OBSERVABILITY_STACK_DIR=/path/to/observability-stack
export IDP_SWIFTPAY_DIR=/path/to/swiftpay
export IDP_OPENSIS_DIR=/path/to/opensis
export IDP_FOODPULSE_DIR=/path/to/foodpulse
export IDP_MEMFLIP_DIR=/path/to/memflip
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

## Runtime Sizing Policy

This workspace is now Kubernetes-first.

Compose remains a stable validation foundation, but local capacity planning should
be driven by the shared k3s platform:

- Vault
- External Secrets
- Traefik
- cert-manager when enabled
- Prometheus
- Loki
- Grafana
- the control-plane UI
- migrated application namespaces
- local image builds and image imports

### Recommended baseline

Use this as the default cross-platform runtime target:

- CPU: `6`
- Memory: `12 GiB`
- Disk: `100 GiB`

### Minimum supported baseline

This may still work for lighter validation, but it is no longer the preferred
shape for the full Phase 7 platform:

- CPU: `4`
- Memory: `8 GiB`
- Disk: `60 GiB`

### Heavier demo profile

Use this when you expect concurrent k3s activity, repeated rebuilds, or wider
parallel demo activity:

- CPU: `8`
- Memory: `16 GiB`
- Disk: `120 GiB`

### Runtime contract variables

The local runtime contract can now be expressed with environment variables:

```bash
export DEVOPS_EASY_LEARNING_RUNTIME_CPU=6
export DEVOPS_EASY_LEARNING_RUNTIME_MEMORY_GIB=12
export DEVOPS_EASY_LEARNING_RUNTIME_DISK_GIB=100
```

On macOS, `./scripts/ensure-k3s-runtime.sh` applies these values to Colima.

On Linux, the same variables define the expected baseline for the Docker plus
k3s host even though there is no Colima VM layer.

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
- OpenSIS

If you want to preview the generated host line before applying it:

```bash
./scripts/setup-devops-local-hosts.sh --print
```

## Optional Production TLS Platform

When you want to validate the production-style TLS path locally, install cert-manager and apply the shared ClusterIssuers:

```bash
./scripts/install-cert-manager.sh --email you@example.com
```

This is optional because it adds another platform dependency and is not required for the normal `dev` ingress path.

Related reference:

- [PRODUCTION-TLS-CERT-MANAGER.md](/Users/raymond/Documents/DevOps-Easy-Learning/PRODUCTION-TLS-CERT-MANAGER.md)

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
