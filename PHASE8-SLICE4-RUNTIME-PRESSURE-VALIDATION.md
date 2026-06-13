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

## Third Pass Update

The third SwiftPay-specific Slice 4 pass re-ran the same bounded public-ingress drill after hardening the live dev baseline for `auth-service`.

Applied hardening before the rerun:

- auth-service dev resource requests raised from `75m` CPU and `128Mi` memory to `250m` CPU and `256Mi` memory
- auth-service HPA `minReplicas` raised from `1` to `2`

Observed state before the rerun:

- `swiftpay-dev` `Synced Healthy`
- auth-service deployment requests live at `250m|256Mi`
- auth-service HPA floor live at `2`
- auth-service steady state at `2/2` running replicas before pressure started

Observed result from the rerun:

- bounded `8`-way concurrent `smoke-send-money.sh` run completed with `RC=0`
- `SUCCESS_COUNT=8`
- `FAIL_SIGNAL_COUNT=0`
- api-gateway logs did not show the earlier `ECONNABORTED` upstream registration timeouts
- api-gateway remained healthy at `1/1`
- auth-service remained healthy at `2/2`
- no auth-service restarts occurred during the successful run window

Observed scale and pressure behavior:

- auth-service stayed at its `2`-replica floor throughout the successful run
- auth-service CPU remained well below the `70%` target during the captured watch window
- api-gateway remained at `1` replica and did not need to scale for this bounded workload

What this means:

- the earlier SwiftPay registration-path failure was materially improved by the stronger auth-service dev baseline
- the current local `k3s` runtime can now complete the bounded public send-money path successfully under the same `8`-way concurrency level that previously failed
- for the current dev objective, keeping two warm auth-service replicas plus stronger baseline requests is a justified runtime contract

Residual cautions:

- HPA and metrics-server warnings still appeared transiently during the rollout window, even though the successful drill itself completed cleanly
- unrelated readiness noise still appeared elsewhere in the namespace, including Redis and wallet-service probe warnings
- this does not yet prove broader high-concurrency stability beyond the bounded `8`-way profile

## Updated Classification

### Confirmed Slice 4 improvements

- SwiftPay HPA behavior is live-observed and no longer only Git-defined intent
- the bounded public SwiftPay registration and send-money path now succeeds cleanly at `8/8` under the hardened auth-service dev baseline
- the local runtime can absorb this bounded SwiftPay pressure profile without auth-service pod restarts or gateway registration timeouts

### Confirmed Slice 4 residual risks

- transient metrics-server and HPA signal instability still appears during some rollout windows
- Redis and other service probes still show occasional namespace-level readiness noise in the local runtime
- broader concurrency bands remain unproven

## Updated Immediate Next Steps

1. Keep the hardened auth-service dev baseline as the new SwiftPay Slice 4 contract.
2. Expand the pressure matrix gradually above the successful `8`-way profile instead of reverting to unbounded concurrency jumps.
3. Re-check transient metrics-server, Redis, and wallet-service probe instability so unrelated local-runtime noise does not get mislabeled as SwiftPay failure.
4. Continue Slice 4 on the other owned workloads using the same evidence-first drill discipline.

## Fourth SwiftPay Pressure Update

Date: `2026-06-10`

The next bounded SwiftPay Slice 4 pass raised the public-ingress pressure band from the previously successful `8`-way profile to a `12`-way profile.

Observed baseline before the run:

- timestamp: `2026-06-10T17:38:24Z`
- cluster running pods: `67`
- `swiftpay-dev` `Synced Healthy`
- Metrics API working before the burst:
  - `kubectl top` succeeded
  - SwiftPay HPAs reported real CPU and memory targets
- steady state before the burst:
  - `api-gateway` `1/1`
  - `auth-service` `2/2`
  - `transaction-service` `2/2`

Observed result from the `12`-way run:

- bounded concurrent `smoke-send-money.sh` run returned:
  - `SUCCESS_COUNT=0`
  - `FAIL_COUNT=12`
  - `FAIL_SIGNAL_COUNT=12`
- all client-visible failures occurred on:
  - `POST /api/auth/register`
