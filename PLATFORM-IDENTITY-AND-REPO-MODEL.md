# Internal Developer Platform Identity And Repository Model

## Purpose

This document defines the professional platform identity for the current workspace
and the target repository model for the future split out of the current monorepo.

It exists to correct two structural problems:

- the project name `DevOps Easy Learning` no longer reflects the quality or scope
  of what the workspace has become
- the current Git root groups the control plane and all managed workloads into one
  repository, which is useful for early integration but is not the cleanest
  long-term operating model

## Canonical Platform Name

Use this as the primary platform identity:

`Internal Developer Platform`

Use this as the short form after the first mention:

`the platform`

Use this for the current control-plane role:

`platform control plane`

## What This Platform Is

In DevOps and platform-engineering terms, this project is an:

`Internal Developer Platform`

because it already provides:

- workload onboarding
- shared observability
- shared operator workflows
- secrets management direction
- Kubernetes-first runtime patterns
- incident response guidance
- environment separation
- platform-level operational ownership across multiple applications

## Current Repository Reality

Today the workspace is still one Git repository rooted at:

`/Users/raymond/Documents/DevOps-Easy-Learning`

That root currently contains:

- `Obervability-Stack`
- `MemFlip`
- `SwiftPay`
- `FoodPulse`
- `OpenSIS`
- root scripts and platform docs
- root Kubernetes platform assets

This is functionally a monorepo, even though the workloads are logically separate
systems.

## Current Transition State

As of `2026-05-05`, the stale child repositories were refreshed from the current
platform workspace using history-preserving subtree extraction.

That means:

- the GitHub child repositories now reflect the current authoritative workload
  state
- the current platform workspace still contains local copies of most workloads
- the workspace is therefore in a transition period where repository boundaries
  are logically split, but the central workspace still carries the physical
  directories

Until the local directories are removed or detached from the central workspace,
we should treat this as a controlled transitional state, not the final operating
model.

## Target Repository Model

Recommended target model:

- one central platform repo
- one repo per managed workload

### Recommended central repo name

`internal-developer-platform`

### Recommended child repo names

- `observability-stack`
- `memflip`
- `swiftpay`
- `foodpulse`
- `opensis`

## Central Platform Repo Ownership

The central platform repo should own:

- root roadmap
- journey runbook
- workstation bootstrap
- shared platform scripts
- shared local runtime policy
- shared platform `k8s/` assets
- Cloudflare and access policy guidance
- GitOps root orchestration
- ArgoCD app-of-apps or environment composition
- portfolio documentation and evidence pack

## Child Repo Ownership

Each application repo should own:

- application source code
- application-local Docker and Compose files
- application-local Kubernetes manifests and overlays
- application-local scripts
- application-local docs
- application-local ArgoCD application manifests if we keep workload ownership at
  the app boundary

## Current Child Repository Index

The current child repositories are:

- `memflip`
  - `https://github.com/eseosaiyangbe/MemFlip`
- `swiftpay`
  - `https://github.com/eseosaiyangbe/SwiftPay`
- `foodpulse`
  - `https://github.com/eseosaiyangbe/FoodPulse`
- `opensis`
  - `https://github.com/eseosaiyangbe/OpenSIS`
- `observability-stack`
  - `https://github.com/eseosaiyangbe/Obervability-Stack`

## GitOps Ownership Direction

Recommended GitOps ownership split:

- central platform repo:
  - environment composition
  - shared platform services
  - root ArgoCD applications
  - repo-to-cluster promotion model
- child repos:
  - workload manifests
  - overlays
  - app-local desired state

This keeps platform composition centralized without forcing all workload-specific
deployment logic into one repository forever.

## Naming Rules For Documentation

Use these terms consistently:

- whole project:
  - `Internal Developer Platform`
- platform short form:
  - `the platform`
- `Obervability-Stack` role:
  - `platform control plane`
- workload set:
  - `managed workloads`
- current root repository during transition:
  - `current platform workspace`

Avoid these terms in future top-level documentation:

- `DevOps Easy Learning`
- `learning platform`
- `easy learning`
- `playground`
- `demo repo`

## What Should Not Be Renamed Blindly

Several identifiers currently include `devops-easy-learning`, but they are not
just documentation strings. They are live integration contracts.

Do not mass-rename these without a migration plan:

- Vault KV paths
- Kubernetes labels such as `app.kubernetes.io/part-of`
- GitHub repository URLs
- Cloudflare or public integration references
- ArgoCD `repoURL` targets
- local state directories such as `~/.config/devops-easy-learning`

These need a deliberate migration sequence, not a global search-and-replace.

## Recommended Migration Sequence

### Phase 1: Identity Alignment

- rename the highest-signal root documentation to `Internal Developer Platform`
- preserve runtime identifiers and Git URLs temporarily
- document the target repository model explicitly

### Phase 2: Repository Boundary Design

- define exact repo ownership boundaries
- define what stays central versus what moves into child repos
- define GitOps ownership before extraction

### Phase 3: Pilot Extraction

Use `MemFlip` as the first extraction candidate because it is the lowest-risk
workload from a repository-ownership perspective.

Pilot goals:

- preserve history
- update scripts and documentation cleanly
- prove control-plane references still work
- prove GitOps path assumptions remain coherent

### Phase 4: Full Workload Extraction

Recommended order:

1. `memflip`
2. `swiftpay`
3. `foodpulse`
4. `opensis`
5. `observability-stack`

`Obervability-Stack` should move late because it is the control-plane hub and
the most cross-linked workload in the current workspace.

### Phase 5: Platform Repo Finalization

- convert the current monorepo into the central platform repo
- update Git remotes and documentation
- update ArgoCD and GitOps references
- decide whether runtime identifiers should also be migrated from
  `devops-easy-learning` to `internal-developer-platform`

## Current Recommendation

Do not delete workload directories from the current platform workspace yet.

The correct next step is:

- formalize the central repository operating model
- define how the platform repo references the child repos
- decide whether the final local topology should use:
  - sibling checkouts
  - Git submodules
  - or a lightweight workspace bootstrap that clones each child repo beside the
    platform repo

The child repositories are now refreshed and usable. The remaining work is to
move from duplicated local directories to a cleaner central orchestration model
without breaking the platform while it is still undergoing late Phase 7 and
GitOps work.
