## Phase 8 Slice 4 Runtime Pressure And Placement Validation

Date: `2026-05-30`

## Purpose

This document records the first live Slice 4 validation pass for the current local `k3s` platform.

It does not claim completion.

It captures:

- the runtime baseline before the drill
- what was validated successfully
- what failed under pressure
- which findings are true platform defects versus accepted local-runtime constraints
- what must happen before Slice 4 can be closed honestly

## Validation Baseline

Baseline captured before the main drill window:

- timestamp: `2026-05-30T09:51:46Z`
- cluster running pods: `66`
- ArgoCD applications healthy:
  - `internal-developer-platform-dev-root`
  - `observability-dev`
  - `swiftpay-dev`
  - `foodpulse-dev`
  - `memflip-dev`
  - `opensis-dev`
- node topology:
  - single node only
  - node: `colima`
  - runtime: `docker://29.2.1`
  - Kubernetes: `v1.35.0+k3s1`

## What This Validation Attempt Targeted

The first Slice 4 pass focused on four concrete runtime questions:

1. Are live HPA signals trustworthy enough to validate autoscaling behavior?
2. Does a controlled `FoodPulse` stop/start drill still converge cleanly after the recent Redis probe hardening?
3. Does the node remain stable while stateful and control-plane workloads reconcile together?
4. Which placement and runtime assumptions remain single-node-local rather than broadly production-safe?

## Findings

### 1. SwiftPay HPA intent exists, but live HPA validation is not trustworthy yet

Live `HorizontalPodAutoscaler` objects exist for the `swiftpay-dev` stateless services.

Observed state:

- all SwiftPay HPAs reported resource targets as `unknown`
- `kubectl top` failed with `Metrics API not available`
- HPA status reported:
  - `FailedGetResourceMetric`
  - `failed to get cpu utilization`
  - `failed to get memory utilization`
  - `unable to fetch metrics from resource metrics API`

What this means:

- HPA manifests are present
- HPA behavior cannot yet be treated as evidence-backed runtime scaling proof
- current autoscaling claims in the local runtime must remain qualified until the metrics path is stable

### 2. FoodPulse stop/start exposed a real local runtime defect

The controlled `FoodPulse` stop/start drill did not complete cleanly.

Observed failure:

- `./scripts/k8s-stop.sh` began scaling app components down
- the drill failed at CNPG hibernation with:
  - `failed calling webhook "mcluster.cnpg.io"`
  - `502 Bad Gateway`

At the same time, the CNPG controller showed repeated webhook and readiness instability and then lost leader election because calls to the Kubernetes API timed out.

This is not just a `FoodPulse` script issue.

It is a platform runtime failure mode affecting:

- CNPG admission and reconciliation
- app stop/start behavior
- stateful workload lifecycle confidence under pressure

### 3. The single `colima` node entered a real kubelet health failure

During the same validation window, the node transitioned to `NotReady`.

Observed node condition:

- `Ready=False`
- `Reason=KubeletNotReady`
- message:
  - `PLEG is not healthy: pleg was last seen active ... threshold is 3m0s`

Platform-wide consequences followed immediately:

- transient `TaintManagerEviction` activity across multiple namespaces
- CNPG leader-election loss
- Kubernetes API instability
- stuck `Pending`, `Error`, and `Terminating` pods across:
  - `foodpulse-dev`
  - `swiftpay-dev`
  - `platform-observability-dev`

This is the strongest Slice 4 result from the first pass:

- the current local single-node runtime can wedge under this class of runtime disturbance
- that wedge is broad enough to affect both workload recovery and control-plane recovery

### 4. A full Colima recycle was required to restore the runtime

The first lightweight recovery path was not enough.

Observed sequence:

- `recover-k3s-platform.sh` started but was blocked during degraded control-plane behavior
- `colima restart` was attempted
- Colima came back, but `k3s.service` remained failed
- direct inspection inside the VM showed:
  - `k3s.service` failed with `Result: timeout`
  - the prior server process was killed after stop timeout
- a clean `colima stop --force` followed by `colima start ... --kubernetes` was required

This confirms an important Slice 4 classification:

- one-time Colima restart escalation is an accepted local-runtime recovery action
- however, the platform currently depends on that action in a real runtime wedge, not just in theory

### 5. Placement proof remains local and single-node only

The current live node topology remains:

- one schedulable node
- no multi-node failure-domain spread

Production-style placement intent exists in Git for several repos, but the live local runtime still proves only:

- single-node scheduling behavior
- single-node contention behavior
- single-node recovery characteristics

It does not yet prove:

- multi-node spread
- anti-affinity effectiveness under real scheduler choice
- zone-style topology resilience

## What Was Learned

The first Slice 4 pass already gave us real evidence:

- platform backup and restore work from Slices 1 and 2 was necessary but not sufficient
- operator access hardening from Slice 3 was necessary but not sufficient
- the next real maturity gap is runtime stability under node-level stress and degraded API responsiveness

The local runtime currently shows three hard constraints:

1. HPA validation is blocked by an unstable metrics path
2. CNPG-backed workload lifecycle operations are vulnerable when the API server or kubelet degrades
3. the single-node `colima` runtime can enter a kubelet `PLEG` wedge severe enough to disrupt the broader platform

## Classification

### Confirmed Slice 4 defects

- HPA runtime evidence is not trustworthy while the Metrics API remains unstable
- `FoodPulse` stop/start is not currently a dependable runtime drill because CNPG webhook operations can fail during node instability
- the current local runtime can enter a `PLEG` wedge that breaks both workload and control-plane reconciliation

### Still-acceptable local-runtime constraints

- single-node-only live placement proof
- one-time Colima restart as an allowed recovery action
- local-runtime rather than production-grade scheduler diversity

These are acceptable constraints.

The defects above are not.

## Status

Slice 4 is now started and has real live evidence.

It is not complete.

Current honest status:

- baseline captured
- first runtime-pressure pass executed
- one major failure mode reproduced and recorded
- runtime recovery path exercised for real
- further validation must continue only after the platform is fully reconciled again

## Immediate Next Steps

1. Finish post-restart platform reconciliation and confirm all managed applications return to `Synced Healthy`.
2. Isolate why the Metrics API and HPA resource metrics are unstable in the current local runtime.
3. Repeat the controlled app-lifecycle drill after stabilization to confirm whether `FoodPulse` convergence issues were purely node-runtime-driven or also script-path-driven.
4. Record a second Slice 4 pass once the runtime is healthy enough to trust the next set of observations.
