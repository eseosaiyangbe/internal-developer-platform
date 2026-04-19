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

### Why This Step Mattered

This phase established that the observability repo should be the workspace hub.

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
