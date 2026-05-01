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

## Second-Round Platform Pass

On `2026-05-01`, the same audit pattern was extended to the always-on `Obervability-Stack` `dev` slice.

### Before Platform Right-Sizing

- platform namespace requests:
  - CPU: `700m`
  - Memory: `1568Mi`
- measured live usage:
  - CPU: `64m`
  - Memory: `1008Mi`
- ratio:
  - CPU: `10.9x`
  - Memory: `1.6x`

### Safe Dev-Only Changes Applied

- reduced CPU requests for:
  - `alertmanager`
  - `blackbox-exporter`
  - `devops-monitor-ui`
  - `grafana`
  - `loki`
  - `prometheus`
  - `node-exporter`
  - `promtail`
  - `observability-postgres`
- preserved more conservative memory for:
  - `promtail`
  - `cadvisor`
  - `prometheus`

This was deliberate. Those components either already had modest headroom or were close enough to live memory usage that aggressive cuts would have been reckless.

### Additional Platform Finding

`CloudNativePG` in the observability slice inherits long default restart and switchover timers.

That is a sound default for resilient environments, but it is unnecessarily slow for the shared single-node `dev` lab when we are only changing resource requests. A `dev`-only CNPG operations patch now shortens:

- `startDelay`
- `stopDelay`
- `smartShutdownTimeout`
- `switchoverDelay`

This keeps `prod` behavior untouched while making `dev` rollouts materially more operable.

### After Platform Right-Sizing

- platform namespace requests:
  - CPU: `395m`
  - Memory: `1424Mi`
- measured live usage after stabilization:
  - CPU: `71m`
  - Memory: `460Mi`
- ratio:
  - CPU: `5.6x`
  - Memory: `3.1x`

### Cluster-Level Outcome

After the application and observability right-sizing passes:

- node CPU requests dropped to `2020m` (`50%`)
- node memory requests dropped to `5008Mi` (`63%`)

The full operator verification remained green:

- smoke check: `30/30`
- inventory check: `0` errors
- workspace app snapshot: `4 healthy / 0 down`

## OpenSIS Follow-Up Pass

On `2026-05-01`, `OpenSIS` received a follow-up review using the same requested-versus-live method.

### Important Difference

Unlike `FoodPulse` and `MemFlip`, `OpenSIS` had already been through an earlier `dev`-overlay compaction pass.

That meant the right answer was not “shrink everything again.”

The live profile showed:

- total requests:
  - CPU: `50m`
  - Memory: `624Mi`
- live usage:
  - CPU: `29m`
  - Memory: `185Mi`
- ratio:
  - CPU: `1.7x`
  - Memory: `3.4x`

The `opensis-ui` container was already using more CPU than its existing request, so reducing it further would have been misleading and operationally unsafe.

### OpenSIS Dev Adjustments

- increased `opensis-ui` CPU request from `10m` to `25m`
- reduced `opensis-db` memory request from `384Mi` to `320Mi`
- reduced `opensis-session-redis` requests to:
  - CPU: `10m`
  - Memory: `24Mi`
- added `maxSurge: 0` and `maxUnavailable: 1` for:
  - `opensis-ui`
  - `opensis-session-redis`

### Result

After the follow-up pass:

- total requests:
  - CPU: `45m`
  - Memory: `600Mi`
- live usage after stabilization:
  - CPU: `15m`
  - Memory: `187Mi`
- ratio:
  - CPU: `3.0x`
  - Memory: `3.2x`

This is a good example of production-minded right-sizing:

- reduce waste where safe
- correct under-requesting where it is misleading
- preserve startup and secret-delivery stability
