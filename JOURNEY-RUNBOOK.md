# DevOps Easy Learning Journey Runbook

## Purpose

This file is the living runbook for this workspace.

It exists to capture:

- every command we ran
- what we were trying to learn or validate
- what we found
- what broke or looked wrong
- how we fixed it, or how we plan to fix it
- why each step mattered

This is not just a changelog.
It is the operator notebook for the project journey.

## Working Agreement

From this point forward, this file should be updated as we work.

Each meaningful phase should record:

1. goal
2. commands used
3. observations
4. problems encountered
5. fixes applied
6. why the step mattered
7. follow-up work

## Workspace Inventory

Current workspace root:

```bash
/Users/raymond/Documents/DevOps-Easy-Learning
```

Current repositories discovered:

- `Obervability-Stack`
- `SwiftPay`
- `MemFlip`
- `FoodPulse`
- `OpenSIS`

## High-Level Strategy So Far

We intentionally started with discovery, not implementation.

Why:

- we needed to understand which repo is the platform hub
- we needed to know which apps are strong enough to become showcase workloads
- we needed to identify duplication, drift, and integration points before making changes
- we needed to verify whether the observability repo already knew about the app repos

Initial conclusion:

- `Obervability-Stack` is the natural control plane
- `SwiftPay` is the strongest flagship application
- `OpenSIS` is the strongest legacy-platform case
- `FoodPulse` is a HA/failover lab around Yelb
- `MemFlip` is the lightest demo app, plus course/book packaging

## Command Log

The sections below record the exact commands used during repo discovery.

---

## Phase 1: Initial Workspace Discovery

### Goal

Identify what repositories exist in the workspace and what kinds of projects they are.

### Commands

```bash
pwd
ls -la
rg --files -g 'README*' -g 'package.json' -g 'pyproject.toml' -g 'Cargo.toml' -g 'go.mod' -g 'requirements*.txt' -g 'Dockerfile*' -g 'compose*.yml' -g '.gitignore' | head -n 40
```

### What We Learned


- The workspace root is `/Users/raymond/Documents/DevOps-Easy-Learning`.
- The initial repos present were:
  - `MemFlip`
  - `Obervability-Stack`
  - `SwiftPay`
- All three looked like real code repos, not placeholders.

### Why This Step Mattered

This gave us the first map of the workspace and let us decide which repo to inspect first.

---

## Phase 2: Observability-Stack Discovery

### Goal

Understand whether `Obervability-Stack` is just a Prometheus/Grafana bundle or a real multi-app control plane.

### Commands

```bash
pwd
ls -la
rg --files | sed -n '1,220p'
sed -n '1,240p' README.md
sed -n '1,220p' docs/README.md
sed -n '1,240p' docs/PROJECT_STRUCTURE.md
sed -n '1,240p' ui-next/package.json
sed -n '1,220p' docker-compose.yml
sed -n '200,420p' docker-compose.yml
sed -n '1,220p' ui-next/app/page.tsx
sed -n '1,240p' ui-next/app/dashboard/page.tsx
sed -n '1,240p' ui-next/lib/monitored-apps.ts
sed -n '240,520p' ui-next/lib/monitored-apps.ts
sed -n '1,240p' ui-next/lib/app-observability.ts
sed -n '1,240p' ui-next/lib/auth-simple.ts
sed -n '1,240p' ui-next/prisma/schema.prisma
sed -n '1,240p' ui-next/app/api/apps/route.ts
sed -n '1,260p' ui-next/app/api/apps/[appId]/overview/route.ts
sed -n '1,240p' ui-next/app/api/apps/health/route.ts
sed -n '1,240p' ui-next/lib/prometheus-api.ts
sed -n '1,240p' 'ui-next/app/api/apps/[appId]/overview/route.ts'
sed -n '1,220p' scripts/README.md
sed -n '1,240p' ui-next/lib/config.ts
sed -n '1,220p' config.json
sed -n '1,240p' ui-next/app/services/page.tsx
sed -n '1,240p' ui-next/lib/service-config.ts
sed -n '1,220p' ui-next/lib/loki-api.ts
sed -n '1,220p' prometheus/prometheus.yml
```

### Problems Encountered

#### 1. Zsh glob expansion broke one file read

Command:

```bash
sed -n '1,260p' ui-next/app/api/apps/[appId]/overview/route.ts
```

Problem:

- `zsh` treated `[appId]` as a glob pattern
- the command failed with:

```text
zsh:1: no matches found: ui-next/app/api/apps/[appId]/overview/route.ts
```

Fix:

- quoted the path:

```bash
sed -n '1,240p' 'ui-next/app/api/apps/[appId]/overview/route.ts'
```

Why it mattered:

- this confirmed we need to quote bracketed Next.js route paths in future shell reads

### What We Learned

- This repo is not just monitoring infra; it is a product-style control plane.
- It includes:
  - Prometheus
  - Grafana
  - Loki
  - Alertmanager
  - blackbox-exporter
  - a Next.js UI under `ui-next/`
- The UI already models managed apps in `ui-next/lib/monitored-apps.ts`.
- It already knows about:
  - `SwiftPay`
  - `MemFlip`
  - `FoodPulse`
  - `OpenSIS`
- The app API surface already exposes app inventory and app-health endpoints.
- The repo expects a shared external Docker network called `observability-net`.

### Problems Identified In The Repo

#### 1. Repo folder name contains a typo

- Folder is named `Obervability-Stack`, not `Observability-Stack`.

Why it matters:

- any automation, docs, or scripts should use the real folder name exactly

#### 2. Documentation drift

- Some docs still described old port mappings
- Example: docs referenced the UI and Grafana on ports that no longer matched the current compose setup

Why it matters:

- stale docs create bad operator assumptions during startup and troubleshooting

#### 3. Auth path is still partly demo-grade

- Prisma schema exists
- active auth path still uses demo users in `ui-next/lib/auth-simple.ts`

Why it matters:

- the repo is strong as a control plane, but auth maturity is below the surrounding product polish

---

## Phase 2: SwiftPay Startup Contract Normalization

### Goal

Bring `SwiftPay`'s local startup story back into alignment so the Docker Compose browser URL, API health URL, and validation helper all describe the same operator path.

### Commands

```bash
sed -n '1,260p' WORKSPACE-SETUP-MATRIX.md
sed -n '1,260p' SwiftPay/docs/SERVICES.md
rg -n "3000|8081|health|validate\\.sh|api-gateway|frontend" SwiftPay/README.md SwiftPay/docs SwiftPay/docker-compose.yml -g '!**/node_modules/**' | sed -n '1,260p'
sed -n '1,260p' OpenSIS/docs/02-local-compose-guide.md
rg -n "\\.env.example|compose-start|8088|health|precheck|curl" OpenSIS/README.md OpenSIS/docs OpenSIS/docker-compose.yaml -g '!**/node_modules/**' | sed -n '1,260p'
sed -n '1,220p' OpenSIS/scripts/precheck.sh
sed -n '1,220p' SwiftPay/scripts/validate.sh
sed -n '1,220p' SwiftPay/README.md
sed -n '1,260p' SwiftPay/docker-compose.yml
rg -n "validate\\.sh|localhost:3000|http://localhost|3007|8081|localhost:8081" SwiftPay/docs SwiftPay/README.md SwiftPay/scripts -g '!**/node_modules/**'
bash -n SwiftPay/scripts/validate.sh
git diff -- SwiftPay/scripts/validate.sh SwiftPay/README.md JOURNEY-RUNBOOK.md
git status --short
git add SwiftPay/scripts/validate.sh SwiftPay/README.md JOURNEY-RUNBOOK.md
git commit -m "Normalize SwiftPay local validation contract"
git push origin main
```

### What We Learned

- `SwiftPay/docker-compose.yml` already exposes the real local contract:
  - frontend at `http://localhost:8081`
  - API gateway at `http://localhost:3007`
- `WORKSPACE-SETUP-MATRIX.md` had already been normalized to that contract.
- `SwiftPay/README.md` still described the old Compose path as `http://localhost` with API health on `http://localhost:3000/health`.
- `SwiftPay/scripts/validate.sh` still defaulted to `http://localhost:3000`, which meant the documented smoke test was pointed at the wrong host port for Docker Compose.
- `OpenSIS` looked comparatively clean, so `SwiftPay` was the right place to spend this normalization slice.

### Problems Encountered

#### 1. The validation helper's default could never reflect the real Compose gateway port

Problem:

- `BASE_URL` was initialized to `http://localhost:3000`
- the environment case block then used `${BASE_URL:-...}`, so the Docker default could never switch to `3007`

Why it mattered:

- this made the "golden path" smoke test disagree with the actual published API gateway port
- that kind of drift is exactly the sort of friction we want to remove before the Kubernetes migration

#### 2. Parallel Git push raced ahead of the new commit

Problem:

- the first push attempt was kicked off in parallel with `git commit`
- the push completed before the new commit existed locally, so it reported `Everything up-to-date`

Why it mattered:

- the local repo had the right fix, but the remote checkpoint did not yet contain it
- the runbook should record the real Git sequence, not the idealized one

### Fixes Applied

#### 1. Repointed Docker Compose validation to the actual gateway port

- changed `SwiftPay/scripts/validate.sh` to treat Docker Compose as `http://localhost:3007`
- changed the script to initialize `BASE_URL` as empty so environment-specific defaults work correctly

#### 2. Rewrote the main README Docker Compose path around the actual operator entrypoints

