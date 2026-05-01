# Phase 7 k3s Dev Resource Audit

## Purpose

This document captures the first shared-cluster resource audit for the local `k3s` development environment.

The goal is to compare:

- Kubernetes `requests`, which control scheduling
- live pod consumption, which reflects actual runtime usage

This distinction matters because the scheduler places pods based on reserved capacity, not current usage.

## Audit Date

- `2026-05-01`

## Environment

- cluster runtime: `k3s` on `colima`
- node count: `1`
- node name: `colima`

## Key Finding

The cluster was CPU-constrained from a scheduling perspective even when live CPU usage was low.

That is the critical platform lesson:

- low `kubectl top` usage does not mean the cluster has scheduling headroom
- oversized `requests` in a shared single-node `dev` cluster create artificial capacity pressure
- rollout strategies that require temporary extra capacity can deadlock otherwise healthy applications

## Node Allocation Snapshot

Measured after the SwiftPay dev-only right-sizing pass:

- CPU requests: `3175m / 4 cores` (`79%`)
- Memory requests: `6816Mi` (`86%`)

This is improved from the earlier `100%` CPU-request saturation that blocked SwiftPay's migration job, but it is still dense enough to justify further `dev` tuning.

## Requested Versus Live Consumption

| App | Pods | CPU Request | Live CPU | CPU Request / Live | Memory Request | Live Memory | Memory Request / Live |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| MemFlip | 4 | 300m | 12m | 25.0x | 576Mi | 115Mi | 5.0x |
| SwiftPay | 10 | 735m | 36m | 20.4x | 1408Mi | 387Mi | 3.6x |
| FoodPulse | 7 | 1600m | 39m | 41.0x | 3488Mi | 284Mi | 12.3x |
| OpenSIS | 3 | 50m | 9m | 5.6x | 624Mi | 185Mi | 3.4x |
| Obervability-Stack | 10 | 800m | 48m | 16.7x | 1824Mi | 976Mi | 1.9x |

## Interpretation

### Highest Priority

- `FoodPulse`
  - strongest reservation outlier in the current cluster
  - main drivers are:
    - `CloudNativePG` requests
    - three Redis pods, each carrying both `redis` and `sentinel` containers

- `MemFlip`
  - much smaller absolute footprint than `FoodPulse`
  - still clearly oversized relative to real demand in `dev`

### Medium Priority

- `SwiftPay`
  - already improved materially
  - still somewhat oversized, but no longer the primary scheduling risk

### Lower Priority

- `OpenSIS`
  - current `dev` overlay is already relatively compact
  - does not appear to be a first-round right-sizing target

- `Obervability-Stack`
  - still conservative, but much closer to a reasonable always-on platform footprint
  - should be reviewed later with extra care because aggressive cuts here can degrade monitoring fidelity

## Dev Versus Prod Policy

This audit applies to the shared single-node `dev` cluster.

It does not justify weakening production resource contracts.

### Dev Policy

- optimize for portability and schedulability
- keep limits higher than requests to preserve burst tolerance
- prefer `maxSurge: 0` and `maxUnavailable: 1` for stateless rollouts on constrained clusters
- right-size based on measured behavior, not guesswork

### Prod Policy

- size for predictable steady-state runtime
- preserve failover, disruption, and headroom expectations
- do not copy `dev` request values into `prod`
- review requests against real production load and SLO targets

## First-Round Actions

### Implement Now

- add `dev`-only right-sizing patches for `MemFlip`
- add `dev`-only right-sizing patches for `FoodPulse`
- add `dev`-only rollout strategy patches for stateless deployments in both apps

### Preserve For Now

- keep `FoodPulse` PostgreSQL at `2` instances in `dev`
- keep `FoodPulse` Redis/Sentinel topology at `3` replicas in `dev`

This keeps the resilience pattern intact while reducing the scheduler pressure caused by oversized requests.

## Next Review Areas

- confirm post-patch node allocation improves materially
- re-check whether `FoodPulse` still justifies the current `dev` HA shape after the shared-cluster certification pass
- perform a later second-pass review of:
  - `Obervability-Stack`
  - `OpenSIS`
  - `SwiftPay` HPAs and rollout posture
