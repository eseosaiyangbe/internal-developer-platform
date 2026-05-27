# Phase 8 Backup And Restore Standard

Date: `2026-05-23`
Updated: `2026-05-27`

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

`OpenSIS` remains the reference implementation shape because it now has:

- backup execution helpers
- backup inspection helpers
- restore reset flow
- restore execution flow
- restore verification flow
- runbook and architecture documentation describing why backup failure matters operationally
- a validated live backup artifact
- a validated live restore drill under GitOps-managed runtime conditions

Reference docs:

- [OpenSIS operations runbook](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/docs/04-operations-runbook.md)
- [OpenSIS architecture reference](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/docs/06-architecture-reference.md)

## Current Implementation Status

### `OpenSIS`

Status:

- implemented
- live backup validated
- live restore drill validated

Current evidence:

- backup artifact:
  - `opensis-20260527T163506Z.sql.gz`
- restore verification:
  - `102` tables restored
  - `app` table row count `5`
- schedule:
  - `0 2 * * *`
  - `Etc/UTC`
- retention:
  - newest `7` archives

### `observability-stack`

Status:

- implemented
- live backup validated
- live restore drill validated

Current evidence:

- backup artifacts:
  - `observability-postgres-20260523T210236Z.dump`
  - `alertmanager-20260523T210236Z.tgz`
- restore verification includes:
  - PostgreSQL-backed control-plane state
  - Grafana dashboard state
  - Alertmanager persisted state
- schedule:
  - `0 3 * * *`
  - `Etc/UTC`
- retention:
  - newest `7` backup sets

### `SwiftPay`

Status:

- implemented
- live backup validated
- live restore drill validated

Current evidence:

- backup artifacts:
  - `swiftpay-postgres-20260523T214822Z.dump`
  - `swiftpay-redis-20260523T214822Z.rdb`
- restore verification includes:
  - relational state
  - Redis persisted state
- schedule:
  - `0 2 * * *`
  - `Etc/UTC`
- retention:
  - newest `7` backup sets

### `FoodPulse`

Status:

- implemented
- live backup validated
- live restore drill validated

Current evidence:

- backup artifacts:
  - `foodpulse-postgres-20260525T033228Z.dump`
  - `foodpulse-redis-20260525T033228Z.rdb`
- restore verification includes:
  - PostgreSQL relational state
  - Redis persisted state
- schedule:
  - `0 4 * * *`
  - `Etc/UTC`
- retention:
  - newest `7` backup sets

### `MemFlip`

Status:

- implemented
- live backup validated
- live restore drill validated

Current evidence:

- backup artifacts:
  - `memflip-postgres-20260525T043725Z.dump`
  - `memflip-redis-20260525T043725Z.rdb`
- restore verification includes:
  - PostgreSQL relational state
  - Redis persisted state
- schedule:
  - `0 5 * * *`
  - `Etc/UTC`
- retention:
  - newest `7` backup sets

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

## Current Outcome

The app-level and control-plane recovery contract is now implemented across the owned workloads.

Use [PHASE8-BACKUP-RESTORE-IMPLEMENTATION-STATUS.md](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/PHASE8-BACKUP-RESTORE-IMPLEMENTATION-STATUS.md) as the operational status record for:

- validated artifacts
- validated restore-drill evidence
- standardized schedules
- standardized retention

## Next Phase 8 Focus After Standardization

The next major Phase 8 follow-on work should be:

1. operator access and break-glass hardening
2. restart and pressure-validation coverage beyond restore drills
3. broader production-path proof