- clarified that Compose users open the app at `http://localhost:8081`
- clarified that gateway health is `http://localhost:3007/health`
- added a note that `./scripts/validate.sh` validates the API gateway and core backend flows, not the frontend itself

### Verification

```bash
bash -n SwiftPay/scripts/validate.sh
```

Result:

- shell syntax check passed
- a follow-up serial `git push origin main` successfully published commit `3aa210d`

### Why This Step Mattered

- it tightened the local contract for the flagship workload before we start harder platform work
- it reduces confusion between user-facing URLs and service-facing URLs
- it makes the Compose path feel more like a Kubernetes-style split between ingress/browser entry and service health entry

### Follow-Up Work

- `SwiftPay` still has deeper documentation drift in older operational docs that reference `localhost:3000` or `http://localhost`
- those should be cleaned in a later documentation sweep, but the primary startup contract is now normalized

---

## Phase 2: SwiftPay Operator Doc Reconciliation

### Goal

Clean the next layer of `SwiftPay` documentation drift so the operator-facing docs match the normalized Docker Compose contract and stop mixing host ports with container ports.

### Commands

```bash
sed -n '1,260p' PROJECT-ROADMAP.md
sed -n '1,260p' WORKSPACE-ARCHITECTURE.md
sed -n '1,260p' WORKSPACE-SETUP-MATRIX.md
sed -n '1,240p' FoodPulse/README.md
sed -n '1,240p' OpenSIS/README.md
rg -n "localhost|health|compose up|cluster-status|precheck|\\.env.example|8088|15672|3000|http://localhost" FoodPulse OpenSIS -g '!**/node_modules/**' -g '!**/vendor/**' | sed -n '1,260p'
sed -n '1,260p' SwiftPay/docs/DEPLOYMENT.md
sed -n '1,260p' SwiftPay/docs/RUNBOOK.md
sed -n '1,240p' SwiftPay/docs/how-to-debug-this-system.md
sed -n '1,220p' SwiftPay/docs/system-flow.md
rg -n "proxy_pass|API_GATEWAY_URL|3000|api-gateway" SwiftPay/services/frontend SwiftPay/services/api-gateway -g '!**/node_modules/**' | sed -n '1,260p'
sed -n '1,220p' SwiftPay/services/frontend/nginx.conf.template
sed -n '1,240p' SwiftPay/services/frontend/Dockerfile
rg -n "docker-compose|http://localhost|3000/health|3002/health|api-gateway:80|proxy_pass|port-forward|open http://localhost|metrics" SwiftPay/docs/DEPLOYMENT.md SwiftPay/docs/RUNBOOK.md SwiftPay/docs/how-to-debug-this-system.md SwiftPay/docs/system-flow.md
git diff -- SwiftPay/docs/DEPLOYMENT.md SwiftPay/docs/RUNBOOK.md SwiftPay/docs/system-flow.md
rg -n "docker-compose|http://localhost(?!:8081|:3007|:3008|:3004|:3003|:3001|:15672|:3000|:9090|:9093)|3002/health|3002/metrics|api-gateway:80" SwiftPay/docs/DEPLOYMENT.md SwiftPay/docs/RUNBOOK.md SwiftPay/docs/system-flow.md -P
git status --short
git add SwiftPay/docs/DEPLOYMENT.md SwiftPay/docs/RUNBOOK.md SwiftPay/docs/system-flow.md JOURNEY-RUNBOOK.md
git commit -m "Reconcile SwiftPay operator docs"
git push origin main
```

### What We Learned

- `FoodPulse` and `OpenSIS` were not the next Phase 2 bottleneck; their top-level local contracts are reasonably aligned.
- The remaining high-friction drift was concentrated in `SwiftPay`'s secondary operator docs.
- Several `SwiftPay` docs were still mixing:
  - Compose browser URL vs gateway host port
  - host ports vs internal service ports
  - `docker-compose` vs `docker compose`
- `SwiftPay/services/frontend/nginx.conf.template` confirmed the real Compose-side upstream is `http://api-gateway:3000`, not `http://api-gateway:80`.

### Problems Encountered

#### 1. Operator docs were teaching the wrong mental model for local networking

Problem:

- `docs/RUNBOOK.md` still sent operators to `localhost:3000` for gateway health and `localhost:3002` for transaction health
- the same doc implied nginx should proxy to `api-gateway:80`, which is not how the Compose frontend is configured
- `docs/system-flow.md` still advertised Docker Compose at `http://localhost`

Why it mattered:

- these are the docs people reach for during failure investigation
- if the runbook itself teaches the wrong ports, debugging becomes slower and more confusing than it should be

#### 2. The no-match validation uses exit code `1` when it succeeds

Problem:

- the final `rg` validation command returned exit code `1`
- in this case that meant it found no remaining forbidden patterns in the targeted docs

Why it mattered:

- it was important to recognize that as a successful cleanup signal, not as a command failure

#### 3. Git briefly reported an `index.lock` conflict during commit

Problem:

- the first commit attempt failed with `Unable to create .git/index.lock`
- a follow-up check showed no lock file was actually present anymore

Why it mattered:

- this was another sign that parallel Git operations can create confusing transient states in this repo workflow
- the safe response was to verify the lock state first, then retry the commit serially

### Fixes Applied

#### 1. Normalized the core Compose-facing operator docs

- updated `SwiftPay/docs/DEPLOYMENT.md` to use `docker compose` consistently in the local section
- updated Compose port-forward examples to use `localhost:8081` for the frontend and `localhost:3007` for gateway access
- updated `SwiftPay/docs/RUNBOOK.md` to use the real host ports:
  - gateway `3007`
  - transaction service `3008`
  - wallet `3001`
  - auth `3004`
  - notification `3003`
- corrected the frontend proxy verification example to use `api-gateway:3000`
- updated `SwiftPay/docs/system-flow.md` so the Docker Compose browser URL is `http://localhost:8081`

### Verification

```bash
rg -n "docker-compose|http://localhost(?!:8081|:3007|:3008|:3004|:3003|:3001|:15672|:3000|:9090|:9093)|3002/health|3002/metrics|api-gateway:80" \
  SwiftPay/docs/DEPLOYMENT.md SwiftPay/docs/RUNBOOK.md SwiftPay/docs/system-flow.md -P
```

Result:

- ripgrep returned no matches
- exit code `1` was expected for that "clean" result

### Why This Step Mattered

- it tightened the docs operators will actually use during break/fix work
- it reinforced the Kubernetes-ready habit of separating browser entrypoints from service health endpoints
- it reduced the amount of Docker-only confusion we would otherwise carry into Phase 3

### Follow-Up Work

- `SwiftPay` still has more historical docs that reference older host-port assumptions
- those are now lower-risk because the main entry docs, deployment guide, runbook, and system-flow guide are aligned

---

## Phase 2: Workspace Hygiene Checkpoint

### Goal

Decide whether Phase 2 still has real blockers left, or whether the remaining work has shifted naturally into control-plane hardening.

### Commands

```bash
rg -n "frontend/dist|generated|build output|Phase 2|Still to do before moving on|Known Gaps|remaining" PROJECT-ROADMAP.md WORKSPACE-SETUP-MATRIX.md WORKSPACE-ARCHITECTURE.md JOURNEY-RUNBOOK.md MemFlip/README.md MemFlip/docs -g '!**/node_modules/**'
find MemFlip/frontend/dist -maxdepth 2 -type f | sed -n '1,80p'
git ls-files MemFlip/frontend/dist MemFlip/~ FoodPulse/command.sh FoodPulse/scripts/pg-failover-drill.sh | sed -n '1,120p'
rg -n "dist|build|nginx|COPY|frontend/dist|npm run build|config.js" MemFlip/frontend MemFlip/docker-compose.yml MemFlip/nginx MemFlip/README.md MemFlip/docs -g '!**/node_modules/**' | sed -n '1,260p'
find MemFlip/frontend -maxdepth 2 \\( -name 'Dockerfile*' -o -name 'package.json' -o -name '.gitignore' -o -name 'README*' \\) | sort | sed -n '1,120p'
sed -n '1,220p' MemFlip/docker-compose.yml
sed -n '1,220p' MemFlip/frontend/Dockerfile
sed -n '1,220p' MemFlip/frontend/package.json
find MemFlip/frontend/src -maxdepth 2 -type f | sort | sed -n '1,80p'
find MemFlip -maxdepth 2 -name '.gitignore' -o -name '.dockerignore' | sort | sed -n '1,120p'
git check-ignore -v MemFlip/frontend/dist MemFlip/frontend/dist/index.html || true
git status --short --untracked-files=all MemFlip/frontend | sed -n '1,120p'
rg --files -g 'WORKSPACE-HYGIENE-CHECKLIST.md' -g 'PHASE-2*' -g '*CHECKLIST*'
sed -n '1,120p' MemFlip/.gitignore
sed -n '200,260p' PROJECT-ROADMAP.md
git add WORKSPACE-HYGIENE-CHECKLIST.md PROJECT-ROADMAP.md WORKSPACE-SETUP-MATRIX.md JOURNEY-RUNBOOK.md
git commit -m "Add workspace hygiene checkpoint"
git push origin main
```

### What We Learned

- `MemFlip/frontend/dist` exists on disk but is already ignored by `MemFlip/.gitignore`.
- It is not a tracked artifact problem in the monorepo.
- The actual source-of-truth path for MemFlip frontend runtime remains:
  - frontend source in `frontend/src`
  - frontend image build in `frontend/Dockerfile`