- every failed run returned HTTP `500`

Observed gateway evidence:

- api-gateway logs again showed upstream registration timeout, not a new failure class:
  - `message: timeout of 10000ms exceeded`
  - `code: ECONNABORTED`
  - `status: null`
- the auth register circuit breaker crossed its open threshold during the burst

Observed scale and probe behavior:

- `auth-service-hpa` scaled from `2` to `3`
- `api-gateway-hpa` scaled from `1` to `2`
- during recovery, `auth-service` briefly degraded to:
  - `0/3` available
- two existing auth-service pods then failed liveness and were restarted
- `api-gateway` converged back to `2/2`
- `auth-service` eventually converged back to `3/3`

Observed runtime side effects:

- the node did not enter the earlier `PLEG` wedge pattern
- the broader platform remained recoverable
- `swiftpay-dev` returned to `Synced Healthy`
- during the post-burst recovery window, the Metrics API again became transiently unavailable and HPAs briefly reported `unknown`

What this means:

- the current validated SwiftPay success ceiling is still `8/8`
- the next band at `12/12` is not yet dependable
- the failure boundary remains the same one identified earlier:
  - auth-service registration path convergence under burst load
  - followed by api-gateway upstream timeout and circuit-breaker pressure
- this pass improves the classification materially:
  - the failure is not a node-level runtime wedge
  - it is a workload-level concurrency and health-tolerance problem inside the current SwiftPay `dev` contract

Prepared hardening after this pass:

- make api-gateway auth registration timeout configurable instead of hard-coded at `10000ms`
- set `AUTH_REGISTER_TIMEOUT_MS=15000` in the `dev` overlay
- increase auth-service `startupProbe`, `readinessProbe`, and `livenessProbe` tolerance in the `dev` overlay so short burst pressure does not trigger container restarts as aggressively

Current honest state after the fourth pass:

- `8/8` remains the highest live-proven clean bounded profile
- `12/12` is a confirmed failure band in the current deployed runtime
- a targeted `dev` hardening change is prepared in Git but still requires a manual image rebuild before the next rerun can be treated as live evidence

## Fifth SwiftPay Pressure Update

Date: `2026-06-13`

The next SwiftPay Slice 4 follow-up activated the previously prepared `dev` hardening and reran the same bounded `12`-way public-ingress profile.

Live hardening confirmed before the rerun:

- `swiftpay-dev` reconciled to revision `9b320c4`
- api-gateway now carries:
  - `AUTH_REGISTER_TIMEOUT_MS=15000`
- auth-service `dev` probes now use the hardened tolerance:
  - `startupProbe.failureThreshold=24`
  - `startupProbe.timeoutSeconds=5`
  - `readinessProbe.failureThreshold=12`
  - `readinessProbe.timeoutSeconds=5`
  - `livenessProbe.failureThreshold=12`
  - `livenessProbe.timeoutSeconds=5`

Observed result from the rerun:

- bounded concurrent `smoke-send-money.sh` run returned:
  - `SUCCESS_COUNT=0`
  - `FAIL_COUNT=12`
  - `FAIL_SIGNAL_COUNT=12`
- all failed runs still returned HTTP `500`
- api-gateway logs showed the same failure class as before, but now at the new timeout boundary:
  - `message: timeout of 15000ms exceeded`
  - `code: ECONNABORTED`

Observed runtime behavior:

- auth-service did not collapse into the earlier `0/3` availability pattern from the June 10 run
- auth-service remained at its warm `2`-replica baseline during this rerun
- pod restarts did not recur during the burst window
- `swiftpay-dev` stayed recoverable and returned cleanly to `Synced Healthy`

What this means:

- widening the gateway register timeout from `10s` to `15s` and softening auth-service probe tolerance improved recovery behavior
- those changes did not move the user-visible `12`-way success ceiling
- the current failure boundary is still the auth registration path under bounded burst pressure

## Sixth SwiftPay Pressure Update

Date: `2026-06-13`

Because the fifth pass still failed cleanly at `12/12`, the next manifest-only hardening kept `auth-service` warm at `3` replicas in the `dev` contract and reran the same `12`-way burst.

