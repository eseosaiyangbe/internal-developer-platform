# Local Vault Recovery Model

## Purpose

This document explains the local restart recovery design for the Internal Developer Platform.

It exists because the local `docker + k3s` platform has a real tension:

- we want restart recovery to be reliable
- we do not want to normalize the bad practice of storing Vault unseal material inside Kubernetes

## The Design Problem

When Colima is stopped and started, Vault returns in a sealed state.

That creates a predictable failure chain:

1. Vault is `Initialized` but `Sealed`
2. namespace `vault-backend` `SecretStore` objects fail with `InvalidProviderConfig`
3. `ExternalSecret` reconciliation stops
4. secret-backed workloads may remain up briefly, but the platform is no longer operationally healthy

That is acceptable as a security property, but it is too fragile as the default local operator experience.

## What We Explicitly Rejected

We did not solve this by storing the Vault unseal key inside the cluster.

That would be a poor enterprise pattern because it breaks the trust boundary:

- the cluster would become responsible for unsealing the cluster-secret system itself
- a compromised cluster would gain access to the very material intended to protect it

For this project, that would be operationally convenient but architecturally weak.

## Chosen Local Design

For the local platform only, the recovery model is host-side and layered:

- Vault init material stays on the operator host:
  - `~/.config/internal-developer-platform/k3s-vault-init.json`
- the cluster remains unaware of the unseal key
- one host-side recovery script reconciles Vault and External Secrets after runtime restart
- a second host-side recovery script reconciles the broader k3s platform after runtime restart
- macOS LaunchAgents run both recovery paths from mirrored bundles under `~/.local/share/internal-developer-platform/` so they do not depend on macOS `Documents` access

This gives us:

- restart recovery without manual cluster surgery
- a repeatable and observable operator path
- preserved separation between host state and cluster state
- a clear distinction between secret-platform recovery and full local platform recovery

## Recovery Components

- Vault recovery script:
  - [/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/recover-k3s-vault.sh](/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/recover-k3s-vault.sh)
- Vault LaunchAgent installer:
  - [/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/install-vault-recovery-launchagent.sh](/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/install-vault-recovery-launchagent.sh)
- Platform recovery script:
  - [/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/recover-k3s-platform.sh](/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/recover-k3s-platform.sh)
- Platform LaunchAgent installer:
  - [/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/install-platform-recovery-launchagent.sh](/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/install-platform-recovery-launchagent.sh)
- Authoritative reconcile path reused by recovery:
  - [/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/bootstrap-k3s-vault-secrets.sh](/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/scripts/bootstrap-k3s-vault-secrets.sh)

## How Recovery Works

### Layer 1: Vault and External Secrets

1. Detect whether Vault is sealed.
2. Detect whether any `SecretStore` or `ExternalSecret` objects are not ready.
3. If everything is already healthy, exit with no changes.
4. If unhealthy, run the authoritative Vault reconcile path.
5. Force-refresh `SecretStore` and `ExternalSecret` objects.
6. Wait until the secret platform returns to `Ready=True`.

### Layer 2: Full local platform

1. Detect whether the Kubernetes API is ready.
2. Detect whether Traefik is healthy.
3. Reuse the Vault recovery layer.
4. Detect whether core platform namespaces still have restart-stuck pods.
5. Reconcile Traefik and re-nudge the core platform until the control plane can serve traffic again.

## Operator Commands

Manual Vault recovery:

```bash
cd /Users/raymond/Documents/devops-easy-learning/internal-developer-platform
./scripts/recover-k3s-vault.sh
```

Manual full platform recovery:

```bash
cd /Users/raymond/Documents/devops-easy-learning/internal-developer-platform
./scripts/recover-k3s-platform.sh
```

Install the automatic recovery agents:

```bash
cd /Users/raymond/Documents/devops-easy-learning/internal-developer-platform
./scripts/install-vault-recovery-launchagent.sh
./scripts/install-platform-recovery-launchagent.sh
```

Check the LaunchAgents:

```bash
launchctl print "gui/$(id -u)/com.internal-developer-platform.vault-recovery"
launchctl print "gui/$(id -u)/com.internal-developer-platform.k3s-platform-recovery"
```

Logs:

- `~/Library/Logs/internal-developer-platform-vault-recovery.out.log`
- `~/Library/Logs/internal-developer-platform-vault-recovery.err.log`
- `~/Library/Logs/internal-developer-platform-k3s-platform-recovery.out.log`
- `~/Library/Logs/internal-developer-platform-k3s-platform-recovery.err.log`

Runtime bundle:

- `~/.local/share/internal-developer-platform/vault-recovery`
- `~/.local/share/internal-developer-platform/k3s-platform-recovery`

## Why This Is A Strong Talking Point

This is a credible platform-engineering example because it shows we handled a real design tension carefully:

- we improved local resiliency
- we preserved a meaningful security boundary
- we made the local fix explicit instead of pretending it was production-grade

The project story is:

- we identified that manual Vault unseal after local runtime restart was operationally weak
- we rejected the lazy fix of storing unseal material in-cluster
- we implemented a host-side recovery control for Vault
- we then proved through live restart testing that full local platform recovery needed a second control
- we implemented that second host-side platform recovery layer instead of pretending the first fix solved everything
- we kept the production recommendation stricter than the local workaround

## Production Recommendation

This local model is not the production recommendation.

For production-grade Vault, the correct posture is:

- KMS or HSM-backed auto-unseal
- no routine manual Shamir unseal dependency
- no unseal material stored on developer laptops

In short:

- local platform: host-side recovery agent
- production platform: managed auto-unseal