- The remaining rough edges across the workspace are now mostly historical or deep-doc residue, not startup-contract blockers.

### Problems Encountered

#### 1. A likely blocker turned out to be a documented non-issue

Problem:

- `MemFlip/frontend/dist` looked like the strongest remaining candidate for a Phase 2 cleanup decision
- once inspected closely, it was already ignored and therefore not a tracked monorepo hygiene problem

Why it mattered:

- this changed the decision from "keep cleaning repos" to "capture the checkpoint and move toward Phase 3"

### Fixes Applied

#### 1. Added an explicit workspace hygiene checkpoint

- created `WORKSPACE-HYGIENE-CHECKLIST.md`
- documented which repos are normalized enough
- separated non-blocking residue from real blockers
- clarified that the next meaningful risks are control-plane risks

#### 2. Updated root workspace docs to reflect the new checkpoint

- updated `PROJECT-ROADMAP.md` so the remaining Phase 2 items focus on transition rather than perfection
- updated `WORKSPACE-SETUP-MATRIX.md` so the MemFlip generated-output note reflects the real ignored-state behavior

### Why This Step Mattered

- it gives the roadmap a clean handoff point instead of letting normalization drag on indefinitely
- it makes Phase 2 completion a judgment call based on platform risk, not on infinite doc polishing
- it protects the future Kubernetes migration from inheriting the wrong source-of-truth assumptions

### Follow-Up Work

- begin Phase 3 by hardening `Obervability-Stack`
- validate the monitored-app inventory against the actual workspace state
- decide whether the control-plane auth path stays demo-grade temporarily or gets hardened now

---

## Phase 3: Control Plane Inventory Reconciliation

### Goal

Start Phase 3 by making sure the control plane’s monitored app inventory matches the normalized workspace contracts instead of stale pre-normalization assumptions.

### Commands

```bash
sed -n '1,260p' Obervability-Stack/ui-next/lib/monitored-apps.ts
sed -n '260,520p' Obervability-Stack/ui-next/lib/monitored-apps.ts
sed -n '1,260p' Obervability-Stack/docs/README.md
sed -n '1,260p' Obervability-Stack/README.md
rg -n "browserUrl|primaryHealthEndpointId|runbooks|healthCheck|localStart|getMonitoredApp|monitoredApps" Obervability-Stack/ui-next -g '!**/node_modules/**' | sed -n '1,260p'
sed -n '1,260p' Obervability-Stack/ui-next/lib/app-observability.ts
sed -n '1,260p' 'Obervability-Stack/ui-next/app/api/apps/[appId]/overview/route.ts'
sed -n '1,260p' Obervability-Stack/ui-next/app/services/page.tsx
rg -n "memflip|foodpulse|opensis|swiftpay" Obervability-Stack/prometheus/prometheus.yml Obervability-Stack/ui-next/lib/monitored-apps.ts -g '!**/node_modules/**'
sed -n '1,260p' Obervability-Stack/prometheus/prometheus.yml
sed -n '1,220p' Obervability-Stack/ui-next/app/dashboard/page.tsx
git add Obervability-Stack/docs/WORKSPACE_APP_INVENTORY_AUDIT.md Obervability-Stack/docs/README.md Obervability-Stack/ui-next/lib/monitored-apps.ts Obervability-Stack/prometheus/prometheus.yml PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md
git commit -m "Reconcile control plane app inventory"
git push origin main
```

### Problems Encountered

#### 1. Bracketed Next.js route paths need shell quoting

Problem:

- trying to read `ui-next/app/api/apps/[appId]/overview/route.ts` without quotes caused `zsh` glob expansion to fail again

Why it mattered:

- this is the same class of shell issue we hit earlier in the journey
- it confirmed the inventory audit commands must keep quoting bracketed route paths

### What We Learned

- the control-plane inventory was broadly correct, but some metadata lagged behind Phase 2 normalization
- `MemFlip` was the biggest mismatch:
  - it had no browser URL in inventory
  - its frontend probe still targeted `/` instead of the normalized proxied health path
  - its primary endpoint was still backend-first
- `FoodPulse` and `OpenSIS` mainly needed metadata polish rather than architectural changes

### Fixes Applied

#### 1. Reconciled monitored app metadata with workspace reality

- `OpenSIS` now points operators to `./scripts/compose-start.sh`
- `MemFlip` now exposes `http://localhost:8080` as its browser URL
- `MemFlip` now treats the frontend proxied health path as the primary control-plane endpoint
- `FoodPulse` now exposes `http://localhost` as its browser URL
- `FoodPulse` now has a simple health-check runbook command

#### 2. Reconciled Prometheus probing with the normalized MemFlip contract

- blackbox probing for `MemFlip` frontend now hits `http://memflip-frontend/api/health`

#### 3. Added an explicit inventory audit document

- created `Obervability-Stack/docs/WORKSPACE_APP_INVENTORY_AUDIT.md`
- linked it from the control-plane docs index

### Why This Step Mattered

- it makes the control plane a more trustworthy source of operator truth
- it aligns dashboard links, probe targets, and runbook text with the actual workspace contracts
- it turns the start of Phase 3 into concrete hardening work rather than just a status change

### Follow-Up Work

- continue Phase 3 with deeper control-plane doc reconciliation
- validate whether app inventory metadata should remain hardcoded or move toward a more declarative config model
- decide how to handle demo auth in the control plane

## Transition to App Discovery

The observability discovery phase established that the control plane should be the workspace hub, which is why the next discovery step moved into `SwiftPay` as the flagship workload candidate.

---

## Phase 3: SwiftPay Discovery

### Goal

Understand whether `SwiftPay` is a real application candidate for the flagship monitored workload.

### Commands

```bash
pwd
ls -la
rg --files | sed -n '1,260p'
sed -n '1,260p' README.md
sed -n '1,260p' docs/README.md
sed -n '1,280p' docker-compose.yml
sed -n '1,220p' services/package.json
sed -n '1,220p' package.json
sed -n '280,520p' docker-compose.yml
sed -n '1,260p' docs/SERVICES.md
sed -n '1,240p' services/api-gateway/server.js
sed -n '1,260p' services/auth-service/server.js
sed -n '1,280p' services/wallet-service/server.js
sed -n '1,320p' services/transaction-service/server.js
sed -n '1,280p' services/notification-service/server.js
sed -n '1,260p' services/frontend/README.md
sed -n '1,260p' docs/observability-runbook.md
sed -n '1,260p' services/frontend/package.json
sed -n '1,260p' services/api-gateway/package.json
rg -n "app.get\\('/metrics'|/health|prom-client|shared/metrics|observability-net" services monitoring k8s docs | sed -n '1,220p'
sed -n '1,280p' services/shared/metrics.js
sed -n '1,220p' services/transaction-service/transaction-guard.js
sed -n '1,220p' services/transaction-service/transaction-finalizer.js
```

### What We Learned

- `SwiftPay` is the strongest application repo in the workspace.
- It is a Node/Express microservices system with:
  - API Gateway
  - Auth Service
  - Wallet Service
  - Transaction Service
  - Notification Service
  - React frontend served through nginx
  - PostgreSQL
  - Redis
  - RabbitMQ
- It already exposes `/health` and `/metrics` endpoints across services.
- It already attaches to `observability-net` in Docker Compose.
- It already has shared Prometheus metrics via `services/shared/metrics.js`.
- It already has a workspace-specific observability runbook.

### Problems Identified In The Repo

#### 1. Large service entrypoints

- several service `server.js` files are large and contain mixed responsibilities

Why it matters:

- refactoring cost will be higher when we start making deeper app changes

#### 2. Shared database weakens service isolation

- service boundaries are logical and operationally useful
- but multiple services still share the same database

Why it matters:

- the architecture is good enough for learning and demos
- but the services are not fully isolated in the strictest platform sense

#### 3. Frontend stack mismatch with observability UI

- `SwiftPay` frontend is older CRA-style React
- `Obervability-Stack` UI is modern Next.js

Why it matters:

- if we build cross-repo UX or visual integration, frontend age mismatch may show up quickly

### Why This Step Mattered

This phase confirmed that `SwiftPay` should be the flagship app in the workspace.

---

## Phase 4: MemFlip Discovery

### Goal

Understand whether `MemFlip` is a real app repo or mostly course/tutorial material, and check for duplication/noise.

### Commands

```bash
pwd
ls -la
find . -maxdepth 2 -type d | sort | sed -n '1,220p'
sed -n '1,260p' README.md
sed -n '1,220p' FILE-STRUCTURE.md
sed -n '1,260p' docker-compose.yml
sed -n '1,240p' backend/package.json
sed -n '1,240p' frontend/package.json
du -sh backend frontend docs book ebook gitops-safe k8s '~' 2>/dev/null
find '~' -maxdepth 3 -type f | sed -n '1,120p'
sed -n '1,260p' backend/server.js
find frontend/src -maxdepth 2 -type f | sort | sed -n '1,200p'
sed -n '1,240p' docs/README.md
sed -n '1,220p' docs/local/README.md
sed -n '1,220p' book/README.md
sed -n '1,220p' ebook/README.md
find backend/routes -maxdepth 2 -type f | sort | sed -n '1,120p'
sed -n '1,220p' backend/routes/game.js
sed -n '1,220p' backend/routes/leaderboard.js
sed -n '1,220p' frontend/src/scripts/game.js
```

