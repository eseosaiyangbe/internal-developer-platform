# Phase 8 Protected Surface Access Model

Date: `2026-05-27`

## Purpose

This document extends the Phase 8 Slice 3 operator-access model beyond ArgoCD to the other protected platform surfaces that matter in the current local `k3s` environment.

It is intentionally narrow.

It defines:

- the current access path
- the normal operator path
- the break-glass path
- which interventions are acceptable local-runtime recovery actions
- which gaps still remain and should not be overstated

## Protected Surfaces In Scope

This Phase 8.2 step covers:

- ArgoCD
- Vault
- host-side local recovery controls for Vault and the broader `k3s` platform

This step does not claim full production access maturity for:

- SSO
- audited operator identity
- identity-aware ingress in front of protected control-plane services

## Surface 1. ArgoCD

Authoritative doc:

- [PHASE8-ARGOCD-ACCESS-AND-BREAK-GLASS.md](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/PHASE8-ARGOCD-ACCESS-AND-BREAK-GLASS.md)

Current posture:

- operator-local only
- local port-forward access
- no public ingress
- no SSO
- no audited identity-aware access flow

Normal operator path:

- `kubectl get application ...`
- `kubectl describe application ...`
- local port-forward only when the UI is truly needed

Scripted helper:

```bash
./scripts/argocd-restore-drill-sync.sh status --app opensis-dev
./scripts/argocd-restore-drill-sync.sh suspend --app opensis-dev
./scripts/argocd-restore-drill-sync.sh resume --app opensis-dev
```

## Surface 2. Vault

Current posture:

- local UI access through `http://vault.devops.local/ui/`
- normal local operator login uses `userpass`
- bootstrap local users:
  - `admin` / `Admin@123`
  - `readonly` / `readonly`
- root token remains break-glass only
- root token material lives on the operator host:
  - `~/.config/internal-developer-platform/k3s-vault-init.json`

Normal operator path:

- use the UI through `vault.devops.local` only when browser interaction is actually needed
- prefer read-oriented checks where possible:
  - `kubectl get pods -n vault`
  - `kubectl get secretstore -A`
  - `kubectl get externalsecret -A`

Break-glass path:

- recover sealed or degraded Vault through the host-side recovery workflow
- do not normalize routine use of the root token

Key rule:

- the root token is a recovery credential, not a day-two operator identity

## Surface 3. Host-Side Recovery Controls

Current posture:

- local restart recovery is intentionally host-side
- the cluster does not store the Vault unseal material
- recovery is already partially scripted and should be treated as an explicit platform control

Current recovery scripts:

```bash
./scripts/recover-k3s-vault.sh
./scripts/recover-k3s-platform.sh
```

Current launch-agent installers:

```bash
./scripts/install-vault-recovery-launchagent.sh
./scripts/install-platform-recovery-launchagent.sh
```

Acceptable local-runtime recovery actions:

- running `recover-k3s-vault.sh` after a raw Colima restart or sealed Vault event
- running `recover-k3s-platform.sh` when Traefik, core pods, or the origin listener are wedged after runtime restart
- allowing one scripted Colima restart escalation through `recover-k3s-platform.sh`

Why these are acceptable:

- they are local-runtime recovery controls
- they are explicit
- they preserve the trust boundary by keeping unseal material outside Kubernetes

Why they should not be overclaimed:

- this is not the production recommendation
- it is a local operator recovery model, not a final enterprise access architecture

## Classification Of Operator Actions

### Acceptable local-runtime recovery actions

These are acceptable in the current Phase 8 posture:

- ArgoCD hard refresh
- temporary ArgoCD automated-sync suspension for a controlled restore drill
- host-side Vault recovery
- host-side k3s platform recovery
- one-time local port-forward for ArgoCD UI access
- one-time local Vault UI access through the documented hostname

### Hardening gaps still open

These should remain clearly classified as not-yet-final:

- ArgoCD still lacks SSO and audited access
- Vault still uses a local `userpass` bootstrap pattern for operator UI access
- Vault root-token material still exists on the operator host for local recovery
- protected-surface access is still local-operator-centric rather than team-grade or identity-aware

## Useful Commands

Protected-surface status snapshot:

```bash
./scripts/platform-protected-surface-status.sh
```

Quiet status snapshot:

```bash
./scripts/platform-protected-surface-status.sh --quiet
```

Manual Vault recovery:

```bash
./scripts/recover-k3s-vault.sh
```

Manual full platform recovery:

```bash
./scripts/recover-k3s-platform.sh
```

Suppress automatic Colima restart escalation:

```bash
./scripts/recover-k3s-platform.sh --no-colima-restart
```

ArgoCD access:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Vault access:

- [http://vault.devops.local/ui/](http://vault.devops.local/ui/)

## Current Phase 8 Assessment

This step improves Slice 3 in a disciplined way because it does not pretend the local platform has a full production access model.

Instead, it makes the real operator contract explicit:

- what is local-only
- what is safe day-two access
- what is break-glass only
- what is an acceptable local-runtime recovery action
- what still remains a maturity gap
