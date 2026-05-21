# Internal Developer Platform Roadmap

## Mission

Build a serious multi-app platform engineering lab where different application styles can be run, observed, compared, operated, and improved from one shared control plane.

This workspace already gives us a powerful mix:

- `Obervability-Stack`: control plane candidate
- `SwiftPay`: flagship microservices app
- `OpenSIS`: legacy monolith with serious platform wrapper
- `FoodPulse`: HA and failover lab
- `MemFlip`: lightweight demo app

The roadmap below turns that collection into one coherent product.

## Product Vision

The end state is a local-first platform operations lab with:

1. one canonical workspace runbook
2. one shared observability/control plane
3. one repeatable app onboarding model
4. one consistent startup and health verification workflow
5. app-specific insights for different architecture styles
6. enough polish that the workspace can be demonstrated as a portfolio project, teaching asset, and operator playground

## Guiding Principles

### 1. Platform First

We are not building five disconnected demos.
We are building one platform that happens to manage five workloads.

### 2. Realistic Over Perfect

We should improve real operational flows before chasing visual polish.

Examples:

- app discovery
- startup reliability
- health verification
- logs and metrics access
- alert interpretation
- incident workflows

### 3. Use The Right Workload For The Right Story

- `SwiftPay` shows microservices and business metrics
- `OpenSIS` shows legacy app platforming
- `FoodPulse` shows resilience and failover
- `MemFlip` shows onboarding simplicity

### 4. Document As We Go

Every meaningful step should land in:

- `JOURNEY-RUNBOOK.md`
- this roadmap
- repo-specific docs when needed

## Roadmap Overview

The work is divided into seven phases.

1. Foundation and governance
2. Workspace normalization
3. Control plane hardening
4. App integration and onboarding
5. Operator workflows and incident drills
6. UX and demo polish
7. Production-style maturity and portfolio packaging

## Phase Status Tracker

| Phase | Status | Notes |
|---|---|---|
| 1. Foundation and governance | Complete | Monorepo, root runbook, and root roadmap are in place |
| 2. Workspace normalization | Complete | Workspace hygiene checkpoint is in place and the remaining risks are no longer primarily normalization risks |
| 3. Control plane hardening | Complete | Static-plus-live audit paths now exist for SwiftPay, MemFlip, OpenSIS, and FoodPulse |
| 4. App integration and onboarding | Complete | Onboarding flows, app-specific audits, and dashboard operator guides now exist across the managed workloads |
| 5. Operator workflows and incident drills | Complete | Standard health workflow, incident matrix, app runbooks, incident drill catalog, and five executed drills are now in place |
| 6. UX and demo polish | Complete | Control-plane story, demo center, comparison view, app handoff pages, and live demo validation now meet the Phase 6 standard |
| 7. Production-style maturity and portfolio packaging | In progress | Phase 7 is now in late-stage hardening: the owned k3s workload set, control plane, Vault-first secrets, public ingress, and runtime baseline are live; remaining work is closeout, GitOps activation, and production-control tightening |

## Current Focus

We are currently in **Phase 7: production-style maturity and portfolio packaging**.

Phase 6 is complete. Phase 7 is no longer just planning and early slicing. The current state is:

- `MemFlip`, `SwiftPay`, `FoodPulse`, and `OpenSIS` are live on the owned `k3s` path
- `Obervability-Stack` is live on the owned `k3s` path
- Vault is the active secret source of truth for the owned overlays
- public ingress is live through Cloudflare Tunnel
- the local runtime contract is now Kubernetes-first and sized accordingly

The remaining Phase 7 focus is:

- formal roadmap and closeout reconciliation
- production-control tightening after GitOps activation and validation
- production-control tightening where the repo still carries placeholder or lab-safe posture

Execution checklist:

- use [PHASE7-REMAINING-WORK-CHECKLIST.md](/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/PHASE7-REMAINING-WORK-CHECKLIST.md) as the concrete closeout plan for the remaining Phase 7 work
- use [GITOPS-ACTIVATION.md](/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/GITOPS-ACTIVATION.md) as the repeatable ArgoCD activation and retry procedure
- use [PRODUCTION-CONTROL-TIGHTENING-REVIEW.md](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/PRODUCTION-CONTROL-TIGHTENING-REVIEW.md) as the current production-control audit baseline

Phase 6 completed intent was:

- turn the integrated workspace into a teachable, portfolio-grade control plane
- make the platform story visible before a presenter drills into individual apps
- give every managed workload a consistent operator handoff page
- remove stale branding and UX residue that caused verbal explanation overhead
- prove the demo path with live browser checks and live operator audits instead of trusting static screenshots

## Current Definition Of Done

Phase 7 will be considered successful when:

- the project has a credible production narrative beyond local Docker Compose
- architecture, screenshots, and diagrams make the platform understandable without a live walkthrough
- packaging materials show why this workspace is a serious platform engineering portfolio piece
- the owned Kubernetes workload set is complete across frontend/backend, microservices, resilience, and the legacy monolith path
- the observability stack is live on the owned `k3s` path and has explicit `dev` and `prod` contracts
- Vault, Traefik, and public ingress are real platform components rather than documentation-only direction
- the roadmap and closeout docs reflect the actual implemented platform state

GitOps note:

- ArgoCD is already the declared GitOps standard and the repo already contains the owned ArgoCD application structure
- the first live activation attempt on `2026-05-07` was rolled back after node-runtime instability prevented a trustworthy controller bring-up
- GitOps activation and validation were completed on `2026-05-20` and `2026-05-21`
- ArgoCD is now the default reconciler for the owned `dev` paths
- Phase 7 does not need to wait for perfect GitOps promotion before the implementation story is credible
- however, Phase 7 is not fully closed until we decide whether GitOps activation lands as the final Phase 7 slice or the opening Phase 8 execution slice

Phase 6 completed when:

- the control-plane UI clearly tells the platform story
- each app has a polished demo path and operator handoff path
- app and platform metrics have a documented standard with central scrape coverage for exposed metric endpoints
- the dashboard language is beginner-friendly without hiding real operational detail
- stale UI duplicates and visual inconsistencies are removed
- the project can be demoed end-to-end without needing verbal patch notes

Previous Phase 5 completion criteria:

- the standard health workflow is documented and runnable
- common incident shapes have a documented first-response path
- app-specific operator runbooks exist for each managed workload
- drills and live audits are connected into one coherent operator story
- selected drills have been executed, recovered, and recorded

---

## Phase 1: Foundation And Governance

### Goal

Create the project spine so every future change has a place to live and a clear decision model.

### Deliverables

- root monorepo established
- root runbook established
- root roadmap established
- common naming model for repos and environments
- decision log for major architecture choices

### Success Criteria

- every future task maps to a roadmap phase
- every meaningful issue gets logged in the runbook
- no ambiguity about the workspace hub repo

### Current Status

Complete.

Already done:

- root monorepo initialization
- GitHub remote setup
- nested `.git` removal
- journey runbook creation
- root workspace architecture summary
- initial workspace setup matrix

### Remaining Work

- define naming conventions for apps, networks, environments, and dashboards

Roadmap note:

- the remaining naming cleanup can continue as part of later phases without blocking Phase 1 completion

---

## Phase 2: Workspace Normalization

### Goal

Reduce repo drift, remove noise, and make the workspace predictable enough to automate.

### Why This Matters

Right now the repos are strong individually, but they are not yet normalized as one platform.
That will hurt us when we start automating startup, health checks, and onboarding.

### Workstreams

#### 2.1 Repo Hygiene

- remove obvious junk and accidental files
- identify generated output that should not be source-controlled going forward
- add or improve missing root docs in repos that need them

Examples:

- `MemFlip/~/.cloudflared/config.yml`
- `FoodPulse` missing top-level `README`
- unclear scratch/history files like `FoodPulse/command.sh`

#### 2.2 Standardize Local Expectations

- identify required environment files across repos
- create safe `.env.example` files where missing
- document required ports, networks, and startup assumptions

#### 2.3 Standardize Network Integration

- ensure each runtime app joins `observability-net`
- ensure stable aliases exist for every monitored app
- verify alias names match `Obervability-Stack`

### Deliverables

- workspace hygiene checklist
- repo-by-repo setup contract
- normalized app alias table

### Success Criteria

- every app has a documented startup contract
- every app has a documented observability alias
- no hidden surprise files are required to run the system

### Current Status

Complete.

Already done:

- root workspace architecture summary added
- repo setup matrix added
- `FoodPulse/README.md` added
- `FoodPulse/.env.example` added
- `OpenSIS/.env.example` added
- accidental `MemFlip/~/.cloudflared/config.yml` removed
- `FoodPulse/command.sh` converted into a safe historical-notes wrapper
- `FoodPulse/scripts/pg-failover-drill.sh` repaired
- `Obervability-Stack/docs/README.md` reconciled with current primary ports
- Kubernetes-minded normalization guidance added to root workspace docs

Still to do before moving on:

- use a workspace hygiene checkpoint to separate true blockers from non-blocking historical residue
- carry minor repo-specific documentation cleanup opportunistically instead of holding the roadmap open for perfection
- transition into Phase 3 once the control-plane work clearly outweighs remaining normalization work

---

## Phase 3: Control Plane Hardening

### Goal

Turn `Obervability-Stack` from a promising prototype into a reliable workspace control plane.

### Why This Matters

This repo is already the obvious hub, but it still has doc drift and some prototype-grade internals.
If the hub is shaky, every downstream integration feels shaky.

### Workstreams

#### 3.1 Documentation Reconciliation

- fix stale port references
- align setup docs with actual compose behavior
- document the monitored-app model clearly

#### 3.2 Authentication And Access Model

- decide whether to keep demo auth temporarily or harden it now
- separate demo mode from platform mode
- document operator access paths

#### 3.3 App Inventory Model

- validate monitored apps against the actual workspace
- ensure every configured app has:
  - clear metadata
  - valid health target
  - valid log query
  - valid runbook reference

#### 3.4 Control Plane Reliability

- verify compose startup order
- verify health endpoints
- verify Prometheus target consistency
- verify UI API routes against actual app state

### Deliverables

- hardened `Obervability-Stack`
- accurate app catalog
- updated control plane docs

### Success Criteria

- control plane can boot reliably
- app inventory is trustworthy
- operator docs match reality

### Current Status

Complete.

Delivered:

- monitored app inventory reconciled against the normalized workspace
- control-plane auth model shifted from demo-only posture toward explicit database mode with controlled demo fallback
- control-plane smoke checks now verify runtime health and API surfaces
- local UI auth runtime now supports both demo login and database-backed login
- monitored app inventory now has a runnable validation path
- SwiftPay, MemFlip, OpenSIS, and FoodPulse each now have dedicated static and live audit paths
- Apple Silicon-safe OpenSIS startup guidance now exists through the documented `--build-local` path
- FoodPulse now has a workspace-safe startup contract with normalized ports, safer container names, and corrected lab defaults

Exit condition achieved:

- Phase 2 reduced enough repo drift that control-plane work no longer had to compensate for basic workspace inconsistency
- the next major bottleneck is richer app onboarding rather than control-plane trust

---

## Phase 4: App Integration And Onboarding

### Goal

Make app onboarding repeatable, visible, and useful across all supported workloads.

### Why This Matters

This is where the project becomes a platform instead of a pile of repos.

### Workstreams

#### 4.1 SwiftPay Integration

This is the flagship integration.

Focus:

- validate all `SwiftPay` service metrics
- validate business metrics in the control plane
- expose clear microservice health and money-flow views
- confirm logs and alerts map cleanly to service boundaries

#### 4.2 OpenSIS Integration

This is the legacy-platform integration.

Focus:

- validate UI probe visibility
- add platform-level runbooks for Vault, DB, and app reachability
- ensure observability tells the difference between edge issues, app issues, and DB issues

#### 4.3 FoodPulse Integration

This is the resilience-lab integration.

Focus:

- surface Redis failover health
- surface Postgres failover health
- expose HAProxy status meaningfully
- connect drill scripts to platform runbooks

#### 4.4 MemFlip Integration

This is the lightweight onboarding integration.

Focus:

- keep the app simple
- make it the easiest example of how an app joins the platform
- use it as the reference onboarding target

#### 4.5 App Onboarding Template

Extract a reusable pattern:

- metadata shape
- compose network requirements
- health endpoint requirements
- metrics/log expectations
- runbook checklist

### Deliverables

- all apps visible in the control plane
- one onboarding template for future repos
- one operator-facing app matrix

### Success Criteria

- each app has a credible platform story
- adding a sixth app would feel structured, not improvised

### Current Status

Complete.

Latest progress:

- static-plus-live audits now exist across all managed workloads
- the control-plane side has enough trust to shift into operator-facing onboarding artifacts
- the reusable onboarding template and operator app matrix are now part of the Phase 4 deliverable set
- the dashboard now includes a SwiftPay operator guide so the flagship microservices app has response guidance alongside its money-flow signals
- the dashboard now includes an OpenSIS-specific operator guide so the control plane explains first-response actions, not just health state
- the dashboard now includes a FoodPulse failover guide so the resilience lab is represented as an operator workflow, not just a health probe
- the dashboard now includes a MemFlip onboarding guide so the simplest browser-first workload is fully represented as a reusable platform pattern

Phase 4 closeout note:

- the next bottleneck is now workflow polish and incident handling rather than basic integration trust

---

## Phase 5: Operator Workflows And Incident Drills

### Goal

Make the workspace teach operations, not just deployment.

### Why This Matters

A serious platform project should demonstrate not only how to run systems, but how to diagnose and recover them.

### Workstreams

#### 5.1 Standard Health Workflow

Define the canonical operator questions:

1. Is the app reachable?
2. Is the app healthy?
3. Are dependencies healthy?
4. Are metrics arriving?
5. Are logs arriving?
6. Are alerts firing correctly?

#### 5.2 Incident Runbooks

Build runbooks for:

- app unreachable
- probe failing but app healthy
- metrics scrape down
- logs missing
- DB auth mismatch
- queue backlog
- circuit breaker open
- failover drift

#### 5.3 Drill Automation

Use real scripts where available:

- `FoodPulse/scripts/redis-failover-drill.sh`
- `FoodPulse/scripts/pg-failover-drill.sh`
- `OpenSIS` smoke and backup helpers
- `SwiftPay` smoke scripts

#### 5.4 Verification Dashboarding

Create a quick “operator first” view in the control plane:

- app state
- dependency state
- drill state
- open incidents
- recent failures

### Deliverables

- incident matrix
- operator runbooks
- incident drill catalog
- verification dashboard

### Success Criteria

- we can intentionally break parts of the workspace and recover them using documented procedures

### Current Status

In progress.

Latest progress:

- `./scripts/devops-monitor.sh operator` now provides a runnable operator-first entrypoint
- the standard health workflow is documented
- the first incident matrix is documented
- all four managed workloads now have platform-facing operator runbooks
- the first incident drill catalog is documented
- five real drills executed and recorded: MemFlip backend down, SwiftPay transaction worker down, OpenSIS Vault unavailable, FoodPulse Redis failover, and control-plane probe drift
- Phase 5 closed after validating both workload failures and an observability-layer failure mode