### What We Learned

- The real runtime app is compact:
  - `backend/`
  - `frontend/`
  - `database/`
  - `docker-compose.yml`
- The repo also contains extensive course/book packaging:
  - `docs/`
  - `book/`
  - `ebook/`
- The app itself is a memory game with a Node backend and static frontend.
- It already exposes `/health`, `/api/health`, and `/metrics`.
- Its compose stack already joins `observability-net` as:
  - `memflip-backend`
  - `memflip-frontend`

### Problems Identified In The Repo

#### 1. Stray `~/` directory inside repo

Command used to confirm:

```bash
find '~' -maxdepth 3 -type f | sed -n '1,120p'
```

Finding:

- the repo contains `~/.cloudflared/config.yml`

Why it matters:

- this looks accidental
- this is repo noise and probably should not be versioned

#### 2. Built output and packaged content mixed into app repo

- `frontend/dist/` exists
- `docs/`, `book/`, and `ebook/` coexist with runtime code

Why it matters:

- this makes the repo feel larger and noisier than the actual app is

### Why This Step Mattered

This phase told us `MemFlip` is useful as a lightweight monitored app, not as the main flagship system.

---

## Phase 5: FoodPulse Discovery

### Goal

Understand the newly added app and determine whether it is an app repo, a lab repo, or a wrapper around an upstream project.

### Commands

```bash
ls -la
find . -maxdepth 1 -mindepth 1 -type d | sort
find . -maxdepth 2 \( -name README.md -o -name package.json -o -name docker-compose.yml -o -name pyproject.toml -o -name go.mod \) | sort | sed -n '1,200p'
pwd
ls -la
find . -maxdepth 2 -type d | sort | sed -n '1,220p'
find . -maxdepth 3 -type f | sort | sed -n '1,240p'
sed -n '1,320p' docker-compose.yml
sed -n '1,260p' yelb/README.md
sed -n '1,260p' command.sh
sed -n '1,220p' monitoring/prometheus.yml
sed -n '320,520p' docker-compose.yml
sed -n '1,220p' scripts/cluster-status.sh
sed -n '1,220p' scripts/redis-failover-drill.sh
sed -n '1,220p' scripts/pg-failover-drill.sh
sed -n '1,220p' yelb/yelb-appserver/README.md
sed -n '1,220p' yelb/yelb-ui/README.md
sed -n '1,220p' yelb/yelb-db/README.md
find ui -maxdepth 2 -type f | sort | sed -n '1,120p'
find . -maxdepth 2 \( -name '.env' -o -name '.env*' -o -name '*env*' \) | sort
rg -n "YELB_DB_SERVER|YELB_DB_USER|YELB_DB_PASSWORD|YELB_REDIS_PASSWORD|GF_ADMIN_USER|POSTGRES_EXPORTER_DSN" -S . | sed -n '1,200p'
```

### What We Learned

- `FoodPulse` is really a HA/failover lab built around `Yelb`.
- It includes:
  - Yelb UI
  - Yelb appserver
  - Postgres primary + replicas
  - Redis master + replicas + Sentinel
  - HAProxy for Postgres and Redis routing
  - Prometheus
  - Grafana
  - Blackbox Exporter
  - Alertmanager
- It already joins `observability-net` with alias `foodpulse-ui`.
- This lines up with the app inventory already defined in `Obervability-Stack`.

### Problems Identified In The Repo

#### 1. No top-level README

- there is no main repo entrypoint

Why it matters:

- operators have to reverse-engineer the repo from compose and scripts

#### 2. No `.env` or `.env.example`

Finding:

- env-dependent variables exist in compose
- no env template is checked in

Why it matters:

- repo is not self-explanatory to bootstrap

#### 3. `command.sh` looks like notes/history, not a production script

Why it matters:

- this kind of file is useful as scratch context
- but it increases ambiguity about the canonical path

#### 4. `scripts/pg-failover-drill.sh` appears partially duplicated/corrupted

Why it matters:

- failover scripts are precisely the kind of asset operators need to trust
- duplicated or malformed preamble is a reliability warning

#### 5. Overlapping database directories

- root-level `yelb-db/`
- vendored `yelb/yelb-db/`

Why it matters:

- they may serve different purposes
- but the naming makes the repo harder to navigate quickly

### Why This Step Mattered

This phase showed that `FoodPulse` is more useful as a resilience lab than as a flagship feature app.

---

## Phase 6: OpenSIS Discovery

### Goal

Understand whether `OpenSIS` is just a legacy app dump or a fully platformized app deployment repo.

### Commands

```bash
ls -la
find . -maxdepth 1 -mindepth 1 -type d | sort
find . -maxdepth 2 \( -name README.md -o -name package.json -o -name docker-compose.yml -o -name pyproject.toml -o -name go.mod -o -name Cargo.toml \) | sort | sed -n '1,240p'
pwd
ls -la
find . -maxdepth 2 -type d | sort | sed -n '1,240p'
sed -n '1,280p' README.md
sed -n '1,320p' docker-compose.yaml
sed -n '1,260p' docs/06-architecture-reference.md
find scripts -maxdepth 1 -type f | sort | sed -n '1,200p'
sed -n '1,220p' scripts/precheck.sh
find observability -maxdepth 3 -type f | sort | sed -n '1,200p'
find k8s -maxdepth 3 -type f | sort | sed -n '1,240p'
sed -n '1,240p' docs/03-kubernetes-bootstrap-guide.md
sed -n '1,240p' tests/README.md
find app -maxdepth 2 -type f | sort | sed -n '1,220p'
sed -n '1,240p' observability/README.md
sed -n '1,220p' scripts/compose-start.sh
sed -n '1,220p' scripts/smoke-dev.sh
```

### What We Learned

- `OpenSIS` is a legacy PHP monolith wrapped in a serious platform layer.
- The app code lives in `app/`.
- The platform layer includes:
  - Docker Compose
  - Vault
  - Vault bootstrap and seeding
  - Vault agents
  - MariaDB
  - Kubernetes manifests
  - GitOps
  - observability
  - backup and restore workflows
- It already attaches to `observability-net` with alias `opensis-ui`.
- The repo docs are clearer and more operator-friendly than most of the other app repos.

### Problems Identified In The Repo

#### 1. Upstream app complexity

- `app/` is large, monolithic, and old-style PHP

Why it matters:

- app-level feature changes will likely be slower and riskier than platform-level changes

#### 2. Repo complexity is legitimate, but high

- many layers are packed into one repo:
  - app
  - local compose
  - Vault
  - Kubernetes
  - Argo CD
  - observability
  - tests

Why it matters:

- it is powerful
- but operators need a strong canonical path, which is why the docs matter so much here

### Why This Step Mattered

This phase established `OpenSIS` as the strongest example of modern platform practices wrapped around a legacy application.

---

## Phase 7: Workspace Rescans When New Repos Were Added

### Goal

Detect newly added repos and continue the same discovery pattern consistently.

### Commands

These scans were repeated as the workspace changed:

```bash
ls -la
find . -maxdepth 1 -mindepth 1 -type d | sort
find . -maxdepth 2 \( -name README.md -o -name package.json -o -name docker-compose.yml -o -name pyproject.toml -o -name go.mod \) | sort | sed -n '1,200p'
find . -maxdepth 2 \( -name README.md -o -name package.json -o -name docker-compose.yml -o -name pyproject.toml -o -name go.mod -o -name Cargo.toml \) | sort | sed -n '1,240p'
```

### Why This Step Mattered

We needed to treat the workspace as evolving, not static.
As new repos appeared, the discovery runbook needed to stay current.

---

## Phase 8: Runbook Creation

### Goal

Create a single living runbook for the whole journey.

### Commands

```bash
pwd
ls -la
```

### What We Did

- created this file at the workspace root:
  - `JOURNEY-RUNBOOK.md`

### Why This Step Mattered

Without a single shared runbook, the reasoning and command history would stay trapped in chat history instead of becoming reusable project documentation.

---

## Current Cross-Repo Summary

### `Obervability-Stack`

- role: control plane
- strongest value: unified app monitoring and dashboarding
- current concern: docs drift, partial demo-grade auth

### `SwiftPay`

- role: flagship application
- strongest value: best app architecture and metrics story
- current concern: large service files, older frontend stack

### `MemFlip`

- role: simple monitored app
- strongest value: lightweight demo and onboarding target
- current concern: repo noise and packaged content mixed with runtime app

### `FoodPulse`

- role: HA/failover lab
- strongest value: resilience and operational drills
- current concern: missing canonical docs/env template, script trustworthiness

### `OpenSIS`

- role: legacy monolith with serious platform wrapper
- strongest value: Vault, GitOps, observability, ops maturity
- current concern: large inherited app surface

## Open Issues To Track

These are not fixed yet. They are simply recorded for future work.

1. `Obervability-Stack` docs and port references need reconciliation.
2. `Obervability-Stack` auth path likely needs hardening beyond demo users.
3. `MemFlip` repo noise should be cleaned up, especially the stray `~/` folder.
4. `FoodPulse` needs a proper `README.md`.
5. `FoodPulse` likely needs an `.env.example`.
6. `FoodPulse/scripts/pg-failover-drill.sh` should be repaired and validated.
7. We need a consistent cross-repo startup, observability, and runbook story.

## Update Rule Going Forward

For all future work on this workspace:

- log the command
- log the reason
- log the result
- log the problem if any
- log the fix
- log the follow-up

