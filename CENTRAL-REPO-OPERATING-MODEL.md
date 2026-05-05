# Central Repo Operating Model

## Purpose

This document defines how the central `Internal Developer Platform` repository
should behave now that the workload child repositories have been refreshed and
are no longer stale.

It answers one key question:

How do we manage the platform centrally without continuing to treat one Git root
as the permanent home of every workload?

## Current State

Today the current platform workspace still contains local workload directories:

- `Obervability-Stack`

`MemFlip`, `SwiftPay`, `FoodPulse`, and `OpenSIS` are now cut over to the sibling-checkout
model, so they should no longer be treated as permanent embedded workloads in
the central repo.

At the same time, each workload now also has a refreshed authoritative child
repository on GitHub.

That means the central workspace is still physically monorepo-shaped, but the
source-of-truth model is shifting toward:

- one central platform repo
- one authoritative repo per workload

## Source Of Truth Rules

From this point forward, use these rules:

### Central platform repo owns

- roadmap and phase tracking
- journey runbook
- workstation bootstrap
- shared platform scripts
- shared platform `k8s/` services
- Cloudflare and access guidance
- future GitOps root orchestration
- evidence pack and portfolio documentation

### Child repos own

- application source code
- workload-local Kubernetes manifests and overlays
- workload-local scripts
- workload-local docs
- workload-local ArgoCD application manifests

## What The Central Repo Must Not Become Again

Do not keep using the central repo as the long-term day-to-day code-edit source
for every workload while also claiming the child repos are authoritative.

That creates drift immediately.

If we continue editing workload code only inside the central repo, the child
repos will become stale again.

## Recommended Final Local Topology

The cleanest final local topology is:

1. one central platform checkout
2. workload repositories checked out beside it as sibling repos

Recommended shape:

```text
<workspace-root>/
  internal-developer-platform/
  observability-stack/
  memflip/
  swiftpay/
  foodpulse/
  opensis/
```

Why this is preferred:

- clean Git boundaries
- no submodule friction
- easier app-local branch and release handling
- clearer GitOps repo ownership
- simpler onboarding for engineers who already understand normal multi-repo
  workflows

## Alternatives

### Option 1: sibling checkouts

Recommended default.

Pros:

- simplest mental model
- clean repo isolation
- no submodule UX problems

Cons:

- central scripts must locate sibling repos intentionally

Current status:

- this support is now implemented in:
  - `./scripts/bootstrap-sibling-repos.sh`
  - `./scripts/workspace-start.sh`
  - `./scripts/workspace-stop.sh`
  - `./scripts/workspace-layout.sh`

### Option 2: Git submodules

Not recommended as the first choice.

Pros:

- central repo can pin exact child revisions

Cons:

- higher operator friction
- easier to misuse
- weaker day-to-day developer ergonomics

### Option 3: keep duplicated local directories inside the central repo

Not recommended beyond the transition window.

Pros:

- no immediate local path breakage

Cons:

- guaranteed drift
- unclear ownership
- weak enterprise repository boundaries

## Recommended Next Transition

The next clean transition is:

1. keep the current platform workspace temporarily
2. keep resolving workloads through the sibling-checkout contract first
3. remove the remaining embedded workload directories deliberately
4. validate the operator flows after each cut

## GitOps Implication

This repo split supports a cleaner GitOps model:

- child repos provide workload desired state
- the central repo provides environment composition and root orchestration

That is the enterprise pattern we should aim for.