---

## Phase 6: UX And Demo Polish

### Goal

Make the platform compelling to use and easy to demo.

### Why This Matters

This project should be usable as:

- a portfolio piece
- a teaching tool
- an operations lab
- a personal control plane

### Workstreams

#### 6.1 Landing Experience

- root-level “what this project is” narrative
- fast-start instructions
- system architecture summary

#### 6.2 Control Plane UX

- improve cross-app navigation
- add app comparison views
- clarify app ownership and category
- distinguish app type visually:
  - microservices
  - monolith
  - HA lab
  - demo app

#### 6.3 Demo Stories

Create demo flows:

- boot the workspace
- inspect app health
- show SwiftPay money flow
- show OpenSIS platform model
- trigger FoodPulse failover drill
- show MemFlip as easy onboarding example

### Deliverables

- polished demo script
- improved control plane UX
- clear root project story

### Success Criteria

- someone new can understand the workspace quickly
- a live walkthrough feels coherent and intentional

### Current Status

Complete.

Latest progress:

- root `README.md` added as the project front door
- `DEMO-WALKTHROUGH.md` added as the guided Phase 6 presenter script
- Phase 6 now has a clearer path from control plane to apps, drills, runbook, and Kubernetes direction
- FoodPulse now has a cleaner demo voting-board UI with colored restaurant labels and a live vote chart
- the control-plane services page now lets operators open managed apps directly from the app cards
- the services dashboard is now simplified into managed app labels, with app-specific operator pages for latency, uptime, alerts, logs, and guidance
- the services area now includes a live app comparison view that explains each workload's architecture role, operator value, Kubernetes direction, and live health state
- the control plane now includes a Demo Center that turns the Markdown walkthrough into a guided UI presenter path with live readiness, commands, talking points, and reference links
- the public landing page and control-plane chrome now use `DevOps Easy Learning` branding instead of stale prototype naming
- the Demo Center, compare view, dashboard, and per-app operator pages were verified live in the browser from the control plane
- `opensis-live`, `swiftpay-live`, `foodpulse-live`, and `memflip-live` were re-run as Phase 6 exit checks
- the SwiftPay live audit now waits for Prometheus to observe the synthetic transfer before asserting metric success, removing a timing-based demo failure

Phase 6 exit evidence:

- control-plane smoke check passed `28/28`
- `opensis-live` passed `39/39`
- `swiftpay-live` passed `44/44`
- `foodpulse-live` passed `23/23`
- `memflip-live` passed `34/34`

Phase 6 accepted because:

- the dashboard, landing page, compare view, and Demo Center now tell one coherent platform story
- every app page exposes probe latency, uptime, alerts, recent logs, and operator guidance
- platform service labels show real health and version data from the live API
- the remaining visible loading state is a normal live refresh behavior, not a verbal patch note

---

## Phase 7: Production-Style Maturity And Portfolio Packaging

### Goal

Turn the project from a cool local lab into a serious engineering narrative.

### Workstreams

#### 7.1 Architecture Narrative

- root architecture doc
- explain why these apps were chosen
- explain how the control plane abstracts different runtime styles

#### 7.2 Portfolio Packaging

- strong root README
- screenshots and diagrams
- operator journey summary
- incident and recovery examples

#### 7.3 Optional Advanced Enhancements

- workspace orchestration scripts
- app discovery automation
- central environment validator
- unified smoke-check runner
- root Makefile or task runner

#### 7.4 Kubernetes Implementation Slices

- prove the migration pattern with real `k3s` workload slices
- keep Docker Compose as the learning baseline while Kubernetes becomes the production direction
- start with simpler workloads, then move into stateful resilience, then platform migration
- treat `dev` and `prod` as first-class environments for the control-plane slice, not as an afterthought

#### 7.5 GitOps Activation