This file is now the canonical journey notebook.

---

## Phase 10: Correct Git Author Identity

### Goal

Replace the auto-detected local Git identity with the preferred project identity:

- name: `Eseosa`
- email: `e_raywhite@yahoo.com`

### Why We Did This

The first two monorepo commits were created with the local machine identity:

```text
Raymond <raymond@mac.home>
```

That was acceptable for a local commit to keep momentum moving, but not the right long-term author identity for the repository history.

### Commands

Inspect current authors:

```bash
git log --format='%h %an <%ae> %s' -n 5
```

Set the repo-local Git identity:

```bash
git config user.name "Eseosa"
git config user.email "e_raywhite@yahoo.com"
```

### Problems Encountered

#### 1. `HEAD~2` was not a valid upstream

Initial attempted command:

```bash
git rebase -x 'git commit --amend --no-edit --reset-author' HEAD~2
```

Problem:

- the repo only had two commits total
- `HEAD~2` does not exist in that case

Git error:

```text
fatal: invalid upstream 'HEAD~2'
```

Fix:

- rerun the author reset from the root of history instead:

```bash
git rebase --root -x 'git commit --amend --no-edit --reset-author'
```

Why it mattered:

- this reset the author metadata on both commits cleanly without needing interactive rebase

### Result

After the successful `--root` rebase, the existing commits were rewritten with the correct identity.

### Follow-Up

Because commit hashes changed, the branch had to be pushed again with history replacement semantics:

```bash
git push --force-with-lease
```

---

## Phase 11: Establish Project Roadmap

### Goal

Define a solid execution roadmap for the whole workspace now that:

- the monorepo is established
- the author identity is correct
- the initial repo discovery is complete

### Why We Did This

We now have enough context to stop thinking in repo-by-repo fragments and start operating with a platform plan.

Without a roadmap, the project would drift into opportunistic fixes instead of building toward a coherent end state.

### Work Performed

- created a root roadmap document:
  - `PROJECT-ROADMAP.md`

### Roadmap Focus

The roadmap defines the project as a multi-app platform engineering lab built around:

- `Obervability-Stack` as control plane
- `SwiftPay` as flagship app
- `OpenSIS` as legacy-platform case
- `FoodPulse` as resilience lab
- `MemFlip` as lightweight demo app

It organizes the work into these major phases:

1. foundation and governance
2. workspace normalization
3. control plane hardening
4. app integration and onboarding
5. operator workflows and incident drills
6. UX and demo polish
7. production-style maturity and portfolio packaging

### Immediate Recommendation Captured In The Roadmap

The recommended next execution step is:

- start with workspace normalization

Reason:

- it reduces chaos before platform integration work begins

### Result

The workspace now has:

- a living journey notebook
- a formal execution roadmap
- a rooted monorepo structure

This gives the project both operational memory and strategic direction.

---

## Phase 12: Phase 2 Workspace Normalization - First Slice

### Goal

Start Phase 2 by creating clear root-level workspace contracts and fixing the most obvious setup/documentation gaps.

### Why We Did This

Before hardening the control plane, we need the workspace itself to be predictable.

That means:

- clear platform architecture at the root
- clear repo setup expectations at the root
- explicit alias verification
- missing env templates filled in
- obvious junk removed where safe

### Commands Used

Baseline discovery:

```bash
find . -maxdepth 1 -mindepth 1 -type f | sort
rg -n "observability-net|aliases:|ports:|docker compose|docker-compose|compose-start|precheck|healthcheck" Obervability-Stack/docker-compose.yml SwiftPay/docker-compose.yml MemFlip/docker-compose.yml FoodPulse/docker-compose.yml OpenSIS/docker-compose.yaml OpenSIS/scripts/compose-start.sh Obervability-Stack/ui-next/lib/monitored-apps.ts | sed -n '1,260p'
find . -path '*/.env.example' -o -path '*/env.example' -o -path '*/docker-compose.env.example' | sort
find MemFlip -path 'MemFlip/~' -o -path 'MemFlip/frontend/dist' | sort
```

Detailed alias and contract extraction:

```bash
nl -ba Obervability-Stack/ui-next/lib/monitored-apps.ts | sed -n '1,320p'
nl -ba SwiftPay/docker-compose.yml | sed -n '150,390p'
nl -ba MemFlip/docker-compose.yml | sed -n '60,155p'
nl -ba FoodPulse/docker-compose.yml | sed -n '1,365p'
nl -ba OpenSIS/docker-compose.yaml | sed -n '240,385p'
```

Cleanup and missing-contract discovery:

```bash
git ls-files | rg '\.DS_Store$|(^|/)~/'
rg -n "MYSQL_ROOT_PASSWORD|MYSQL_DATABASE|MYSQL_USER|MYSQL_PASSWORD|APP_ENV|GRAFANA_ADMIN_PASSWORD" OpenSIS/docker-compose.yaml OpenSIS/docs OpenSIS/scripts | sed -n '1,200p'
rg -n "YELB_DB_SERVER|YELB_REDIS_SERVER|YELB_REDIS_PASSWORD|YELB_DB_USER|YELB_DB_PASSWORD|PG_REPLICATOR_PASSWORD|POSTGRES_EXPORTER_DSN|GF_ADMIN_USER|GF_ADMIN_PASSWORD" FoodPulse/docker-compose.yml FoodPulse/scripts FoodPulse/monitoring FoodPulse/haproxy | sed -n '1,240p'
sed -n '1,240p' OpenSIS/docs/02-local-compose-guide.md
find OpenSIS -maxdepth 2 \( -name '.env' -o -name '.env.example' -o -name '*example*' \) | sort
git ls-files FoodPulse/command.sh MemFlip/~/.cloudflared/config.yml
```

Verification after edits:

```bash
git status --short
sed -n '1,220p' WORKSPACE-ARCHITECTURE.md
sed -n '1,240p' WORKSPACE-SETUP-MATRIX.md
sed -n '1,220p' FoodPulse/README.md
sed -n '1,120p' FoodPulse/.env.example
sed -n '1,120p' OpenSIS/.env.example
```

### Files Added

- `WORKSPACE-ARCHITECTURE.md`
- `WORKSPACE-SETUP-MATRIX.md`
- `FoodPulse/README.md`
- `FoodPulse/.env.example`
- `OpenSIS/.env.example`

### Files Removed

- `MemFlip/~/.cloudflared/config.yml`

### What We Learned

#### 1. The alias model is already stronger than the docs

The control plane inventory in `Obervability-Stack/ui-next/lib/monitored-apps.ts` already matched the real Docker aliases in:

- `SwiftPay`
- `OpenSIS`
- `FoodPulse`
- `MemFlip`

That was important because it meant we were documenting an existing contract, not inventing a new one.

#### 2. `FoodPulse` and `OpenSIS` both lacked committed env templates

This made local setup less predictable than it should be.

We fixed that by adding:

- `FoodPulse/.env.example`
- `OpenSIS/.env.example`

#### 3. `FoodPulse` lacked a top-level README

This was a real normalization gap because the repo had no clean canonical entrypoint.

We fixed that by adding:

- `FoodPulse/README.md`

#### 4. `MemFlip/~/.cloudflared/config.yml` was confirmed as stray repo noise

That file was tracked and did not belong in the source tree or platform story.

We removed it.

### Why These Changes Mattered

These changes made the workspace easier to reason about in three ways:

1. root-level platform understanding now exists
2. repo startup and alias expectations are now explicit
3. missing setup contracts in app repos were replaced with real examples

### Deferred Cleanup Items

These were identified but not changed in this slice:

- `FoodPulse/command.sh` still exists as a scratch/history file
- `FoodPulse/scripts/pg-failover-drill.sh` still needs a trust/readability review
- `MemFlip/frontend/dist` still exists and may be generated output rather than source
- `Obervability-Stack` docs still need reconciliation with actual ports and behavior

### Result

Phase 2 is now active and has produced its first concrete artifacts.

The workspace now has:

- a root architecture summary
- a root setup matrix
- explicit alias verification
- env templates for missing repos
- one obvious junk file removed safely

---

## Phase 9: Flatten Nested Repos Into One Main Repository

### Goal

Convert the workspace into one top-level Git repository, remove the five nested repo histories, and connect the root to the GitHub project:

`https://github.com/eseosaiyangbe/DevOps-Easy-Learning.git`

### Why We Did This

We decided to treat this workspace as one multi-app platform project instead of five separate Git roots.

That matters because:

- the repos are meant to work together
- the observability repo is already modeling the app repos together
- the journey documentation belongs to the whole workspace
- future changes will likely span multiple repos at once

### Commands

Initial Git-state discovery:

```bash
find . -maxdepth 2 -name .git -type d | sort
git rev-parse --is-inside-work-tree
git status --short
find . \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name '.DS_Store' -o -name 'node_modules' -o -name '.next' \) | sort | sed -n '1,240p'
find . -type f | wc -l
find . -type d -name node_modules | sort | sed -n '1,100p'
```

Root repo prep:

```bash
rm -rf ./FoodPulse/.git ./MemFlip/.git ./Obervability-Stack/.git ./OpenSIS/.git ./SwiftPay/.git
git init -b main
find . -maxdepth 2 -name .git -type d | sort
git status --short
git remote -v
```

### Problems Encountered

#### 1. Dependent Git commands were run in parallel

What happened:

- `git init -b main`
- `git remote add origin ...`
- verification commands

were launched in parallel during one execution wave.

