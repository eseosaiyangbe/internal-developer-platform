# Production Overlay Audit

This document records the first explicit production-hardening audit across the owned Kubernetes paths:

- `MemFlip`
- `SwiftPay`
- `FoodPulse`
- `OpenSIS`
- `Obervability-Stack`

The goal is not to claim that production is already deploy-ready. The goal is to distinguish between:

- production contract elements that are already explicit
- production controls that were missing and are now added
- deeper production decisions that still require follow-up

## Current Verdict

The repository now has a materially stronger `prod` posture than before this audit:

- all five owned `prod` overlays are Vault-first
- all five owned `prod` overlays now carry explicit Traefik TLS placeholders
- replicated stateless workloads outside `SwiftPay` now have explicit PodDisruptionBudgets
- replicated stateless workloads outside `SwiftPay` now have explicit HPAs where that was missing
- the observability control plane `prod` overlay now has an explicit two-replica posture for the UI and Grafana entry points

That said, the workspace is still not at a final “production-complete” posture.

## What Was Missing Before This Audit

### 1. `SwiftPay` was the only app with a clear production-control model

Before this pass, `SwiftPay` already had:

- dedicated `prod` scale patches
- `prod` HPA patches
- `prod` PodDisruptionBudget patches
- explicit prod ingress hosts

The other owned overlays mostly stopped at:

- Vault-backed secrets
- production image tags
- larger resource sizes
- production hostnames

That was not enough to claim a consistent production contract.

### 2. Several prod ingresses were still effectively HTTP-first

Before this pass:

- `MemFlip`
- `FoodPulse`
- `OpenSIS`
- `Obervability-Stack`

did not carry explicit `spec.tls` entries in their `prod` ingress posture.

That meant the repo implied a production hostname model without making the TLS contract explicit.

### 3. Disruption posture was uneven outside `SwiftPay`

Before this pass:

- `MemFlip` had no explicit `prod` PDBs
- `FoodPulse` had no explicit `prod` PDBs for API/UI
- `OpenSIS` had no explicit `prod` PDB for the replicated UI tier
- `Obervability-Stack` had no explicit `prod` PDBs for the user-facing stateless entry points

That left drain and voluntary disruption behavior under-specified.

### 4. Autoscaling posture was inconsistent

Before this pass:

- `SwiftPay` was the only owned workload set with explicit prod HPA posture
- `MemFlip`, `FoodPulse`, `OpenSIS`, and `Obervability-Stack` lacked equivalent `prod` autoscaling contracts for their stateless tiers

For a repo that claims a production direction, that gap was too large.

## What This Audit Added

### `MemFlip`

Added:

- `prod` HPA for backend
- `prod` HPA for frontend
- `prod` PDB for backend
- `prod` PDB for frontend
- TLS placeholder secret for `memflip.prod.example.com`
- explicit `web,websecure` Traefik entrypoint posture

### `SwiftPay`

Added:

- explicit `spec.tls` blocks for:
  - `www.swiftpay.prod.example.com`
  - `swiftpay.prod.example.com`
  - `api.swiftpay.prod.example.com`

This keeps `SwiftPay` aligned with the same TLS-first production contract as the other apps.

### `FoodPulse`

Added:

- `prod` HPA for API
- `prod` HPA for UI
- `prod` PDB for API
- `prod` PDB for UI
- TLS placeholder secret for `foodpulse.prod.example.com`
- explicit `web,websecure` Traefik entrypoint posture

### `OpenSIS`

Added:

- `prod` HPA for `opensis-ui`
- `prod` PDB for `opensis-ui`
- TLS placeholder secret for `opensis.prod.example.com`

This is intentionally narrower than the other apps because `OpenSIS` remains the most operationally sensitive workload and should not be over-generalized blindly.

### `Obervability-Stack`

Added:

- `prod` HPA for `devops-monitor-ui`
- `prod` HPA for `grafana`
- `prod` PDB for `devops-monitor-ui`
- `prod` PDB for `grafana`
- explicit `replicas: 2` posture for:
  - `devops-monitor-ui`
  - `grafana`
- TLS placeholder secrets for:
  - `controlplane.prod.example.com`
  - `grafana.prod.example.com`
- explicit `web,websecure` Traefik entrypoint posture

## Remaining Production Gaps

These are real remaining issues and should not be hidden by the improvements above.

### 1. Certificate issuance is now standardized in-repo, but not yet live-installed everywhere

The repository now defines a shared production TLS path through:

- `cert-manager`
- shared `ClusterIssuer` manifests
- per-ingress `cert-manager.io/cluster-issuer` annotations

That closes the architecture gap, but it does not by itself guarantee live certificate issuance in every cluster.

A later follow-up should ensure the chosen path is actually installed and reconciled in each production environment, including:

- cert-manager availability
- issuer readiness
- DNS ownership and propagation
- renewal monitoring and alerting

### 2. Stateful durability is still mixed

Examples:

- `Grafana` still uses `emptyDir`
- `Alertmanager` still uses `emptyDir`
- `Prometheus` and `Loki` are still single-instance stateful services in the owned path

Those are acceptable as a portfolio direction signal, but they are not final production architecture for a serious multi-node platform.

### 3. Anti-affinity and topology spread are still under-specified

Replicas and PDBs are now present, but true production posture should also define:

- anti-affinity
- topology spread constraints
- zone or node-failure assumptions

That matters especially for:

- `SwiftPay`
- `FoodPulse`
- `Obervability-Stack`

### 4. OpenSIS still deserves a narrower scaling posture than the other apps

`OpenSIS` is replicated at the UI tier, but it is still a legacy-runtime workload with:

- file-oriented startup behavior
- Vault-rendered env contracts
- tighter coupling to legacy application assumptions

So the current `prod` additions are appropriate, but future scaling or disruption behavior should remain conservative and explicitly tested.

## Recommended Next Follow-Up

The clean next production-hardening slice should be:

1. install and validate the shared cert-manager path in the target production-style clusters
2. add anti-affinity and topology spread constraints to replicated `prod` workloads
3. tighten observability-state durability, especially for Grafana and Alertmanager
4. decide whether the next roadmap step is formal Phase 7 closeout or a Phase 8 production-controls phase
