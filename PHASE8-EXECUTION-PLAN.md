# Phase 8 Execution Plan

Date: `2026-05-23`
Updated: `2026-06-29`

## Purpose

This document turns Phase 8 from a roadmap label into an executable operating plan.

Phase 8 is not a platform-assembly phase.

It is the phase where we:

- validate durability assumptions under failure
- make backup and restore a real platform control
- tighten operator access and recovery discipline
- increase confidence in the production-style narrative without overstating current runtime proof

## Phase 8 Scope

Phase 8 execution is organized into five ordered slices:

1. backup and restore standardization
2. durability validation and restore drills
3. operator access and break-glass hardening
4. runtime pressure and placement validation
5. broader production-path proof

## Current Status Snapshot

As of `2026-06-28`:

- Slice 1 is complete at the app-contract level
- Slice 2 has live restore-drill evidence across the owned stateful workloads
- Slice 3 is materially complete for the current local-platform objective
- Slice 4 has started and now has first-pass runtime-wedge evidence plus an eleventh SwiftPay pressure validation with a clean bounded `12/12` public-ingress success band under the current local dev contract
- the shared local Vault control plane now runs on integrated Raft storage instead of the legacy file backend
- the host-side Vault recovery automation has now passed a controlled sealed-Vault drill against the Raft-backed state
- the shared Vault control plane now has a Raft snapshot backup and destructive restore contract at the helper level
- the shared Vault control plane has now passed a reversible Raft snapshot restore drill with a rollback proof marker and return-to-current-state validation
- Slice 5 has started on the safe-first path with:
  - clean render validation for all owned `prod` overlays
  - live production observability TLS challenge reconciliation proof, still blocked at external DNS or HTTP-01 routing conditions
  - live Vault-backed secret-delivery proof in the paused `platform-observability-prod` namespace
  - a centralized dormant `prod` ArgoCD composition path now added and client-side validated in the platform repo
  - a more coherent production observability network-policy contract across the owned apps, including a corrected SwiftPay `prod` observability path
  - a stronger production namespace-governance contract in Git through standardized namespace labels and explicit `ResourceQuota` posture across the owned `prod` overlays

Validated app-level recovery coverage now exists for:

- `observability-stack`
- `SwiftPay`
- `FoodPulse`
- `MemFlip`
- `OpenSIS`

## Execution Order

### Slice 1. Backup And Restore Standardization

Goal:

- define one platform-level backup and restore contract across the owned workloads

Outputs:

- platform backup and restore standard
- per-app implementation status
- retention expectations
- restore verification expectations

Priority order:

1. `OpenSIS` as the reference implementation baseline
2. `observability-stack`
3. `SwiftPay`
4. `FoodPulse`
5. `MemFlip`

Why this order:

- `OpenSIS` already has concrete backup and restore workflows
- `observability-stack` is the control plane and should not lag behind the app workloads
- `SwiftPay`, `FoodPulse`, and `MemFlip` can then inherit one common platform contract

Status:

- complete at the owned workload level

### Slice 2. Durability Validation And Restore Drills

Goal:

- prove that state continuity and restore behavior work in practice, not just on paper

Outputs:

- restart validation evidence
- stop/start validation evidence
- restore drill evidence
- gap log for any workload that still lacks repeatable recovery proof

Status:

- core restore-drill coverage complete for the owned app and control-plane state stores
- the shared Vault control plane now has live save, rollback-restore, and forward-restore evidence on integrated Raft
- broader restart and pressure-validation work remains open

### Slice 3. Operator Access And Break-Glass Hardening

Goal:

- reduce weak or implicit operator access assumptions

Outputs:

- hardened ArgoCD access guidance
- clearer break-glass procedures
- explicit admin and recovery paths for protected platform surfaces

Status:

- ArgoCD operator access and break-glass guidance documented
- restore-drill GitOps suspension and re-enable path scripted
- Vault operator access and break-glass guidance documented
- Vault and host-side protected-surface access model documented
- protected-surface status snapshot scripted
- Vault access status and break-glass verification scripted
- host-side recovery readiness verification scripted
- observability control-plane database initialization corrected toward ArgoCD hook semantics instead of steady-state Job drift
- remaining access limitations are now classified as intentional local-runtime constraints or later-stage maturity work

### Slice 4. Runtime Pressure And Placement Validation

Goal:

- determine what stays healthy under tighter runtime conditions

Outputs:

- validated probe and HPA behavior notes
- resource-pressure findings
- single-node versus multi-node assumptions called out explicitly

Status:

- first live Slice 4 validation pass executed
- the first pass exposed a node-level runtime wedge and CNPG lifecycle instability
- the second pass showed the Metrics API path working again during the drill window
- SwiftPay HPA scale-up is now live-observed evidence, not only declared intent
- a third SwiftPay-specific pass hardened the auth-service dev baseline and converted the prior bounded registration failure into a clean `8/8` successful public-ingress run
- a fourth SwiftPay-specific pass established that the next bounded `12/12` profile still fails on auth registration timeout and auth-service health convergence, while remaining a workload-level failure rather than a node wedge
- a fifth and sixth SwiftPay-specific follow-up on `2026-06-13` showed that increasing auth register timeout, softening probes, and then holding auth-service warm at `3` replicas improved recovery behavior and raised the `12`-way result from `0/12` to `2/12`, but still did not produce a clean `12/12` success band
- a seventh SwiftPay-specific isolation pass on `2026-06-13` confirmed that direct auth-service registration from the live api-gateway path can succeed but still starves auth-service health enough to force a liveness-driven pod restart under `12`-way burst load
- an eighth SwiftPay-specific hardening pass on `2026-06-28` added auth-service registration-stage timing and database-pool instrumentation so the next concurrency rerun can measure the bottleneck directly instead of inferring it from gateway symptoms
- a ninth SwiftPay-specific rerun on `2026-06-28` used the new instrumentation and improved the bounded `12`-way outcome to `7/12`, while confirming bcrypt hashing as the dominant completed registration-path cost and preserving namespace stability
- a tenth SwiftPay-specific rerun on `2026-06-28` tested a dev-only lower bcrypt cost and showed that faster hashing alone did not stabilize the `12`-way band, with the result falling back to `5/12` and probe stress still present
- an eleventh SwiftPay-specific rerun on `2026-06-28` activated explicit per-pod registration concurrency control in the live auth-service env contract and produced the first clean bounded `12/12` public-ingress success result without auth-service probe collapse
- a twelfth SwiftPay-and-observability follow-up on `2026-06-28` proved that the post-success latency alerts were caused by Service-level Prometheus scraping across scaled replicas, and corrected the monitoring path to pod-backed endpoint discovery with explicit Prometheus discovery RBAC
- a FoodPulse lifecycle pass confirmed the preserved stop/start workflow must suspend ArgoCD automation first and now has a validated GitOps-safe round-trip
- a thirteenth Slice 4 runtime revalidation on `2026-06-29` showed the hardened FoodPulse preserved stop/start path converging cleanly end to end on the live node, with stale ArgoCD comparison noise cleared, CNPG hibernation and rehydration succeeding, and only transient probe turbulence remaining
- a fourteenth Slice 4 follow-up on `2026-06-29` classified the remaining noise boundary more cleanly: ArgoCD sync churn and short readiness failures now read as expected local convergence behavior, while isolated observability-UI liveness timeouts remain a service-level hardening concern rather than current proof of node-wide instability
- a fifteenth Slice 4 follow-up on `2026-06-29` hardened `devops-monitor-ui` by adding a dedicated `/api/health` route plus startup, readiness, and liveness probe tolerance tuned for the single-replica control-plane UI path
- a controlled `FoodPulse` stop/start drill exposed CNPG admission instability during node degradation
- the local `colima` node entered a `PLEG`-driven `NotReady` state during the drill window
- the current recovery path required a full Colima recycle rather than a clean in-cluster converge
- follow-up validation remains open because the app-level SwiftPay burst path is now stabilized locally and the hardened FoodPulse lifecycle path is revalidated, but the broader single-node runtime failure modes still need cleaner separation from transient local convergence noise

### Slice 5. Broader Production-Path Proof

Goal:

- increase live proof for production-style operating paths beyond the primary `dev` runtime

Outputs:

- selected production-overlay validation evidence
- stronger dev/prod contract guidance
- clearer documentation on what is Git-defined intent versus what has been live-exercised

Status:

- production overlay render validation complete across the owned repos
- shared dependency and CRD baseline confirmed live in-cluster
- production observability TLS challenge reconciliation proven live, with final issuance still blocked by external environment conditions
- production Vault-backed secret delivery proven live in the paused `platform-observability-prod` namespace
- centralized dormant `prod` app-of-apps composition now present and client-side validated in the platform repo
- production observability network-policy posture now reads more coherently across the owned apps after correcting the SwiftPay `prod` overlay
- production namespace-governance posture now reads more coherently in Git after standardizing namespace labels and adding missing `prod` `ResourceQuota` contracts

## Phase 8 Definition Of Done

Phase 8 can be considered successful when:

- backup and restore are platform controls rather than isolated app scripts
- at least one restore drill path exists for each protected stateful workload class
- operator access and recovery flows are documented and repeatable
- runtime and placement assumptions are explicit and evidence-backed
- the platform can defend a stronger production-style claim under failure and operational stress

## Immediate Next Step

Close Phase 8 formally and transition cleanly:

- stop treating additional work as a new implicit Phase 8 slice, because the approved plan ends at Slice 5
- preserve the current `dev` cluster as the primary validated operating baseline until a later phase explicitly authorizes broader runtime risk
- treat the current `prod` path as stronger production-style contract proof, not as live production-runtime proof by itself
- keep the remaining production TLS issuance gap classified as an external environment constraint in this local setup unless a later phase explicitly chooses to remediate DNS and edge-routing behavior
- use the next phase decision to choose among:
  - controlled live activation of selected dormant `prod` GitOps paths
  - broader runtime-class validation beyond the current single-node local platform
  - consolidation, documentation normalization, and release discipline across the owned repos
