# Kubernetes Migration Plan

## Purpose

This document turns the workspace’s Kubernetes direction into a phased implementation plan.

It is not a promise that everything moves at once.
It is a disciplined path from the current local Compose proving ground to a more production-style `dev` and `prod` model.

## Migration Goal

Move the platform from local Docker Compose orchestration to a Kubernetes-based operating model without losing:

- workload-specific observability
- operator clarity
- runbook integrity
- incident drill value
- environment separation

## Current Starting Point

Today the workspace already has several useful preconditions:

- a shared control plane
- stable runtime aliases and health targets
- app-specific runbooks
- real alerting
- documented incident response
- stronger environment discipline than a typical local-only demo stack

This means the migration should not start from manifests.
It should start from the operating contracts we have already validated.

It also means the repo already has a natural strategic direction:

- `OpenSIS` proves Vault is already operationally meaningful in this workspace
- `OpenSIS` also proves ArgoCD and GitOps are already part of the Kubernetes story
- Phase 7 should now elevate those patterns into root platform standards

## Target End State

The intended Kubernetes end state is:

- separate `dev` and `prod` environments
- a shared observability platform with clear ownership boundaries
- workload deployments expressed through Kubernetes-native resources
- database, secrets, probes, and ingress modeled explicitly
- ArgoCD managing desired-state reconciliation
- Traefik handling the standard in-cluster ingress layer
- Vault managing secret truth and runtime delivery
- migration decisions driven by operational truth, not by YAML volume

## Environment Model

### Development

Purpose:

- integration testing
- demo preparation
- incident drills
- fast iteration

Expected characteristics:

- lower blast radius
- easier reset/rebuild path
- development-safe credentials and seed data
- tighter feedback loops for alert and probe validation

### Production

Purpose:

- stable deployment target
- stronger security and secret controls
- backup and restore guarantees
- clearer operational ownership

Expected characteristics:

- stricter secret handling
- explicit retention and backup policies
- tighter ingress and access controls
- more deliberate rollout and recovery procedures

## Namespace And Ownership Direction

Recommended namespace shape:

- `platform-observability`
- `swiftpay-dev`
- `swiftpay-prod`
- `opensis-dev`
- `opensis-prod`
- `foodpulse-dev`
- `foodpulse-prod`
- `memflip-dev`
- `memflip-prod`

This keeps platform services separate from application namespaces and makes the `dev`/`prod` split explicit from the beginning.

## Platform Control Decisions

Two platform decisions should now be treated as root direction, not as optional side paths.

### ArgoCD For GitOps

ArgoCD should be the preferred Kubernetes reconciler for:

- platform manifests
- environment overlays
- workload promotion paths

Why:

- it matches the strongest GitOps posture already present in the workspace
- it keeps desired state reviewable and versioned
- it fits the future `dev` and `prod` environment split cleanly

### Vault For Secret Management

Vault should be the preferred secret source of truth for Kubernetes environments.

Why:

- OpenSIS already proves Vault is operationally meaningful in this workspace
- it avoids treating Git or manually curated Kubernetes Secrets as the human secret store
- it strengthens the production story for secret rotation, secret scoping, and runtime delivery

### Traefik For Ingress

Traefik should be the preferred ingress controller direction for this workspace.

Why:

- it already aligns with the strongest explicit ingress direction in the repo
- it fits well behind Cloudflare Tunnel and other edge layers
- it keeps the platform story cleaner than maintaining mixed ingress-controller guidance across workloads

## Workload Mapping

### `Obervability-Stack`

Likely resource model:

- `Deployment`: UI, Grafana, Alertmanager, exporters where appropriate
- `StatefulSet`: Prometheus, Loki if self-hosted in cluster
- `ConfigMap`: Prometheus rules, datasource config, dashboards, app catalog config where applicable
- `Secret`: auth secrets, database credentials, API keys
- `Ingress`: control-plane entry point
- `PersistentVolumeClaim`: Prometheus, Loki, Grafana state where self-hosted

### `SwiftPay`

Likely resource model:

- `Deployment`: frontend, API gateway, auth, wallet, transaction, notification services
- `StatefulSet` or managed service: PostgreSQL and Redis depending on hosting decision
- `Deployment` or operator-managed: RabbitMQ depending on complexity tolerance
- `ConfigMap`: service configuration
- `Secret`: database, JWT, messaging, and API credentials
- `Ingress`: frontend and API edge access
- `HorizontalPodAutoscaler`: best candidate in the workspace for autoscaling discussion

### `OpenSIS`

Likely resource model:

- `Deployment`: PHP/Apache app, exporters
- `StatefulSet` or managed service: MariaDB
- `StatefulSet` or external managed solution: Vault depending on platform scope
- `Job` / init flow: bootstrap and seeding tasks
- `Secret`: app credentials and rendered secret material
- `ConfigMap`: Apache/PHP config and exporter config
- `Ingress`: app edge

### `FoodPulse`

Likely resource model:

- `Deployment`: UI, API, HAProxy
- `StatefulSet`: Redis and Postgres only if the repo remains self-contained in cluster
- `ConfigMap`: HAProxy config and API settings
- `Secret`: database and Redis credentials
- `Ingress`: UI/API routing

Important note:

FoodPulse is a resilience lab. In Kubernetes, we should decide deliberately whether to keep self-managed failover components for teaching value or replace some of them with managed-service assumptions for production realism.

### `MemFlip`

Likely resource model:

- `Deployment`: frontend and backend
- `StatefulSet` or managed service: Postgres and Redis
- `ConfigMap`: app config
- `Secret`: database and session credentials
- `Ingress`: frontend/API entry

