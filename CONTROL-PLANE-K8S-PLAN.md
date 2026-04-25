# Control Plane Kubernetes Plan

## Purpose

This document deepens the Kubernetes plan for `Obervability-Stack`.

The root migration plan explains the full workspace direction.
This document focuses specifically on the control plane because it is the dependency we will rely on to validate every later workload migration.

## Why The Control Plane Goes First

Migrating workloads before the control plane would weaken visibility during the move.

The control plane should go first because it provides:

- app probes
- metrics ingestion
- alerting
- log visibility
- operator UI context
- notification and incident flow continuity

If this layer is unstable, the rest of the migration becomes harder to observe and trust.

## Scope

The Kubernetes control-plane scope includes:

- Prometheus
- Alertmanager
- Grafana
- Loki
- blackbox exporter
- node and container observability equivalents
- the Next.js UI
- rule/config provisioning

## Recommended Namespace

```text
platform-observability
```

Reason:

- keeps platform services separate from application namespaces
- makes ownership boundaries easier to reason about
- avoids hiding platform concerns inside one workload namespace

## Resource Direction

### Prometheus

Recommended resource type:

- `StatefulSet`

Why:

- needs persistent TSDB storage
- requires stable identity and predictable storage attachment

Requires:

- PVC
- ConfigMap for scrape config and rules
- Secret for any external auth or remote-write credentials if added later
- Service for UI/API access

### Alertmanager

Recommended resource type:

- `Deployment` for single-instance lab/dev
- `StatefulSet` or HA pattern later if clustering becomes part of the platform goal

Requires:

- ConfigMap for routing config
- Secret for webhook/auth integrations if needed
- Service for internal access

### Grafana

Recommended resource type:

- `Deployment`

Requires:

- PVC if local state is preserved
- ConfigMap for provisioning and dashboards
- Secret for admin/auth settings
- Service and Ingress

Strategic note:

if Grafana metadata moves to PostgreSQL later, the deployment becomes easier to reason about across environments.

### Loki

Recommended resource type:

- `StatefulSet` if self-hosted in cluster

Requires:

- PVC
- ConfigMap for storage and retention config
- Service for ingestion and query path

Strategic note:

retention and storage cost should be environment-aware from the start.

### Blackbox Exporter

Recommended resource type:

- `Deployment`

Requires:

- ConfigMap for module definitions
- Service for Prometheus scrape access
- explicit network policy/egress review if probing external targets

### UI Control Plane

Recommended resource type:

- `Deployment`

Requires:

- ConfigMap for non-secret runtime config
- Secret for auth/session/database settings
- Service
- Ingress

Strategic note:

the UI should not assume direct localhost access to Prometheus or Loki. All backend endpoint wiring must remain environment-driven.

## Data And State Direction

### Control-Plane App Database

Recommended direction:

- PostgreSQL

Environment approach:

- `dev`: dedicated lower-risk Postgres backend
- `prod`: separate Postgres backend with stricter durability and credentials

### Prometheus Data

Recommended direction:

- persistent volume in `dev`
- more deliberate retention/storage design in `prod`

### Loki Data

Recommended direction:

- persistent volume in `dev`
- stronger retention and storage planning in `prod`

## Configuration Model

Configuration should be split cleanly:

- `ConfigMap`: rules, dashboards, non-secret runtime settings
- `Secret`: auth/session keys, database credentials, webhook tokens, API secrets

Do not combine secret and non-secret configuration into one convenience object just because local Compose env files did.

## Ingress Direction

Recommended pattern:

- one ingress for the control-plane UI
- internal Services for Prometheus, Alertmanager, Loki, and Grafana
- exposure of internal components only when operationally justified

The UI should remain the main operator entry point.

## Observability Continuity Requirements

Before calling the control-plane migration successful, all of these must still work:

- app inventory page
- managed-app detail pages
- active alerts
- resolved history / notifications
- log page
- service status / platform status surfaces
- operator scripts or equivalent validation path

## Rule And Dashboard Management Direction

Recommended approach:

- Prometheus rules stored in version-controlled files and loaded through ConfigMaps
- Grafana dashboards stored in version-controlled provisioning bundles
- app inventory and operator guidance kept as code-backed configuration, not as manual dashboard edits

This preserves reviewability and makes `dev` to `prod` promotion cleaner.

## Security Direction

The control plane becomes more sensitive in Kubernetes, not less.

Controls should include:

- namespace isolation
- least-privilege secrets access
- explicit ingress/auth policy
- no accidental public exposure of internal metrics surfaces
- reduced reliance on default credentials and placeholder secrets

## Migration Sequence

### Step 1

Freeze control-plane config sources:

- Prometheus config
- alert rules
- recording rules
- Loki config
- Grafana provisioning
- UI runtime env contract

### Step 2

Define `dev` control-plane resource manifests:

- namespace
- ConfigMaps
- Secrets
- Deployments/StatefulSets
- Services
- PVCs
- Ingress

### Step 3

Deploy the `dev` control plane and validate:

- UI loads
- Prometheus scrapes
- alerts evaluate
- notifications flow
- logs query successfully

### Step 4

Reconnect one migrated workload and validate observability continuity.

### Step 5

Define the stronger `prod` variant:

- ingress/auth tightening
- storage and retention
- database durability
- backup and restore

## Risks

### 1. Stateful Service Complexity

Prometheus and Loki are not stateless web apps.

Mitigation:

- treat storage and retention as first-class design choices

### 2. Config Drift Between UI And Telemetry Backends

If the UI points at the wrong endpoints or mismatched app inventory, the platform story breaks.

Mitigation:

- keep control-plane config source-of-truth explicit and versioned

### 3. Premature Exposure

Publishing every internal service externally because it was reachable in local Compose is not production-minded.

Mitigation:

- keep the UI as the main public entry point
- restrict direct backend exposure unless justified

## Success Criteria

This plan is successful when:

- the control plane can move to Kubernetes without losing operator continuity
- configuration, secrets, storage, and ingress are modeled explicitly
- the control plane remains the trusted validation layer for later workload migrations
