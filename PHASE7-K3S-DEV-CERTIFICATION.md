# Phase 7 k3s Dev Certification

## Date

- `2026-05-01`

## Scope

This certification pass covers the full local `k3s` development platform for Phase 7:

- shared control plane
- Vault-backed secrets platform
- Traefik ingress
- `MemFlip`
- `SwiftPay`
- `FoodPulse`
- `OpenSIS`

## Certification Goal

Confirm that the migrated Kubernetes development environment is:

- schedulable on the shared single-node `colima` runtime
- operationally healthy
- reachable through the intended local ingress model
- consistent with the workspace control-plane truth

## Environment State

- Kubernetes runtime: `k3s` on `colima`
- node count: `1`
- ingress address: `192.168.64.2`
- namespaces present:
  - `memflip-dev`
  - `swiftpay-dev`
  - `foodpulse-dev`
  - `opensis-dev`
  - `platform-observability-dev`
  - `vault`
  - `external-secrets`
  - `cnpg-system`

## Verification Performed

### Control Plane

- [k8s-dev-verify.sh](/Users/raymond/Documents/DevOps-Easy-Learning/Obervability-Stack/scripts/k8s-dev-verify.sh)
- [devops-monitor.sh](/Users/raymond/Documents/DevOps-Easy-Learning/Obervability-Stack/scripts/devops-monitor.sh) `operator`

### Workloads

- [k8s-dev-verify.sh](/Users/raymond/Documents/memflip/scripts/k8s-dev-verify.sh)
- [k8s-dev-verify.sh](/Users/raymond/Documents/DevOps-Easy-Learning/SwiftPay/scripts/k8s-dev-verify.sh)
- [k8s-dev-verify.sh](/Users/raymond/Documents/DevOps-Easy-Learning/FoodPulse/scripts/k8s-dev-verify.sh)
- [k8s-dev-verify.sh](/Users/raymond/Documents/DevOps-Easy-Learning/OpenSIS/scripts/k8s-dev-verify.sh)

### Secrets Platform

- Vault `SecretStore` objects valid in all migrated namespaces
- `ExternalSecret` objects synchronized in all migrated namespaces
- Vault ingress reachable at `vault.devops.local`
- Vault status:
  - initialized: `true`
  - sealed: `false`

## Results

### Passed

- all migrated workload verification scripts passed
- control-plane verification passed
- workspace app snapshot reported:
  - `4 healthy`
  - `0 degraded`
  - `0 down`
- Prometheus target verification passed for the expected application and platform targets
- all migrated namespaces reported healthy pods

### Current Resource Posture

Node allocation at certification time:

- CPU requests: `2015m` (`50%`)
- Memory requests: `4984Mi` (`62%`)

This is materially healthier than the earlier pre-audit state and leaves the shared node in a much safer dev operating posture.

## Browser Access Outcome

Direct browser entrypoint checks succeeded for:

- `controlplane.devops.local`
- `grafana.devops.local`
- `memflip.devops.local`
- `www.swiftpay.devops.local`
- `api.swiftpay.devops.local/health`
- `foodpulse.devops.local`
- `vault.devops.local`

`OpenSIS` also passed ingress validation, but in a more specific way:

- host-header validation against the Traefik address returned:
  - `/` -> `302`
  - `/install/index.php` -> `200`

That confirms the Kubernetes ingress is healthy.

## One Remaining Local Workstation Gap

The local workstation `/etc/hosts` entry was stale and did not yet include:

- `opensis.devops.local`

That is not a cluster failure.

It is a local browser-resolution gap caused by an older host mapping line that predated the OpenSIS browser entrypoint.

The helper script already contains the correct host list:

- [setup-devops-local-hosts.sh](/Users/raymond/Documents/DevOps-Easy-Learning/scripts/setup-devops-local-hosts.sh)

Required local follow-up:

```bash
cd /Users/raymond/Documents/DevOps-Easy-Learning
./scripts/setup-devops-local-hosts.sh
```

After that, the browser contract is complete for:

- `http://controlplane.devops.local`
- `http://grafana.devops.local`
- `http://vault.devops.local`
- `http://memflip.devops.local`
- `http://www.swiftpay.devops.local`
- `http://foodpulse.devops.local`
- `http://opensis.devops.local`

## Certification Verdict

Phase 7 `k3s` `dev` is operationally certified from the platform perspective.

The only remaining action is a local workstation host refresh so the `OpenSIS` browser hostname resolves consistently alongside the other ingress hosts.
