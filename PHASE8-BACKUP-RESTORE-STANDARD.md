# Phase 8 Backup And Restore Standard

Date: `2026-05-23`

## Purpose

This document defines the platform-level backup and restore contract for the owned workloads.

Backup and restore are not optional app-local helpers.

They are platform controls that affect:

- durability claims
- operator confidence
- GitOps recovery credibility
- production-style maturity

## Standard Requirements

Every protected stateful workload should have all of the following:

1. backup execution path
2. backup inspection path
3. retention policy
4. restore execution path
5. restore verification path
6. runbook documentation
7. clear ownership of where backup artifacts live

## Workload Classes

### Class A. Primary Application Datastores

Includes:

- `OpenSIS` MariaDB
- `SwiftPay` PostgreSQL and supporting persistent state where relevant
- `FoodPulse` PostgreSQL and Redis state expectations
- `MemFlip` PostgreSQL and Redis state expectations

Required controls:

- manual backup path
- documented restore path
- restore verification path
- retention expectations
- operator runbook

### Class B. Control-Plane Stateful Data

Includes:

- `observability-stack` PostgreSQL-backed control-plane data
- Grafana metadata state
- Alertmanager state
- any control-plane notification or event state now stored in PostgreSQL

Required controls:

- backup path for the backing database or persistent state store
- restore path
- verification path
- retention expectations
- control-plane recovery notes

### Class C. Node-Local Or Cursor State

Includes:

- Promtail positions

Required controls:

- explicit statement that this is node-local continuity data, not shared restore state
- documented behavior on pod restart
- documented behavior on node loss

## Reference Implementation

`OpenSIS` is the current reference implementation shape because it already has:

- backup execution helpers
- backup inspection helpers
- restore reset flow
- restore execution flow
- restore verification flow
- runbook and architecture documentation describing why backup failure matters operationally

Reference docs:

- [OpenSIS operations runbook](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/docs/04-operations-runbook.md)
- [OpenSIS architecture reference](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/docs/06-architecture-reference.md)

## Current Implementation Status

### `OpenSIS`

Status:

- implemented baseline

Current evidence:

- one-off backup helper exists
- backup inspection helper exists
- restore reset helper exists
- restore execution helper exists
- restore verification helper exists
- runbook coverage exists

### `observability-stack`

Status:

- next implementation target

Current evidence:

- durability posture is materially stronger than before
- Grafana state is now PostgreSQL-backed
- Alertmanager is now PVC-backed
- Promtail positions are now node-local and persistent on the node
- platform-level backup and restore workflow is not yet documented as a unified operator contract

### `SwiftPay`

Status:

- gap to close

Current evidence:

- persistent services exist
- platform lifecycle controls exist
- backup and restore workflow is not yet documented as a first-class operational contract

### `FoodPulse`

Status:

- gap to close

Current evidence:

- persistent services exist
- platform lifecycle controls exist
- backup and restore workflow is not yet documented as a first-class operational contract

### `MemFlip`

Status:

- gap to close

Current evidence:

- persistent services exist
- platform lifecycle controls exist
- backup and restore workflow is not yet documented as a first-class operational contract

## Retention Expectations

At minimum, every protected backup workflow should define:

- how often backups run
- how long backups are retained
- where retained backups live
- how old backups are pruned
- whether retention differs between `dev` and `prod`

## Restore Verification Expectations

A restore is not complete when data is merely reloaded.

A restore is complete only when:

- the workload starts cleanly
- the application can serve expected traffic or health paths
- critical records or functional markers are verified
- the operator runbook records the verification steps

## Phase 8 Initial Implementation Order

1. document and implement `observability-stack` backup and restore contract
2. standardize `SwiftPay`
3. standardize `FoodPulse`
4. standardize `MemFlip`
5. then review whether `OpenSIS` needs alignment updates to match the final shared contract