## Migration Phases

### Phase A: Freeze The Contracts

Before more Kubernetes work, confirm the source-of-truth contracts:

- startup paths
- health endpoints
- metrics endpoints
- required env vars
- data dependencies
- persistent state boundaries

Why this phase matters:

bad migrations usually start by translating Compose files too literally instead of preserving the real operational contract.

### Phase B: Separate Platform And Application Concerns

Clarify what belongs to the shared platform versus what belongs to each app:

- observability ownership
- database ownership
- ingress ownership
- secret ownership
- backup ownership

Why this phase matters:

if ownership is fuzzy, Kubernetes manifests only make the ambiguity harder to debug.

### Phase C: Establish Environment Templates

Create environment-specific templates for `dev` and `prod`:

- config shape
- secret shape
- database connection model
- ingress hostnames
- storage assumptions
- retention assumptions

Why this phase matters:

the move to Kubernetes should preserve the environment split instead of retrofitting it later.

### Phase D: Prove The First Workload Migration Pattern

Recommended first Kubernetes implementation slice:

- move `MemFlip` into a `dev` cluster namespace first
- preserve browser access, backend health, metrics, and stateful dependency clarity
- preserve a clean path back into the shared control plane narrative

Why this phase matters:

the first migration should reduce ambiguity, not compound it. `MemFlip` is the cleanest low-risk proof that the workspace can move beyond Compose without losing operator clarity.

Current implementation path:

- [MEMFLIP-K8S-CANDIDATE.md](MEMFLIP-K8S-CANDIDATE.md)
- [MemFlip/docs/local/12-phase7-k8s-dev.md](MemFlip/docs/local/12-phase7-k8s-dev.md)

### Phase E: Migrate The Control Plane And Remaining Workloads Deliberately

Recommended order:

1. `MemFlip`
2. `FoodPulse`
3. `SwiftPay`
4. `Obervability-Stack`
5. `OpenSIS`

Reasoning:

- `MemFlip` is the cleanest low-risk onboarding candidate
- `FoodPulse` is a good mid-complexity resilience test
- `SwiftPay` is the flagship microservices story and deserves deliberate treatment
- `Obervability-Stack` should move only after the first workload pattern is proven, because it is the shared platform the rest of the system depends on
- `OpenSIS` has the most platform complexity because of Vault and legacy/runtime wrapping

### Phase F: Add Production Controls

Before calling the platform production-style, add:

- backup and restore procedures
- retention policies
- storage sizing assumptions
- rollout strategy
- incident escalation paths
- secret rotation expectations

## Recommended Database Direction

For the control plane, PostgreSQL is the right strategic choice going forward.

That means:

- local Compose can keep using containerized Postgres for development
- Kubernetes should use environment-specific Postgres backends
- `dev` and `prod` should never share the same database or credentials

For app databases, the decision should be workload-specific:

- keep self-managed databases only when they materially support the teaching goal
- otherwise prefer simpler and safer production assumptions

## Secrets Strategy

Current direction:

- environment-driven configuration
- Vault already matters in `OpenSIS`

Target Kubernetes direction:

- Vault as the secret source of truth
- Kubernetes Secrets only as delivery artifacts where required by the runtime path
- workloads authenticating to Vault through Kubernetes-native auth patterns where applicable
- no secret material in images, committed env files, or ad hoc bootstrap notes

Important separation:

- Git stores desired state
- ArgoCD reconciles desired state
- Vault stores secret truth
- the cluster delivers secrets to workloads through approved runtime mechanisms

Do not blur those responsibilities.

## Observability Strategy In Kubernetes

The observability model should remain recognizable after migration:

- Prometheus continues scraping platform and app targets
- Blackbox probing remains first-class for user-facing availability
- Loki remains the central log path unless an external service replaces it
- Alertmanager continues routing into the control-plane notification flow
- per-app operator pages should still reflect probes, metrics, logs, and runbooks

If the observability story changes too much during migration, the platform loses continuity.

## Major Risks

### 1. Translating Compose Too Literally

Risk:

- brittle manifests
- poor ownership boundaries
- hidden runtime assumptions

Mitigation:

- migrate contracts first, manifests second

### 2. Mixing `dev` And `prod` Logic

Risk:

- weak security posture
- accidental environment drift
- poor reproducibility

Mitigation:

- separate env templates, secrets, storage, and ingress decisions early

### 3. Losing The Operator Story

Risk:

- Kubernetes exists, but the repo becomes harder to understand and operate

Mitigation:

- keep docs, dashboards, runbooks, and incident paths aligned to the new platform model

## Recommended Next Steps

The clean next implementation order is:

1. tighten the root architecture and portfolio docs
2. formalize `dev` and `prod` config expectations at the root level
3. formalize ArgoCD and Vault as root platform standards
4. define the control-plane Kubernetes resource plan
5. migrate `MemFlip` as the first low-risk app
6. validate observability continuity before moving to the next workload

Supporting planning documents:

- [ENVIRONMENT-MODEL.md](ENVIRONMENT-MODEL.md)
- [CONTROL-PLANE-K8S-PLAN.md](CONTROL-PLANE-K8S-PLAN.md)
- [MEMFLIP-K8S-CANDIDATE.md](MEMFLIP-K8S-CANDIDATE.md)

## Success Criteria

This migration plan is successful when:

- the repo explains the move from Compose to Kubernetes clearly
- `dev` and `prod` are treated as first-class environments
- each workload has a reasoned migration path instead of generic YAML aspirations
- the platform story stays coherent before, during, and after the migration