Result:

- `git remote add origin` failed with:

```text
fatal: not a git repository (or any of the parent directories): .git
```

Why:

- `git remote add` depends on the root `.git` directory already existing
- parallel execution was fine for independent reads, but not for sequential Git initialization

Fix:

- rerun the Git setup in proper order after verifying the root repo exists

Lesson:

- do not parallelize commands when one command depends on side effects from another

### Safety Notes

Before flattening the repos, we checked for obvious files that should not be pushed accidentally.

Findings:

- `.DS_Store` files were present
- `SwiftPay/.env.example` was present
- no obvious live `.env` files or key files were discovered in the workspace root scan

### Files Added For The New Root Repo

- root `.gitignore`
- root `JOURNEY-RUNBOOK.md`

### Status At End Of This Phase

- root Git repo initialized
- nested Git repos removed
- root is now the canonical repository location
- remote wiring, commit, and push were the next steps

### Follow-On Git Commands Used

```bash
git remote add origin https://github.com/eseosaiyangbe/DevOps-Easy-Learning.git
git remote -v
git add .
git status --short | sed -n '1,120p'
git commit -m "Initialize DevOps Easy Learning monorepo"
git push -u origin main
```

### Additional Problems Encountered

#### 2. `git status` was checked too early during staging

What happened:

- `git add .`
- `git status --short`

were launched in the same parallel batch once.

Result:

- the status output still showed everything as untracked
- that output was stale, not authoritative

Fix:

- reran staging and status sequentially:

```bash
git add . && git status --short | sed -n '1,120p'
```

Lesson:

- status checks should happen after staging completes, not beside it

#### 3. GitHub push protection blocked the first push

What happened:

- the first push was rejected by GitHub repository rules
- GitHub detected real-looking Slack Incoming Webhook URLs in imported files

Blocked locations:

- `FoodPulse/monitoring/alertmanager.yml`
- `OpenSIS/k8s/FROM_SCRATCH_LOCAL_BOOTSTRAP.md`
- `OpenSIS/k8s/base/observability/alertmanager/secret.yaml`
- `Obervability-Stack/docs/NOTIFICATIONS_INTEGRATION.md`

Commands used to inspect and sweep:

```bash
nl -ba FoodPulse/monitoring/alertmanager.yml | sed -n '1,80p'
nl -ba Obervability-Stack/docs/NOTIFICATIONS_INTEGRATION.md | sed -n '140,180p'
nl -ba OpenSIS/k8s/FROM_SCRATCH_LOCAL_BOOTSTRAP.md | sed -n '1376,1394p'
nl -ba OpenSIS/k8s/base/observability/alertmanager/secret.yaml | sed -n '1,40p'
rg -n "hooks\\.slack\\.com/services/" -S . | sed -n '1,120p'
rg -n "T09BTEF6PBQ|B0A27R4269E|B0APQE1458C|Mam6XIKYlQotCOj3KQtq3Rb8|SxN9M6vz44dwQSLrMHN673CM" -S .
```

Fix:

- replaced real webhook values with placeholders using the pattern:

```text
https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

- amended the root commit to remove the secrets from commit history:

```bash
git add FoodPulse/monitoring/alertmanager.yml OpenSIS/k8s/FROM_SCRATCH_LOCAL_BOOTSTRAP.md OpenSIS/k8s/base/observability/alertmanager/secret.yaml
git commit --amend --no-edit
git add Obervability-Stack/docs/NOTIFICATIONS_INTEGRATION.md
git commit --amend --no-edit
git push -u origin main
```

Why it mattered:

- this was not just a formatting problem
- the remote would not accept the repository until secret-looking values were removed from commit history

### Final Status

- root repo initialized successfully
- nested `.git` directories removed
- remote `origin` configured
- initial monorepo commit created
- push protection issue resolved by redacting webhook values
- `main` pushed successfully to:

```text
https://github.com/eseosaiyangbe/DevOps-Easy-Learning.git
```

---

## Phase 8: Phase 2 Normalization Slice 2

### Goal

Clean the remaining obvious rough edges from workspace normalization while keeping the future Kubernetes migration in mind.

This slice focused on:

- repairing broken or misleading operator paths
- reconciling control-plane docs with the actual runtime
- making the local setup contract easier to translate into Kubernetes later

### Commands

```bash
git status --short
sed -n '1,260p' FoodPulse/scripts/pg-failover-drill.sh
sed -n '1,220p' FoodPulse/command.sh
sed -n '1,240p' Obervability-Stack/docs/README.md
sed -n '1,240p' WORKSPACE-ARCHITECTURE.md
sed -n '1,260p' JOURNEY-RUNBOOK.md
sed -n '1,260p' WORKSPACE-SETUP-MATRIX.md
sed -n '1,220p' FoodPulse/README.md
sed -n '1,240p' Obervability-Stack/README.md
rg -n "frontend/dist|dist/|build artifact|generated" MemFlip -g '!**/node_modules/**'
git ls-files MemFlip/frontend/dist FoodPulse/command.sh FoodPulse/scripts/pg-failover-drill.sh Obervability-Stack/docs/README.md WORKSPACE-ARCHITECTURE.md WORKSPACE-SETUP-MATRIX.md JOURNEY-RUNBOOK.md
tail -n 120 FoodPulse/scripts/pg-failover-drill.sh
sed -n '1,220p' FoodPulse/scripts/redis-failover-drill.sh
sed -n '1,220p' FoodPulse/scripts/cluster-status.sh
sed -n '1,220p' MemFlip/frontend/Dockerfile
sed -n '1,220p' MemFlip/docker-compose.yml
chmod +x FoodPulse/command.sh FoodPulse/scripts/pg-failover-drill.sh
bash -n FoodPulse/command.sh
bash -n FoodPulse/scripts/pg-failover-drill.sh
ls -l FoodPulse/command.sh FoodPulse/scripts/pg-failover-drill.sh
```

### What We Learned

#### `FoodPulse`

- `command.sh` was not a real script.
- It was a scratchpad of free-form notes and would fail if executed.
- `scripts/pg-failover-drill.sh` had duplicated content and a corrupted top section.
- `scripts/redis-failover-drill.sh` was the better reference for what a usable lab drill should look like.

#### `Obervability-Stack`

- `docs/README.md` still advertised stale port mappings.
- The root `README.md` already matched the current local runtime more closely.
- The docs index needed to become explicit that it is a navigation surface, not the primary runtime source of truth.

#### `MemFlip`

- `frontend/dist` is present in the repo, but the Docker build still builds from source.
- That means checked-in frontend artifacts are not the architecture contract we want to preserve for Kubernetes.
- We should treat the source tree plus Docker image build as the real contract and avoid designing around committed build output.

### Problems Encountered

#### 1. `FoodPulse/command.sh` looked executable but was not actually safe to run

Problem:

- the file had shell extension but contained unstructured notes
- anyone treating it like a real operator script would hit errors immediately

Fix:

- converted it into a safe shell wrapper that prints guidance and preserves the historical notes as comments

Why it mattered:

- in a multi-repo workspace, misleading files are worse than noisy files
- if we keep a historical artifact, it needs to fail safe

#### 2. `FoodPulse/scripts/pg-failover-drill.sh` was duplicated and partially corrupted

Problem:

- the file repeated its own preamble and contained a second, conflicting implementation lower down
- this made the drill untrustworthy before even considering the actual database behavior

Fix:

- rewrote the file into one clean script
- kept its intent explicit: manual educational failover drill, not production-grade automation
- aligned its structure with the healthier Redis drill style

Why it mattered:

- broken drills are dangerous because they teach the wrong operator habits
- Kubernetes migration will not remove the need for good operational drills, so the drill needs to be conceptually clean now

#### 3. Control-plane docs were partially stale

Problem:

- `Obervability-Stack/docs/README.md` still referenced old ports for the UI and Grafana

Fix:

- updated the docs index to match the current local runtime
- added a note pointing operators back to the root `README.md` for startup truth

Why it mattered:

- observability is the hub of the workspace
- when the hub docs drift, every app onboarding and troubleshooting step gets less reliable

### Fixes Applied

Files updated:

- `FoodPulse/command.sh`
- `FoodPulse/scripts/pg-failover-drill.sh`
- `FoodPulse/README.md`
- `Obervability-Stack/docs/README.md`
- `WORKSPACE-ARCHITECTURE.md`
- `WORKSPACE-SETUP-MATRIX.md`

Behavioral improvements:

- `FoodPulse/command.sh` is now safe to execute
- `FoodPulse/scripts/pg-failover-drill.sh` now passes `bash -n`
- the workspace docs now explicitly frame Docker Compose as the proving ground and Kubernetes as the destination
- the setup matrix now includes a Kubernetes-readiness lens per repo instead of treating local Compose setup as the end state

### Kubernetes-Minded Decisions

We explicitly chose the following direction in this phase:

- prefer documenting env contracts now because they can become ConfigMaps and Secrets later
- prefer health endpoints because they map cleanly to readiness and liveness probes
- treat `observability-net` aliases as local stand-ins for future Kubernetes Services
- avoid blessing committed frontend build artifacts as the long-term deployment contract
- treat local helper scripts as operator aids, not the permanent control plane

### Things We Deliberately Did Not Change Yet

#### `MemFlip/frontend/dist`

Decision:

- do not remove it yet

Why:

- it is tracked today and referenced in project materials
- removing it blindly could create noise without improving the actual runtime contract
- for now, documenting that it should not become part of the future Kubernetes architecture is the safer move

#### deeper `Obervability-Stack` docs

Decision:

- do not try to refresh every doc page in one sweep

Why:

- the immediate risk was port and startup drift in the main docs index
- a larger docs audit should happen as a dedicated control-plane hardening task

### Why This Step Mattered

This phase reduced hidden local fragility.

That matters because Kubernetes migrations usually fail when teams carry forward:

- ambiguous startup contracts
- Docker-only assumptions
- misleading scripts
- undocumented drift between docs and runtime

We are trying to reduce those translation problems now instead of discovering them during the cluster move.

### Follow-Up Work

- continue Phase 2 by tightening startup and health contracts where they are still fuzzy
- begin identifying which workloads are closest to having clean Kubernetes manifests already
- start mapping `Obervability-Stack` assumptions from Docker aliases toward service-oriented discovery

---

## Phase 9: Roadmap Status Tracking

### Goal

Make the roadmap reflect current execution state, not just planned future phases.

### Commands

```bash
sed -n '1,260p' PROJECT-ROADMAP.md
git status --short
tail -n 80 JOURNEY-RUNBOOK.md
```

### What We Changed

- added a phase status tracker to `PROJECT-ROADMAP.md`
- marked Phase 1 as complete
- kept Phase 2 as in progress
- marked Phases 3 through 7 as not started
- added a current-focus section
- added a practical definition of done for Phase 2
- added explicit current-status sections for Phases 2 and 3

### Why This Mattered

The roadmap was already strong as a strategy document, but it did not yet answer the project-management question:

```text
Where are we right now?
```

Adding status tracking fixes that without flattening the roadmap into a checklist.

It gives us:

- a shared project state view
- a cleaner handoff between phases
- less ambiguity when deciding whether a task still belongs to Phase 2 or should move into Phase 3

### Follow-Up Work

- keep the roadmap status tracker current as we complete major phase milestones
- use the Phase 2 definition of done to decide when to transition into control-plane hardening

---

## Phase 10: MemFlip Startup Contract Normalization

### Goal

Tighten the local startup and health contract for `MemFlip` so the active Docker Compose path matches the documented user journey and translates more cleanly into future Kubernetes service boundaries.

### Commands

```bash
sed -n '1,260p' MemFlip/README.md
sed -n '1,260p' MemFlip/env/env.example
sed -n '1,260p' OpenSIS/.env.example
sed -n '1,260p' SwiftPay/.env.example
sed -n '1,260p' OpenSIS/scripts/compose-start.sh
sed -n '1,260p' SwiftPay/scripts/validate.sh
sed -n '1,280p' SwiftPay/docker-compose.yml
sed -n '1,220p' SwiftPay/README.md
rg -n "8080|8081|3000|3001|3007|health" MemFlip/README.md MemFlip/docs -g '!**/node_modules/**'
sed -n '1,240p' MemFlip/frontend/nginx.conf
sed -n '1,240p' MemFlip/backend/server.js
rg -n "app\\.get\\('/health'|app\\.get\\('/api/health'|router\\.get\\('/health'|/api/health|/metrics" MemFlip/backend -g '!**/node_modules/**'
sed -n '1,220p' MemFlip/docs/local/README.md
sed -n '1,240p' MemFlip/docs/local/02-compose.md
sed -n '1,220p' MemFlip/docs/local/user-guide.md
docker compose --env-file .env.example config >/tmp/memflip-compose-config.out
git diff --stat
git status --short
```

### What We Learned

- `MemFlip` documentation mostly assumes the local browser entrypoint is `http://localhost:8080`.
- The active `docker-compose.yml` did not actually publish the frontend on a host port.
- The frontend Nginx config already proxies `/api/*` to the backend container.
- The backend already exposes both `/health` and `/api/health`.

