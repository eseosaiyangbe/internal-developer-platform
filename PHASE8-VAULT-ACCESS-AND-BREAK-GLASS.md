# Phase 8 Vault Access And Break-Glass Model

Date: `2026-05-27`

## Purpose

This document defines the current operator access model for Vault on the local `k3s` platform and distinguishes normal operator behavior from true break-glass use.

This is intentionally a local-platform contract.

It is not a final enterprise identity architecture.

## Current Access Posture

Current truth:

- Vault UI is available only through the local platform hostname:
  - [http://vault.devops.local/ui/](http://vault.devops.local/ui/)
- normal local operator login uses `userpass`
- bootstrap local users currently include:
  - `admin`
  - `readonly`
- the Vault root token remains break-glass only
- root-token and unseal material remain on the operator host rather than in Kubernetes

This posture is acceptable only if it is treated as:

- a local operator surface
- a constrained recovery control
- not a team-grade or internet-exposed admin surface

## Normal Operator Path

Routine operator checks should stay read-oriented first:

```bash
kubectl get pod vault-0 -n vault
kubectl get secretstore -A
kubectl get externalsecret -A
./scripts/vault-access-status.sh status
```

Use the browser UI only when interaction is actually required:

- auth inspection
- secret-path validation
- policy inspection

Normal operator rule:

- do not use the root token for routine day-two work
- prefer namespace health, SecretStore readiness, and ExternalSecret readiness as the first checks

## Break-Glass Path

Break-glass use begins when Vault is:

- sealed
- degraded in a way that blocks normal userpass access
- unable to satisfy downstream SecretStore or ExternalSecret recovery

The current local break-glass controls are:

```bash
./scripts/recover-k3s-vault.sh
./scripts/vault-access-status.sh break-glass-check
```

The recovery material lives on the operator host:

- `~/.config/internal-developer-platform/k3s-vault-init.json`

Key rule:

- the root token is a recovery credential, not a normal operator identity
- the local runtime uses host-side automated recovery, not Vault-native KMS auto-unseal
- the local runtime now stores Vault state on integrated Raft instead of the legacy file backend

## Scripted Helper

Safe day-two snapshot:

```bash
./scripts/vault-access-status.sh status
```

File-to-Raft migration helper:

```bash
./scripts/migrate-k3s-vault-file-to-raft.sh
```

Vault Raft snapshot helpers:

```bash
./scripts/vault-raft-snapshot-save.sh
./scripts/vault-raft-snapshot-inspect.sh --latest
./scripts/vault-raft-snapshot-restore.sh --snapshot /path/to/vault.snap --yes-really-restore
```

Explicit break-glass verification:

```bash
./scripts/vault-access-status.sh break-glass-check
```

What the helper verifies:

- Vault pod phase
- Vault sealed state
- host-side init-material presence
- host-side init-material file mode
- SecretStore readiness count
- ExternalSecret readiness count
- break-glass root-token lookup path
- `userpass/` auth mount presence
- `admin` and `readonly` user definitions

What the helper does not do:

- print the root token
- unseal Vault directly
- mutate policies or users

What the snapshot helpers do:

- capture host-side Vault Raft snapshots with metadata and checksums
- inspect locally stored snapshot inventory
- restore a selected snapshot only through an explicit destructive flag

## Acceptable Local-Runtime Recovery Actions

These are acceptable in the current local Phase 8 posture:

- using `recover-k3s-vault.sh` after a runtime restart or sealed-Vault event
- relying on the installed host-side Vault recovery LaunchAgent to retry through early Colima and Kubernetes startup races
- using `vault-access-status.sh break-glass-check` to confirm the host-side recovery material still works
- using the Vault UI through the local hostname for deliberate operator tasks

Current automation characteristics:

- LaunchAgent label: `com.internal-developer-platform.vault-recovery`
- startup behavior: `RunAtLoad` plus `30s` polling
- recovery stance: wait through early API and `vault-0` startup instead of failing the first interval
- recovery execution path: prefer Colima-side `k3s kubectl` for unattended local recovery so the agent does not depend on the host-to-VM API route staying healthy
- recovery action order: direct unseal first, SecretStore reconcile second, bootstrap reconcile only as a fallback
- trust boundary: unseal material remains on the operator host and is not mirrored into Kubernetes

Validated drill result on `2026-06-07`:

- a controlled sealed-Vault event returned from `sealed=true` to `sealed=false` through the unattended LaunchAgent path
- Raft leadership stayed healthy after recovery
- SecretStore readiness returned to zero-not-ready

## Hardening Gaps Still Open

These remain clearly open:

- Vault still lacks SSO or audited identity-aware access
- `userpass` is still a bootstrap-pattern operator path, not a final production model
- root-token recovery material still exists on the operator host
- the current Vault access model is local-operator-centric, not team-grade

## Current Phase 8 Assessment

This improves Slice 3 because it turns Vault access from an implied local habit into an explicit operator contract.

It does not overclaim maturity.

It makes these things unambiguous:

- what is normal day-two access
- what is break-glass only
- what helper is safe to run
- what still remains a maturity gap