Live hardening confirmed before the rerun:

- `swiftpay-dev` reconciled to revision `c1f1ccf`
- `auth-service-hpa` now uses:
  - `minReplicas=3`
  - `maxReplicas=3`
- auth-service steady state before the burst:
  - `3/3` ready

Observed result from the rerun:

- bounded concurrent `smoke-send-money.sh` run returned:
  - `SUCCESS_COUNT=2`
  - `FAIL_COUNT=10`
  - `FAIL_SIGNAL_COUNT=10`
- the gateway still returned HTTP `500` for the failed requests
- api-gateway logs still showed:
  - `message: timeout of 15000ms exceeded`
  - `code: ECONNABORTED`

Observed runtime behavior:

- auth-service held `3/3` throughout the burst instead of dropping below full availability
- auth-service did not restart during the run
- the namespace recovered cleanly and remained:
  - `swiftpay-dev` `Synced Healthy`
- metrics-server and HPA telemetry were again transiently unstable during the same window, but the workload itself remained stable enough to complete the drill

What this means:

- keeping three warm auth-service replicas materially improved the `12`-way outcome from `0/12` to `2/12`
- the ceiling still has not moved enough to call `12/12` a validated success profile
- the current honest SwiftPay classification is now:
  - clean success ceiling: `8/8`
  - partial improvement at `12/12`, but still failure
  - failure boundary still centered on auth registration latency through the gateway under burst pressure

## Seventh SwiftPay Pressure Update

Date: `2026-06-13`

The next Slice 4 step isolated the auth registration path directly so the team could stop guessing whether the remaining `12/12` failure band belonged to api-gateway behavior or auth-service behavior.

### 1. The first direct helper-pod test path was invalid

An initial synthetic benchmark used a temporary helper pod in `swiftpay-dev`.

That path did not produce valid auth-service evidence.

Observed behavior:

- the helper pod could not resolve cluster DNS
- direct TCP connection attempts to:
  - `auth-service`
  - `auth-service.swiftpay-dev.svc.cluster.local`
  - `10.43.125.57:3004`
  all failed from that helper pod

This was not an auth-service defect.

It was expected network segmentation.

Live network policy confirmed that backend ingress currently allows auth-service traffic from:

- `api-gateway`
- observability scrapers

It does not allow arbitrary helper pods.

That means the helper-pod path cannot be used as a valid service-isolation benchmark without explicitly widening the policy, which would distort the real runtime contract.

### 2. The valid direct benchmark had to run from inside api-gateway

To match the production-like SwiftPay service path, the direct auth benchmark was rerun from inside a live `api-gateway` pod against:

- `http://auth-service:3004/auth/register`

Two important observations came out of that isolation test:

- the first attempt used the wrong payload shape and returned fast validation failures:
  - auth-service expects `name`
  - the invalid probe used `firstName` and `lastName`
  - those requests returned HTTP `400` quickly and do not represent the performance boundary
- the corrected direct benchmark used the real auth-service payload contract and was launched at `12`-way concurrency from `api-gateway`

### 3. Direct auth-service registration can succeed, but still starves pod health under burst load

Once the corrected direct benchmark was in flight, the live runtime showed:

- direct auth-service `POST /auth/register` calls returned `201` from multiple auth-service pods
- the path therefore does work without the public ingress hop
- however, at least one auth-service pod then stopped answering `/health` quickly enough for:
  - kubelet readiness probes
  - kubelet liveness probes
  - blackbox probe traffic
  - api-gateway health polling

Observed runtime consequences:

- `auth-service-686d498c4d-9ckpm` entered prolonged health-check timeouts
- that pod dropped to `0/1 Ready`
- kubelet eventually issued:
  - `Container auth-service failed liveness probe, will be restarted`
- the pod restarted once
- the auth-service set then recovered back to:
  - `3/3 Ready`
- `swiftpay-dev` recovered back to:
  - `Synced Healthy`

### 4. What this isolation step proves

This is the strongest SwiftPay Slice 4 classification so far.

It proves that the remaining `12/12` failure band is not just a gateway timeout artifact.