That means the user-facing health path already existed conceptually.
The local Compose contract was simply lagging behind the intended architecture.

### Problems Encountered

#### 1. `MemFlip` docs and active Compose behavior disagreed

Problem:

- docs pointed users to `http://localhost:8080`
- active Compose only exposed the backend on `3001`
- frontend access depended on internal networking rather than the documented local browser path

Fix:

- published the frontend on `FRONTEND_HOST_PORT` with a default of `8080`
- updated the main local docs to treat `http://localhost:8080` as the primary browser URL
- updated the workspace setup matrix to use the proxied health check `http://localhost:8080/api/health`

Why it mattered:

- startup contracts should describe the real path users and operators take
- this is also a better precursor to Kubernetes, where the frontend service and the user-facing health path matter more than direct container access

#### 2. `MemFlip` lacked a root `.env.example`

Problem:

- there was a detailed `env/env.example`, but not a root `.env.example` aligned with Docker Compose conventions

Fix:

- added `MemFlip/.env.example`
- kept it focused on the local Compose contract
- left `env/env.example` as the deeper reference

Why it mattered:

- Phase 2 is trying to standardize repo-root startup expectations
- a root `.env.example` is easier to copy into `.env` locally and easier to map later into Kubernetes ConfigMaps and Secrets

#### 3. Live Compose rendering could not be verified in this shell

Problem:

- this environment does not have `docker` installed
- running:

```bash
docker compose --env-file .env.example config
```

failed with:

```text
zsh:1: command not found: docker
```

Fix:

- verified the file-level contract changes directly in the compose file and docs
- documented the missing local Docker binary as a verification limitation for this session

Why it mattered:

- the repo changes are still valid and reviewable
- but we should distinguish between “config reviewed” and “runtime validated”

### Fixes Applied

Files updated:

- `MemFlip/docker-compose.yml`
- `MemFlip/.env.example`
- `MemFlip/README.md`
- `MemFlip/docs/local/README.md`
- `MemFlip/docs/local/02-compose.md`
- `MemFlip/docs/local/user-guide.md`
- `WORKSPACE-SETUP-MATRIX.md`

Behavioral improvements:

- `MemFlip` now has a standard root env example
- the frontend is explicitly published for local use on `8080` by default
- the preferred operator health check is now the user-facing proxied route
- workspace docs now reflect a cleaner frontend/backend boundary for `MemFlip`

### Kubernetes-Minded Decisions

We intentionally moved `MemFlip` toward a more Kubernetes-friendly shape:

- browser entrypoint on a dedicated frontend port
- health verification through the user-facing route
- root env contract for future ConfigMap and Secret mapping
- frontend and backend treated as separate concerns, even in local Compose

### Why This Step Mattered

This change removes a quiet but important mismatch:

- the docs said one thing
- the actual runtime contract said another

Fixing that now makes local onboarding easier and avoids carrying a misleading Docker-only assumption into later Kubernetes work.

### Follow-Up Work

- finish the remaining Phase 2 startup and health contract cleanup across the workspace
- start identifying which normalization gaps are still true blockers for Phase 3 control-plane hardening

---

## Phase 11: macOS Workstation Bootstrap

### Goal

Bootstrap this new Apple Silicon Mac mini with the toolchain needed to work on the monorepo.

The target was not just “install some binaries.”
The target was:

- get the local container runtime working
- get Kubernetes and infrastructure CLIs available
- get cloud CLIs available
- do it in a way that matches the constraints of this machine

### Commands

```bash
uname -a
uname -m
which brew || true
for t in git rg jq curl wget docker docker-compose kubectl helm kustomize kind k3d terraform aws az node npm python3 pip3 make yq cloudflared openssl; do printf '%-15s' "$t"; command -v "$t" || echo MISSING; done
rg -n "Prerequisites|brew install|Docker Desktop|kubectl|helm|terraform|aws cli|AWS CLI|az |Azure CLI|cloudflared|k3d|kind|microk8s|multipass|jq|yq|node|npm|python|make|git" MemFlip OpenSIS SwiftPay FoodPulse Obervability-Stack -g 'README*' -g 'docs/**' -g 'scripts/**'
xcode-select -p || true
whoami
echo $SHELL
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
curl -I -fsSL https://desktop.docker.com/mac/main/arm64/Docker.dmg
curl -fsSL https://api.github.com/repos/abiosoft/colima/releases/latest | jq -r '.tag_name'
curl -fsSL https://api.github.com/repos/lima-vm/lima/releases/latest | jq -r '.tag_name'
bash -x ./scripts/bootstrap-macos-userland.sh
source ~/.zprofile >/dev/null 2>&1; for t in docker docker-compose colima limactl kubectl helm kustomize kind k3d terraform node npm aws az yq cloudflared argocd; do printf '%-15s' "$t"; command -v "$t" || echo MISSING; done
source ~/.zprofile >/dev/null 2>&1; docker --version
source ~/.zprofile >/dev/null 2>&1; docker compose version
source ~/.zprofile >/dev/null 2>&1; colima version
source ~/.zprofile >/dev/null 2>&1; limactl --version
source ~/.zprofile >/dev/null 2>&1; kubectl version --client=true
source ~/.zprofile >/dev/null 2>&1; helm version --short
source ~/.zprofile >/dev/null 2>&1; kustomize version
source ~/.zprofile >/dev/null 2>&1; kind version
source ~/.zprofile >/dev/null 2>&1; k3d version
source ~/.zprofile >/dev/null 2>&1; terraform version | head -n 1
source ~/.zprofile >/dev/null 2>&1; node --version
source ~/.zprofile >/dev/null 2>&1; npm --version
source ~/.zprofile >/dev/null 2>&1; aws --version
source ~/.zprofile >/dev/null 2>&1; az version --output json | jq -r '."azure-cli"'
source ~/.zprofile >/dev/null 2>&1; yq --version
source ~/.zprofile >/dev/null 2>&1; cloudflared version
source ~/.zprofile >/dev/null 2>&1; argocd version --client --short
source ~/.zprofile >/dev/null 2>&1; colima start --runtime docker --cpu 4 --memory 8 --disk 60
source ~/.zprofile >/dev/null 2>&1; docker context ls
source ~/.zprofile >/dev/null 2>&1; docker context create colima --docker "host=unix://${HOME}/.colima/default/docker.sock" 2>/dev/null || true
source ~/.zprofile >/dev/null 2>&1; docker context use colima
source ~/.zprofile >/dev/null 2>&1; docker version
source ~/.zprofile >/dev/null 2>&1; docker compose version
source ~/.zprofile >/dev/null 2>&1; docker run --rm hello-world
cat ~/.docker/config.json
```

