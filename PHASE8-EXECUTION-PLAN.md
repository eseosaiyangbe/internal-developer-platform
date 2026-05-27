# Phase 8 Execution Plan

Date: `2026-05-23`
Updated: `2026-05-27`

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

As of `2026-05-27`:

- Slice 1 is complete at the app-contract level
- Slice 2 has live restore-drill evidence across the owned stateful workloads
- Slice 3 is now started with the ArgoCD access and break-glass contract documented

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
- observability control-plane database initialization corrected toward ArgoCD hook semantics instead of steady-state Job drift
- broader protected-surface access hardening still remains open

### Slice 4. Runtime Pressure And Placement Validation

Goal:

- determine what stays healthy under tighter runtime conditions

Outputs:

- validated probe and HPA behavior notes
- resource-pressure findings
- single-node versus multi-node assumptions called out explicitly

### Slice 5. Broader Production-Path Proof

Goal:

- increase live proof for production-style operating paths beyond the primary `dev` runtime

Outputs:

- selected production-overlay validation evidence
- stronger dev/prod contract guidance
- clearer documentation on what is Git-defined intent versus what has been live-exercised

## Phase 8 Definition Of Done

Phase 8 can be considered successful when:

- backup and restore are platform controls rather than isolated app scripts
- at least one restore drill path exists for each protected stateful workload class
- operator access and recovery flows are documented and repeatable
- runtime and placement assumptions are explicit and evidence-backed
- the platform can defend a stronger production-style claim under failure and operational stress

## Immediate Next Step

Proceed to Slice 3:

- extend the same explicit access and break-glass model to any remaining protected platform surfaces not yet covered
- review which remaining manual operator actions should still become scripted helpers
- classify which live interventions are acceptable local-runtime recovery actions versus hardening gaps to remove
