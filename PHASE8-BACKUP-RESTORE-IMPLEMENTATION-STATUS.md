# Phase 8 Backup And Restore Implementation Status

Date: `2026-05-27`

## Purpose

This document records the live implementation and validation status of the Phase 8 backup and restore contract across the owned workloads.

This is the operational status view, not just the design intent view.

## Platform-Level Summary

The app-level and control-plane backup contract is now implemented across:

- `observability-stack`
- `SwiftPay`
- `FoodPulse`
- `MemFlip`
- `OpenSIS`

Standardized contract now in place:

- automated backup `CronJob` per protected workload class
- explicit `Etc/UTC` backup schedules
- count-based retention of the newest `7` backup sets
- manual backup execution helpers
- backup inspection helpers
- backup cleanup helpers
- restore execution helpers
- restore verification helpers
- runbook documentation
- controlled restore-drill guidance with temporary GitOps automation suspension and re-enable flow where required

## Current Validated Status

### `observability-stack`

Status:

- implemented
- live backup validated
- live restore drill validated

Validated evidence:

- backup artifacts:
  - `observability-postgres-20260523T210236Z.dump`
  - `alertmanager-20260523T210236Z.tgz`
- restore verification proved:
  - `_prisma_migrations`
  - `notification_events`
  - `notification_settings`
  - Grafana dashboard state
  - Alertmanager persisted state

Key notes:

- backup is automated through `CronJob/observability-control-plane-backup`
- schedule is `0 3 * * *` in `Etc/UTC`
- retention is the newest `7` backup sets

### `SwiftPay`

Status:

- implemented
- live backup validated
- live restore drill validated

Validated evidence:

- backup artifacts:
  - `swiftpay-postgres-20260523T214822Z.dump`
  - `swiftpay-redis-20260523T214822Z.rdb`
- restore verification proved:
  - `users`
  - `wallets`
  - `transactions`
  - Redis `dump.rdb`
  - Redis `appendonlydir/*`

Key notes:

- backup is automated through `CronJob/swiftpay-state-backup`
- schedule is `0 2 * * *` in `Etc/UTC`
- retention is the newest `7` backup sets

### `FoodPulse`

Status:

- implemented
- live backup validated
- live restore drill validated

Validated evidence:

- backup artifacts:
  - `foodpulse-postgres-20260525T033228Z.dump`
  - `foodpulse-redis-20260525T033228Z.rdb`
- restore verification proved:
  - `venues=8`
  - `vote_events=5`
  - Redis `dump.rdb`
  - Redis `appendonlydir/*`

Key notes:

- backup is automated through `CronJob/foodpulse-state-backup`
- schedule is `0 4 * * *` in `Etc/UTC`
- retention is the newest `7` backup sets

### `MemFlip`

Status:

- implemented
- live backup validated
- live restore drill validated

Validated evidence:

- backup artifacts:
  - `memflip-postgres-20260525T043725Z.dump`
  - `memflip-redis-20260525T043725Z.rdb`
- restore verification proved:
  - `users=9`
  - `games=5`
  - `game_matches=6`
  - Redis `dump.rdb`
  - Redis `appendonlydir/*`

Key notes:

- backup is automated through `CronJob/memflip-state-backup`
- schedule is `0 5 * * *` in `Etc/UTC`
- retention is the newest `7` backup sets

### `OpenSIS`

Status:

- implemented
- live backup validated
- live restore drill validated

Validated evidence:

- backup artifact:
  - `opensis-20260527T163506Z.sql.gz`
- restore verification proved:
  - `102` tables restored
  - `app` table row count `5`

Key notes:

- backup is automated through `CronJob/opensis-db-backup`
- schedule is `0 2 * * *` in `Etc/UTC`
- retention is the newest `7` backup archives

## Important Lessons From Implementation

### 1. GitOps authority must be respected during restore drills

For the owned `dev` paths, a live restore drill may require temporary removal of ArgoCD automated sync and then explicit re-enable plus hard refresh afterward.

### 2. Backup helper pods are part of the platform design

Helper pods required real production-style hardening:

- explicit CPU and memory requests and limits where namespace quotas demanded them
- correct network-policy allowances
- correct storage behavior
- clean CLI usage and predictable script behavior

### 3. Current runtime truth matters more than old design assumptions

Several drill fixes came from reconciling helper scripts to the live runtime:

- current secret mount paths
- current database ownership and restore identity
- current service reachability under network policy
- current container-start behavior under local runtime constraints

## Remaining Phase 8 Work After This Slice

The platform now has app-level backup and restore coverage.

The next major Phase 8 work should focus on:

1. operator access and break-glass hardening
2. broader restart, stop/start, and pressure-validation coverage
3. stronger production-path proof beyond the primary `dev` runtime
