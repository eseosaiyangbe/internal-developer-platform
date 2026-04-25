# Environment Model

## Purpose

This document defines the root environment contract for DevOps Easy Learning.

The goal is to make `dev` and `prod` first-class concepts before the Kubernetes migration starts, rather than trying to retrofit environment discipline after infrastructure grows more complex.

## Environment Principles

1. `dev` and `prod` are different operational targets, not different names for the same setup.
2. Each environment must have its own secrets, databases, ingress, and retention expectations.
3. No workload should assume localhost-only behavior in application code.
4. Environment settings should be driven by configuration, not by image rebuilds or ad hoc shell edits.

## Root Environment Definitions

### `dev`

Purpose:

- local validation
- feature integration
- demo preparation
- incident drills
- migration rehearsals

Expected traits:

- easier rebuild and reset path
- development-safe credentials
- faster iteration
- acceptable lower durability where explicitly understood
- observability tuned for rapid feedback

### `prod`

Purpose:

- stable deployment target
- stronger access and secrets posture
- longer-lived state
- clearer operational ownership and auditability

Expected traits:

- stricter credential handling
- backup and restore guarantees
- tighter ingress and exposure rules
- more conservative rollout and recovery procedures
- explicit retention and storage planning

## Root Configuration Expectations

Every environment should define, at minimum:

- application base URLs
- database endpoints and credentials
- cache/message-broker endpoints and credentials
- secret-management endpoints where applicable
- observability endpoints
- authentication/session secrets
- storage and retention settings where relevant

## Shared Platform Expectations

The control plane should behave differently by environment only where operationally justified.

That means:

- app inventory shape should stay recognizable across environments
- dashboards and alerts should stay conceptually aligned
- notification routing may differ by environment
- retention and storage policy may differ by environment
- ingress hostnames and authentication policy should differ explicitly

## Workload Expectations By Environment

### `SwiftPay`

`dev`:

- sandbox payment and test-traffic assumptions
- lower-risk queues and data
- easier reset of transactions and message backlog

`prod`:

- durable transaction data
- clearer backup and audit requirements
- stronger message, API, and credential controls

### `OpenSIS`

`dev`:

- developer-safe seeded credentials and sample data
- easier Vault/bootstrap reinitialization
- safer experimentation with exporter and runtime settings

`prod`:

- stronger Vault and database access controls
- stricter data handling expectations
- formalized backup and recovery for MariaDB and secret state

### `FoodPulse`

`dev`:

- easier failover drills
- acceptable topology experimentation
- shorter retention acceptable for generated activity

`prod`:

- deliberate decision required on self-managed versus managed HA components
- stronger storage, failover, and logging guarantees

### `MemFlip`

`dev`:

- fastest resettable environment
- best candidate for iterative migration rehearsals

`prod`:

- tighter session, database, and ingress controls
- simplified operational footprint

## Configuration Shape Direction

At the root level, the workspace should converge toward:

- `.env.example` as safe contract documentation
- environment-specific values injected outside source control
- secrets stored outside committed files
- app configuration grouped by concern instead of by random historical accumulation

## Secrets Rules

Environment separation is meaningless if secrets are shared.

Strategic direction:

- Vault is the long-term secret source of truth for Kubernetes environments
- Kubernetes Secrets should hold only the delivery objects needed by workloads, not become the human-managed system of record
- Git must not store live secret values

Required rules:

- `dev` and `prod` never share the same secret values
- no committed secret-bearing env files
- no fallback to placeholder secrets in production-like contexts
- no app should require manual inline editing of committed files to switch environments

## GitOps Rules

Strategic direction:

- ArgoCD is the preferred GitOps reconciler for Kubernetes environments in this workspace
- Git stores desired state, manifest structure, and non-secret configuration references
- Git does not store secret values

Required rules:

- `dev` and `prod` should reconcile from explicit environment-aware manifest paths or overlays
- manual kubectl drift should be treated as temporary debugging, not as the normal operating model
- sync ordering for secrets-dependent workloads must be explicit where needed

## Database Rules

Required rules:

- `dev` and `prod` never share database instances
- `dev` and `prod` never share credentials
- schema migration behavior must be environment-driven and explicit
- backup expectations must be environment-specific

## Networking And Exposure Rules

### `dev`

- loopback-only publication is preferred unless remote sharing is intentional
- convenience is allowed when the risk is understood

### `prod`

- exposure must be deliberate and documented
- ingress, TLS, and authentication requirements must be explicit
- internal services should not be published just because they were reachable locally in Compose

## Observability Rules

The observability plane should preserve consistency across environments while allowing operational differences:

- health contracts should remain stable
- metrics naming should remain stable
- alert thresholds may differ only when justified by environment behavior
- notification routing and retention may differ by environment

## Deployment Implications

This environment model means:

- local Compose continues to be the proving ground for `dev`
- Kubernetes planning must assume separate `dev` and `prod` namespaces or clusters
- root docs must continue to describe environment differences as part of the platform story

## Next Environment-Model Tasks

1. create root environment variable inventories by workload
2. identify secrets that still depend on overly local assumptions
3. define control-plane `dev` and `prod` hostnames and ingress expectations
4. align migration planning with this environment model

## Success Criteria

This environment model is working when:

- root docs describe `dev` and `prod` consistently
- migration planning maps clearly to environment boundaries
- contributors can understand what changes across environments without reading each repo in full
