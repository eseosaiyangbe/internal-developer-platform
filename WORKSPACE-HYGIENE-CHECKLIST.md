# Workspace Hygiene Checklist

## Purpose

This file is the Phase 2 normalization checkpoint for the workspace.

It answers three questions:

1. what has already been normalized
2. what still exists but is non-blocking
3. what remains important before or during Phase 3

The goal is not to make every repo perfectly tidy before moving on.
The goal is to separate true platform blockers from acceptable historical residue.

## Current Assessment

Overall status: **Phase 2 is substantially complete, with a short tail of non-blocking cleanup left.**

The workspace now has:

- a root architecture model
- a repo-by-repo setup matrix
- a living journey runbook
- cross-platform workstation bootstrap scripts
- normalized local startup contracts for the main monitored apps
- verified `observability-net` alias alignment for the monitored workloads

## Repo Check

| Repo | Status | What Was Normalized | Remaining Notes | Phase 3 Blocker? |
|---|---|---|---|---|
| `Obervability-Stack` | Mostly normalized | root docs and setup ports were reconciled; role as control plane is explicit | deeper control-plane docs still need periodic drift checks | Yes, but as Phase 3 work rather than unfinished Phase 2 hygiene |
| `SwiftPay` | Strongly normalized | startup path, validation path, README, deployment guide, runbook, and system-flow docs now align around real local ports | older historical docs still contain some stale references | No |
| `OpenSIS` | Normalized enough | root `.env.example` exists, local compose path is clear, startup and health contract are documented | legacy and advanced docs are extensive, but the main entry path is coherent | No |
| `FoodPulse` | Normalized enough | root `README`, root `.env.example`, safer `command.sh`, repaired Postgres failover drill | repo remains infrastructure-heavy and drill-oriented by design | No |
| `MemFlip` | Normalized enough | root `.env.example`, browser URL and health path clarified, stray accidental folder removed | local generated frontend build output may appear on disk after builds | No |

## Generated Assets Review

### `MemFlip/frontend/dist`

Assessment:

- this directory exists as generated frontend build output
- it is already ignored by [`MemFlip/.gitignore`](https://github.com/eseosaiyangbe/MemFlip/blob/main/.gitignore)
- it is not part of the committed source of truth for the monorepo
- the runtime contract is the frontend source tree plus the Docker build in [`MemFlip/frontend/Dockerfile`](https://github.com/eseosaiyangbe/MemFlip/blob/main/frontend/Dockerfile)

Decision:

- treat `frontend/dist/` as local build residue, not as a Phase 2 blocker
- do not design future Kubernetes flows around checked-in static build output

Why this matters:

- it keeps the source-of-truth model clean
- it avoids carrying Docker-era build residue into the Kubernetes migration story

## Non-Blocking Residue

These items still exist, but they do not justify holding the roadmap in Phase 2:

- historical docs in `SwiftPay` that reference older local ports
- large legacy or tutorial-heavy documentation trees in `MemFlip`, `OpenSIS`, and `SwiftPay`
- repo-specific implementation choices that are valid today but will be revisited in Kubernetes form later

## True Remaining Risks

The biggest remaining risks are now platform risks, not hygiene risks:

- the control plane still needs hardening in `Obervability-Stack`
- the app inventory model needs verification against the real workspace state
- demo-grade auth in the control plane still needs an explicit decision
- future Kubernetes migration needs a canonical local cluster direction, even if that decision is temporarily on hold

These belong more naturally to **Phase 3** than to further repo cleanup.

## Recommendation

Use this checklist as the transition marker:

- do not chase every stale line in every deep doc tree before progressing
- treat the workspace as normalized enough for control-plane hardening
- carry minor historical cleanup opportunistically while Phase 3 work proceeds

## Practical Exit Criteria Check

| Phase 2 Exit Question | Current Answer |
|---|---|
| Does every repo have a trustworthy startup contract? | Yes, at the primary entrypoint level |
| Does every repo have a documented env contract? | Yes |
| Does every monitored workload have a verified alias and health path? | Yes, for the current control-plane inventory |
| Have obvious junk and misleading helper files been cleaned or documented? | Yes |
| Does the next highest-value work now belong to control-plane hardening? | Yes |

## What To Do Next

The next roadmap-aligned move is:

1. begin **Phase 3: Control plane hardening**
2. verify and tighten the monitored-app inventory in `Obervability-Stack`
3. reconcile any remaining control-plane doc drift
4. decide how explicitly to separate demo mode from real operator mode
