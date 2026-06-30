# Phase 9 Execution Plan

Date: `2026-06-30`

## Purpose

This document starts Phase 9 as an explicit, bounded next phase after Phase 8 closeout.

Phase 9 is the AI-infrastructure and operator-augmentation phase.

It does not replace the platform controls earned in Phase 8.

It builds on them.

## Strategic Decision

Phase 9 adopts the AI-infrastructure direction already defined in [AI-INFRASTRUCTURE-ADOPTION-ROADMAP.md](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/AI-INFRASTRUCTURE-ADOPTION-ROADMAP.md).

The recommended operating model is:

1. self-host upstream Hermes as a private runtime
2. keep the current repo-local Hermes script as the trusted platform control adapter
3. preserve a read-only default for cluster inspection and recommendation flows
4. require manual operator approval for every proposed change

## Why This Is The Right Next Phase

Phase 8 made the platform operationally credible.

That created the conditions for an AI layer that can:

- summarize cluster and ArgoCD state faster
- accelerate incident-note creation
- improve operator navigation across the workload portfolio
- propose remediation steps without weakening control discipline

The wrong next phase would be a generic assistant bolted onto the repo.

The right next phase is a controlled AI-operating layer with explicit guardrails.

## Phase 9 Scope

Phase 9 is organized into five ordered slices.

1. Hermes naming and control-boundary cleanup
2. private self-hosted Hermes runtime
3. read-only tool integration
4. incident intelligence and bounded memory discipline
5. private access and scheduled reporting

## Current Guardrails

These guardrails are mandatory for Phase 9:

- no public Hermes exposure
- no direct Kubernetes mutation from the AI runtime
- no direct Vault write access from the AI runtime
- no ArgoCD sync, suspend, resume, or refresh privileges from the AI runtime
- every AI recommendation must reduce to observation, summary, and manual next-step guidance

## Slice Order

### Slice 1. Naming And Control-Boundary Cleanup

Goal:

- remove ambiguity between upstream Hermes and the repo-local Hermes adapter

Outputs:

- stable naming for the local platform adapter
- docs that distinguish:
  - AI runtime
  - platform control adapter
- updated command references and operator language

### Slice 2. Private Self-Hosted Hermes Runtime

Goal:

- run upstream Hermes locally without exposing it publicly

Outputs:

- local runtime install path
- startup and stop procedure
- persistence path
- security posture and restart guidance

### Slice 3. Read-Only Tool Integration

Goal:

- let the private Hermes runtime use the local platform adapter as a tool surface

Outputs:

- health inspection integration
- ArgoCD summary integration
- safe log-read integration
- incident-note generation integration
- remediation proposal integration

### Slice 4. Incident Intelligence And Memory Discipline

Goal:

- make Hermes operationally useful rather than merely interactive

Outputs:

- incident-note templates
- app-aware heuristics
- bounded local memory rules
- evidence-driven operator summary format

### Slice 5. Private Access And Scheduled Reporting

Goal:

- make Hermes available beyond one terminal session without weakening the trust model

Outputs:

- approved private access path
- optional scheduled read-only reporting
- morning summary and drift-summary pattern

## Definition Of Done

Phase 9 can be considered successful when:

- Hermes is clearly split into runtime and control-adapter roles
- the self-hosted runtime is private, restartable, and documented
- read-only platform inspection works end to end through the AI layer
- incident-note generation is faster and more structured than manual drafting
- private access and optional scheduling exist without introducing uncontrolled mutation

## Explicit Non-Goals

Phase 9 does not promise:

- autonomous remediation
- public AI endpoints
- AI-issued `kubectl apply`, `patch`, `delete`, or ArgoCD sync operations
- direct Vault mutation
- production-grade multi-tenant agent hosting

## Immediate Next Step

Start with Slice 1:

- rename the repo-local Hermes command surface so it is clearly the platform control adapter
- update central docs to remove naming ambiguity before introducing the upstream runtime itself