The direct caller path from `api-gateway` into `auth-service` can itself push auth-service into a state where:

- registration requests partially succeed
- health checks starve
- at least one pod loses readiness
- liveness eventually forces a restart

Current honest classification:

- the public `500` responses seen at `12/12` are still surfaced by api-gateway
- but the underlying bottleneck is now confirmed to include auth-service internal saturation or event-loop starvation under burst registration load
- the remaining SwiftPay Slice 4 problem is therefore inside the auth registration runtime path itself, not only in gateway timeout tuning

### 5. What this means for the next hardening step

The next useful SwiftPay work is no longer another blind timeout increase.

The platform now needs auth-service-specific runtime diagnostics and hardening, most likely around:

- bcrypt cost and event-loop pressure during burst registration
- database connection-pool pressure during concurrent user creation
- registration-path timing instrumentation inside auth-service
- safer health-check isolation so `/health` does not starve behind burst registration work

Current honest state after the seventh pass:

- clean proven SwiftPay success ceiling remains `8/8`
- `12/12` is still an invalid success band
- the failure is now evidence-backed as an auth-service-internal runtime saturation problem, not merely a gateway-facing symptom

## FoodPulse Lifecycle Update

The next Slice 4 pass targeted `FoodPulse` lifecycle resilience rather than HPA behavior.

Why this workload was chosen:

- the `dev` runtime does not expose live HPA behavior for FoodPulse
- the more relevant runtime-pressure signal is whether the preserved stop/start path converges cleanly under GitOps
- earlier operator experience had already shown resume-path fragility around Redis and lifecycle sequencing

### 1. The original preserved stop path was not GitOps-safe

Observed behavior from the initial `./scripts/k8s-stop.sh --wait` drill:

- the script scaled API, UI, and Redis down and hibernated the CNPG cluster
- ArgoCD automated sync remained enabled on:
  - `internal-developer-platform-dev-root`
  - `foodpulse-dev`
- the controller immediately started reconciling workloads back toward desired state during the stop window
- the namespace entered a noisy partial state instead of a clean preserved stop

This is an operational design defect, not just a drill inconvenience.

It means the original lifecycle helper allowed an operator to trigger reconciliation conflict during a legitimate preserved-stop workflow.

### 2. FoodPulse lifecycle controls were hardened to suspend and resume GitOps intentionally

The operator path in `FoodPulse` was updated so lifecycle controls now support GitOps-aware execution directly:

- `./scripts/k8s-stop.sh --wait --suspend-gitops`
- `./scripts/k8s-start.sh --resume-gitops`

What changed:

- `k8s-stop.sh` now fails fast if ArgoCD automation is still enabled and `--suspend-gitops` is not supplied
- `k8s-stop.sh --suspend-gitops` removes automated sync from both:
  - `internal-developer-platform-dev-root`
  - `foodpulse-dev`
- `k8s-start.sh --resume-gitops` restores automated sync for both applications after workload recovery

### 3. The full GitOps-safe FoodPulse lifecycle round-trip was verified live

Validated stop sequence:

- `foodpulse-dev` moved to `OutOfSync` and then `Suspended`
- workload pods terminated cleanly instead of being recreated by ArgoCD
- CNPG hibernation condition completed successfully
- the namespace drained to only the completed backup job

Validated resume sequence:

- CNPG rehydration succeeded
- Redis StatefulSet converged
- API and UI deployments rolled out successfully
- ArgoCD automation was re-enabled by the script
- final live state returned to:
  - `foodpulse-dev` `Synced Healthy`
  - `internal-developer-platform-dev-root` `Synced Healthy`

What this means:

- FoodPulse now has a verified GitOps-safe preserved stop/start path
- the remaining lifecycle complexity is explicit and operator-controlled rather than hidden behind reconciliation conflict
- for Slice 4, this converts FoodPulse from a fragile lifecycle drill into a repeatable one

### 4. Residual local-runtime cautions remain

- FoodPulse API and UI still showed intermittent readiness and liveness turbulence during some lifecycle transitions
- Redis resume remains one of the slower convergence points in the local single-node runtime
- these are now runtime characteristics to monitor, not workflow-design defects
