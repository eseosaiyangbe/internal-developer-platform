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

## Second Validation Pass

Date: `2026-06-03`

## Validation Baseline

Baseline captured before the second drill window:

- timestamp: `2026-06-03T16:46:18Z`
- cluster running pods: `65`
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
  - status: `Ready`
- live resource metrics working again:
  - `kubectl top node` succeeded
  - SwiftPay HPAs reported real CPU and memory targets instead of `unknown`

## What This Validation Attempt Targeted

The second Slice 4 pass focused on three concrete runtime questions:

1. Is the Metrics API path healthy enough to treat SwiftPay HPA behavior as evidence-backed?
2. Does controlled parallel traffic against the public SwiftPay ingress trigger real autoscaling?
3. After removing a known test-harness defect, does the public registration and transaction path remain stable under bounded parallel demand?

## Findings

### 1. The Metrics API path is currently usable again

Observed state before the drill:

- `kubectl top` succeeded
- SwiftPay HPAs reported live CPU and memory utilization
- HPA conditions showed `ScalingActive=True` and `ValidMetricFound`

What this means:

- the earlier Metrics API blockage from the first Slice 4 pass is not the current limiting factor
- HPA observations from this second pass can be treated as real runtime evidence

This does not prove the metrics path is permanently stable.

It does prove the current drill window had a working autoscaling signal path.

### 2. SwiftPay autoscaling was observed live under bounded public-ingress pressure

The drill used bounded concurrent executions of the public `smoke-send-money.sh` path against:

- `https://swiftpay.eseosadevbox.com/api`

Observed scale behavior:

- `auth-service-hpa` scaled from `1` to `2`, then from `2` to `3`
- `api-gateway-hpa` scaled from `1` to `2`
- these rescale events were confirmed both by live HPA snapshots and by HPA events:
  - `auth-service-hpa`: `SuccessfulRescale`
  - `api-gateway-hpa`: `SuccessfulRescale`

Observed runtime state after scale-up:

- `api-gateway` deployment: `2/2`
- `auth-service` deployment: `3/3`
- all managed applications remained `Synced Healthy`
- the node remained `Ready`
- no repeat of the earlier `PLEG` wedge occurred during this SwiftPay-specific drill

What this means:

- SwiftPay now has evidence-backed live autoscaling behavior in the local `k3s` runtime
- the current local runtime can absorb this class of stateless scale-up without repeating the broader node-level failure seen in the earlier `FoodPulse` lifecycle drill

### 3. The initial non-zero load result was caused by a test-harness defect, not by SwiftPay itself

The first bounded concurrent run returned a non-zero result.

Root cause identified from live auth-service logs:

- the original `smoke-send-money.sh` script generated account emails using only second-level timestamp precision
- concurrent executions created duplicate email addresses
- auth-service returned PostgreSQL uniqueness violations on `users.email`

This was a test artifact, not a trustworthy platform failure signal.

The operator script was corrected to include extra uniqueness in the generated stamp:

- file: `SwiftPay/scripts/smoke-send-money.sh`
- change: stamp now includes second-level timestamp plus process ID and random suffix

### 4. After fixing the harness defect, bounded parallel registration still exposed a real runtime weakness

After the uniqueness fix, a follow-up bounded concurrent `smoke-send-money.sh` run still failed.

Observed state:

- all `8` concurrent runs failed
- failure point was `POST /api/auth/register`
- api-gateway returned HTTP `500`
- api-gateway structured logs now show the upstream failure class directly:
  - `message: timeout of 10000ms exceeded`
  - `code: ECONNABORTED`
  - `status: null`
- api-gateway circuit-breaker failure count increased from `1` through `8`
- the auth-service circuit breaker opened after the fifth upstream timeout
- Kubernetes events recorded auth-service probe instability during the same window:
  - HPA rescaled auth-service from `1` to `3`
  - readiness probe failures
  - liveness probe failures
  - restart of the original serving auth-service pod during scale-up

What this means:

- the remaining failure is no longer explained by duplicate test identities
- the current public registration path still has a real concurrency weakness under bounded parallel pressure
- the observable failure boundary currently appears at or before the auth registration path, not in the transaction-processing path
- the issue is not only client-visible; it also degrades auth-service pod health under pressure while new replicas are still converging

Current evidence is now strong enough to narrow the defect materially:

- api-gateway is waiting `10s` for auth-service and timing out upstream
- auth-service does scale out, but not fast enough to absorb the registration burst before the gateway timeout window closes
- the original serving pod becomes unhealthy during the same scale-up interval
- the dev overlay currently makes this worse by allowing auth-service to idle at `1` replica with reduced resource requests (`75m` CPU and `128Mi` memory) versus the stronger base contract

### 5. Slice 4 now has both positive proof and a concrete remaining defect

The second pass materially improves Slice 4 confidence:

- positive proof:
  - Metrics API usable during drill window
  - SwiftPay HPA scale-up observed live
  - node stayed healthy
  - control plane stayed healthy
- remaining defect:
  - public auth registration path does not yet handle bounded parallel pressure cleanly

## Classification

### Confirmed Slice 4 improvements

- SwiftPay HPA behavior is now live-observed, not just Git-defined intent
- the local runtime can perform at least one real stateless scale-up path without triggering a node wedge
- the earlier Metrics API `unknown` state is not currently blocking Slice 4 validation

### Confirmed Slice 4 defects

- `SwiftPay` public registration is not yet dependable under bounded parallel pressure
- auth-service can still hit readiness and liveness failures during burst registration scale-up
- the current SwiftPay dev overlay weakens auth-service resilience by shrinking resource requests and allowing a single warm replica

### Still-acceptable local-runtime constraints

- single-node-only live placement proof
- one-time Colima restart as an allowed recovery action
- local-runtime rather than production-grade scheduler diversity

## Status

Slice 4 remains in progress.

Current honest status after the second pass:

- Metrics API path is usable in the current drill window
- SwiftPay autoscaling now has live evidence
- the local node remained healthy during the bounded SwiftPay load pass
- a real concurrency defect remains on the SwiftPay registration path
- the defect is now narrowed to upstream auth-service timeout and convergence behavior rather than an opaque gateway-only failure

## Immediate Next Steps

1. Keep the `smoke-send-money.sh` uniqueness fix as the new operator baseline for future Slice 4 drills.
2. Keep the improved api-gateway register-path diagnostics as the new baseline evidence path.
3. Harden the SwiftPay dev overlay so auth-service keeps stronger baseline requests and at least two warm replicas during public-ingress pressure.
4. Re-run a bounded auth-focused concurrency drill after the overlay hardening lands.
5. Continue separating app-path defects from node-runtime defects before closing Slice 4.