### What We Learned

- This machine is `darwin/arm64`.
- It had Apple Command Line Tools already installed.
- It did not have Homebrew.
- It did not have admin rights for standard Homebrew installation.
- Most of the project toolchain was missing:
  - Docker
  - Docker Compose
  - kubectl
  - helm
  - kustomize
  - kind
  - k3d
  - terraform
  - aws
  - az
  - yq
  - cloudflared
  - npm

### Problems Encountered

#### 1. Homebrew could not be installed normally

Problem:

- standard Homebrew install failed because the user does not have admin rights on this machine

Observed output:

```text
Need sudo access on macOS (e.g. the user raymond needs to be an Administrator)!
```

Fix:

- switched from a system-level package-manager approach to a user-space bootstrap strategy
- installed tools into `~/.local/bin`, `~/.local/opt`, `~/.docker/cli-plugins`, and local Python virtual environments

Why it mattered:

- this changed the entire workstation bootstrap design
- it also made the resulting setup more portable for locked-down machines

#### 2. The first bootstrap script runs exposed installer bugs

Problems:

- quoting bug in the Docker CLI version parser
- pipefail interaction in GitHub asset selection
- broken stale symlink at `~/.docker/cli-plugins/docker-compose`
- Lima install assumed the wrong archive layout
- AWS CLI download URL had drifted

Fixes:

- repaired the parser quoting
- removed the fragile `head -n 1` asset-selection pattern
- made downloads remove stale targets before writing
- changed Lima installation to install the bundle structure, not just one guessed path
- switched AWS CLI installation to a local Python virtual environment

Why it mattered:

- the installer needed to become robust before it could be trusted as a reusable bootstrap path

#### 3. Colima could not start at first because `lima` was not on PATH

Problem:

- Lima was installed, but only `limactl` had been linked into `~/.local/bin`
- Colima expected the `lima` wrapper binary as well

Fix:

- linked both `lima` and `limactl`
- updated the bootstrap script to expose both

Why it mattered:

- Colima is the local Docker runtime strategy on this machine
- without it, none of the Compose or k3d/kind workflows would be usable

#### 4. Docker was still pointed at stale Docker Desktop leftovers

Problems:

- active Docker context was `desktop-linux`
- `~/.docker/config.json` still had:

```json
"credsStore": "desktop"
```

- that caused image pulls to fail because the machine no longer had `docker-credential-desktop`

Fixes:

- created and switched to a `colima` Docker context
- removed the stale Docker Desktop credential-helper setting
- folded that cleanup into the bootstrap script itself

Why it mattered:

- installed binaries are not enough if Docker is still wired to dead local state

#### 5. Colima came up, but registry pulls hit a VM DNS issue

Problem:

- `docker version` worked against the Colima socket
- image pulls failed with DNS resolution errors inside the guest:

```text
lookup registry-1.docker.io on [::1]:53: read udp [::1]:...: read: connection refused
```

Fixes:

- updated `~/.colima/default/colima.yaml` to set explicit DNS servers:
  - `1.1.1.1`
  - `8.8.8.8`
- verified guest DNS directly with:

```bash
ssh -F ~/.colima/ssh_config colima 'cat /etc/resolv.conf && echo --- && getent hosts registry-1.docker.io || true'
```

- re-tested Docker Hub access with:

```bash
docker pull hello-world
docker run --rm hello-world
```

Current state:

- the toolchain is installed
- Colima is running
- Docker is pointed at Colima
- the DNS fix is applied and working
- Docker Hub pulls and container runs now succeed

Why it mattered:

- this is the remaining runtime sharp edge
- local image pulls must work before we can rely on Compose or build workflows end to end

### Fixes Applied

Repo changes:

- added `scripts/bootstrap-macos-userland.sh`

Machine changes:

- updated `~/.zprofile` to add:
  - `~/.local/bin`
  - `~/.docker/cli-plugins`
- installed user-space toolchain:
  - Docker CLI
  - Docker Compose plugin
  - Colima
  - Lima
  - kubectl
  - helm
  - kustomize
  - kind
  - k3d
  - terraform
  - Node.js + npm
  - AWS CLI
  - Azure CLI
  - yq
  - cloudflared
  - argocd
- switched Docker context to `colima`
- removed stale `credsStore: desktop` from Docker config
- set explicit DNS servers in the Colima profile

### Verification Results

Verified successfully:

- `docker --version`
- `docker compose version`
- `colima version`
- `limactl --version`
- `kubectl version --client`
- `helm version`
- `kustomize version`
- `kind version`
- `k3d version`
- `terraform version`
- `node --version`
- `npm --version`
- `aws --version`
- `az version`
- `yq --version`
- `cloudflared version`
- `argocd version --client`
- `docker version` against the Colima socket

Not yet fully validated:

- broader project-specific Compose stacks and Kubernetes cluster creation

### Why This Step Mattered

This machine bootstrap was necessary before deeper implementation work could continue.

Without this toolchain:

- we could not run Docker Compose stacks
- we could not validate or build Kubernetes workflows
- we could not work on Terraform-backed cloud paths
- we could not treat this Mac as a real operator workstation for the project

### Follow-Up Work

- once pulls are healthy, move back to the remaining Phase 2 normalization work

---

## Phase 12: Linux Workstation Bootstrap Companion

### Goal

Add a Linux companion bootstrap script so the workstation setup path is not limited to macOS users.

### Commands

```bash
sed -n '1,320p' scripts/bootstrap-macos-userland.sh
rg -n "bootstrap-macos-userland|workstation bootstrap|macOS workstation" JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md WORKSPACE-ARCHITECTURE.md WORKSPACE-SETUP-MATRIX.md -g '!**/node_modules/**'
ls scripts
bash -n scripts/bootstrap-linux-userland.sh
sed -n '1,260p' scripts/bootstrap-linux-userland.sh
git status --short
```

### What We Changed

- added `scripts/bootstrap-linux-userland.sh`

The Linux script mirrors the same broad toolchain goals as the macOS bootstrap:

- Docker + Docker Compose
- Kubernetes CLIs
- Terraform
- Node.js and npm
- AWS CLI
- Azure CLI
- yq
- cloudflared
- argocd

### Design Notes

The Linux version intentionally differs from the macOS version in a few ways:

- it targets Linux instead of Apple Silicon macOS
- it uses Docker Engine directly instead of Colima/Lima
- it detects `apt-get` and `dnf` for base package installation
- it still installs most project tooling into user-space locations such as:
  - `~/.local/bin`
  - `~/.local/opt`
  - `~/.docker/cli-plugins`
  - local Python virtual environments for `aws` and `az`

### Why This Mattered

The project already had a real workstation bootstrap path, but it was Mac-specific.

Adding the Linux companion matters because:

- collaborators should be able to follow the same project setup story on non-Mac machines
- the repo should carry its own bootstrap logic, not rely on private shell history
- a Linux path is especially relevant for people learning Kubernetes, Docker, and Terraform on cloud VMs or Linux laptops

### Validation Level

Validated here:

- shell syntax check via `bash -n`
- structure review against the macOS installer and current repo requirements

Not yet validated here:

- full end-to-end execution on a live Linux host

Why:

- this session is running on macOS, so we could not execute the Linux bootstrap directly

### Follow-Up Work

- when we have access to a Linux workstation or VM, run the script end to end and capture any Linux-specific issues in this runbook

---

## Phase 13: Root Bootstrap Guide

### Goal

Add one top-level workstation setup guide so new contributors know exactly where to start before diving into repo-specific docs.

### Commands

```bash
git status --short
sed -n '1,220p' PROJECT-ROADMAP.md
ls -la scripts
sed -n '1,320p' scripts/bootstrap-macos-userland.sh
bash -n scripts/bootstrap-linux-userland.sh
sed -n '1,260p' scripts/bootstrap-linux-userland.sh
```

### What We Changed

- added `WORKSTATION-BOOTSTRAP.md`

The new guide explains:

- which bootstrap script to use on macOS
- which bootstrap script to use on Linux
- what gets installed
- how to refresh the shell afterward
- which verification commands to run
- what Docker runtime model to expect per OS

### Why This Mattered

At this point the repo had:

- a macOS bootstrap script
- a Linux bootstrap script
- a runbook history of how the Mac was bootstrapped

But it still did not have one simple answer to:

```text
I’m new here. What do I run first?
```

This guide fixes that gap and makes the workstation setup story part of the root workspace contract.

### Follow-Up Work

- if we later add a Windows or WSL path, extend this guide instead of scattering setup notes across repos
