# MemFlip As The First Kubernetes Migration Candidate

## Purpose

This document explains why `MemFlip` should be the first workload migrated after the control plane.

It is not the most important app in the workspace.
It is the cleanest first migration candidate.

## Why MemFlip Goes First

The first migrated workload should reduce risk, not maximize complexity.

`MemFlip` is the right first candidate because it is:

- small enough to reason about quickly
- already observable from the control plane
- easy to validate from both browser and API health paths
- not burdened by the platform complexity of Vault, HA routing, or queue-heavy microservices

## Current Architecture

`MemFlip` currently consists of:

- frontend
- backend
- PostgreSQL
- Redis

That makes it a strong transitional workload:

- simple enough for early Kubernetes validation
- still real enough to exercise ingress, services, env config, secrets, and stateful dependencies

## Why It Is Better Than The Other Candidates

### Better first candidate than `SwiftPay`

`SwiftPay` is more important strategically, but it is a poor first migration candidate because:

- it has more services
- it has queueing complexity
- it has richer cross-service dependencies
- it deserves a calmer, more deliberate migration after the platform pattern is proven

### Better first candidate than `OpenSIS`

`OpenSIS` is the most operationally interesting app, but it is too heavy for the first move because:

- Vault is already part of the story
- MariaDB and secret rendering add complexity
- the runtime wrapping is more fragile than a simple service stack

### Better first candidate than `FoodPulse`

`FoodPulse` is valuable, but it is not the best first move because:

- failover, Sentinel, replicas, and HAProxy complicate the teaching surface
- it is better used after the basic migration pattern is established

## What MemFlip Lets Us Prove

Migrating `MemFlip` first lets us prove:

- service discovery translation from Compose aliases to Kubernetes Services
- environment variable and secret mapping
- frontend and backend ingress/service design
- observability continuity from the control plane
- database and cache connectivity assumptions
- basic rollout and smoke-check discipline

## Recommended Resource Model

Expected Kubernetes shape:

- `Deployment`: frontend
- `Deployment`: backend
- `Service`: frontend
- `Service`: backend
- `Ingress`: user-facing route
- `ConfigMap`: non-secret runtime config
- `Secret`: database/session credentials
- `StatefulSet` or managed service: PostgreSQL
- `StatefulSet` or managed service: Redis

## Migration Objectives

The MemFlip migration should not try to solve everything at once.

Primary objectives:

1. preserve user-facing availability
2. preserve backend health and metrics
3. preserve control-plane visibility
4. preserve a simple onboarding story

## Validation Requirements

The migration should only be considered successful when all of these still work:

- browser access to the app
- backend health endpoint
- control-plane app status
- probe visibility
- logs path
- app-specific operator page relevance

## Risks

### 1. Making The Simple App Too Complex

If we over-engineer the first migration, the teaching value drops.

Mitigation:

- keep the resource model minimal
- avoid adding complexity that exists only for aesthetics

### 2. Losing Observability Continuity

If MemFlip moves but the control plane no longer sees it clearly, the migration pattern is not good enough for larger workloads.

Mitigation:

- require observability parity as part of done criteria

### 3. Hiding Environment Assumptions

If MemFlip only works because of undeclared local defaults, the migration will appear cleaner than it really is.

Mitigation:

- freeze env contract before manifest authoring

## Recommended Migration Sequence

1. inventory MemFlip env inputs and runtime dependencies
2. define `dev` Kubernetes manifests
3. wire the app back into the shared control plane
4. validate browser, API, probes, metrics, and logs
5. then capture the pattern as the template for later workloads

## What Success Looks Like

When MemFlip is migrated well, it becomes:

- the first proof that the workspace can move beyond Compose
- the reference app for future workload migrations
- the lowest-risk template for onboarding and environment separation

That is why it is the right first candidate.