- move ArgoCD from declared standard to active reconciler for the owned Kubernetes paths
- stop relying on ad hoc `kubectl apply` as the primary day-two operating model
- define the repo-to-cluster promotion path explicitly for `dev` and `prod`
- make drift detection and desired-state ownership part of the default platform story

### Deliverables

- portfolio-ready documentation
- architecture visuals
- credible engineering story
- real local `k3s` workload slices for `MemFlip`, `SwiftPay`, and `FoodPulse`
- a live control-plane `k3s` `dev` slice plus an explicit `prod` contract
- a live owned `OpenSIS` `k3s` `dev` slice plus an explicit `prod` contract
- a clear decision on whether GitOps activation closes Phase 7 or opens Phase 8

### Success Criteria

- repo can be shown to employers, collaborators, or students without extra context
- at least one frontend/backend workload, one microservices workload, and one stateful resilience workload run credibly on the owned `k3s` path
- the shared observability platform runs credibly on the owned `k3s` path for `dev`
- the workload migration set is now complete across frontend/backend, microservices, stateful resilience, and the legacy monolith path
- GitOps is either active on the owned paths or explicitly sequenced as the first formal Phase 8 operational slice

---

## Priority Order

This is the order I recommend we actually execute in:

1. Phase 2: Workspace normalization
2. Phase 3: Control plane hardening
3. Phase 4: App integration and onboarding
4. Phase 5: Operator workflows and drills
5. Phase 6: UX and demo polish
6. Phase 7: Portfolio packaging

Reason:

- normalization reduces chaos
- control plane hardening creates stability
- app integration creates value
- drills prove credibility
- polish comes after reliability

## Near-Term Milestones

## Milestone A: Workspace Baseline

Target outcome:

- every repo has a clear setup contract
- no obvious junk or hidden dependency files
- app aliases and networks are verified

## Milestone B: Control Plane Trustworthiness

Target outcome:

- `Obervability-Stack` docs, ports, and app catalog match reality
- startup and health behavior are consistent

## Milestone C: Flagship Integration

Target outcome:

- `SwiftPay` is fully represented in the control plane with health, logs, metrics, and business signals

## Milestone D: Mixed-Architecture Platform Story

Target outcome:

- `SwiftPay`, `OpenSIS`, `FoodPulse`, and `MemFlip` all have clear, distinct platform stories

## Milestone E: Operator Credibility

Target outcome:

- drills and incident runbooks work end to end

## Major Risks

### Risk 1: Control Plane Drift

If docs and app inventory drift from reality, confidence drops quickly.

Mitigation:

- treat control plane reconciliation as an early priority

### Risk 2: Workspace Complexity

Five repos can become cognitively expensive fast.

Mitigation:

- normalize naming
- add a root architecture summary
- maintain the runbook continuously

### Risk 3: Legacy App Friction

`OpenSIS` may be harder to change safely at the application layer.

Mitigation:

- favor platform and observability improvements before invasive app changes

### Risk 4: HA Lab Ambiguity

`FoodPulse` currently mixes real implementation with notes and missing env setup.

Mitigation:

- clean and document before depending on it as a core demo path

### Risk 5: Scope Creep

There are enough ideas here to sprawl indefinitely.

Mitigation:

- execute by milestone
- prefer vertical slices that land visible value

## Decisions We Should Make Early

These are the next decisions that will shape implementation.

1. Do we want a root orchestration command for all apps?
2. Do we harden `Obervability-Stack` auth now or defer it?
3. Do we want one root README now or after milestone B?
4. Do we treat `FoodPulse` as core or optional in the first demo story?
5. Do we clean repo noise immediately or as part of each integration phase?

## Recommended Immediate Next Step

Start with **Phase 2: Workspace normalization**.

Specifically:

1. create a root architecture summary
2. create a repo setup matrix
3. verify and document all `observability-net` aliases
4. clean obvious junk and missing setup docs
5. then move directly into control plane hardening

That gives us the strongest base for every later phase.
