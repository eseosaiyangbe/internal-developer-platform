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

## Phase 3: Control Plane Reliability Checks

### Goal

Run the `Obervability-Stack` control plane the way a new operator would, validate the actual startup and health behavior, and harden the default path so it matches the docs and our future Kubernetes direction.

### Commands

```bash
sed -n '1,260p' Obervability-Stack/docker-compose.yml
docker context ls
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker network ls --format 'table {{.Name}}\t{{.Driver}}'
echo "$PATH" && sed -n '1,220p' ~/.zprofile
ls -la ~/.local/bin ~/.docker/cli-plugins 2>/dev/null
find ~/.local ~/.docker -maxdepth 3 \( -name docker -o -name colima -o -name docker-compose -o -name limactl \) 2>/dev/null | sort
which docker colima limactl 2>/dev/null || true
export PATH="$HOME/.local/bin:$HOME/.docker/cli-plugins:$PATH"
which docker
which colima
which limactl
docker version --format '{{.Client.Version}}'
colima status
docker context ls
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker network ls --format 'table {{.Name}}\t{{.Driver}}'
docker compose -f Obervability-Stack/docker-compose.yml config
rg -n "ui-next|next|4000|3000|observability-net|external:" Obervability-Stack/docker-compose.yml Obervability-Stack/docs/README.md Obervability-Stack/README.md Obervability-Stack/ui-next/env.example
sed -n '260,520p' Obervability-Stack/docker-compose.yml
docker network inspect observability-net >/dev/null 2>&1 || docker network create observability-net
rg -n "docker compose up|--profile ui|devops-monitor-ui|localhost:4000|Quick Start|Getting Started" Obervability-Stack/README.md Obervability-Stack/docs/README.md Obervability-Stack/docs/*.md
docker compose -f Obervability-Stack/docker-compose.yml up -d
docker compose -f Obervability-Stack/docker-compose.yml ps
curl -fsS -o /dev/null -w 'PROMETHEUS %{http_code}\n' http://localhost:9090/-/healthy
curl -fsS -o /dev/null -w 'GRAFANA %{http_code}\n' http://localhost:3000/
curl -fsS -o /dev/null -w 'LOKI %{http_code}\n' http://localhost:3100/ready
curl -fsS -o /dev/null -w 'ALERTMANAGER %{http_code}\n' http://localhost:9093/-/healthy
curl -fsS -o /dev/null -w 'BLACKBOX %{http_code}\n' http://localhost:9115/-/healthy
curl -sS -o /dev/null -w 'UI %{http_code}\n' http://localhost:4000/ || true
docker compose -f Obervability-Stack/docker-compose.yml --profile ui up -d devops-monitor-ui
ls -la Obervability-Stack/ui-next/.dockerignore
du -sh Obervability-Stack/ui-next/node_modules Obervability-Stack/ui-next/.next 2>/dev/null
sed -n '1,260p' Obervability-Stack/ui-next/Dockerfile
curl -fsSL https://api.github.com/repos/docker/buildx/releases/latest | jq -r '.tag_name, (.assets[]?.browser_download_url)' | sed -n '1,20p'
```

### What We Learned

- The local Docker runtime was healthy, but the shell used for command execution was not inheriting the userland `PATH` additions from `~/.zprofile`.
- `Obervability-Stack/docker-compose.yml` was syntactically valid, but it still contained the obsolete top-level `version` field.
- The shared external network requirement is real. `observability-net` did not exist yet on this machine, so the control plane needed that network created before app-to-control-plane connectivity could work.
- A plain `docker compose up -d` successfully started the metrics stack:
  - Prometheus
  - Grafana
  - Loki
  - Alertmanager
  - Blackbox Exporter
  - Node Exporter
  - Promtail
- The default startup path did **not** start the Next.js UI, even though the docs described `http://localhost:4000` as part of the normal quick start.
- The reason was structural, not transient: `devops-monitor-ui` was behind `profiles: ["ui"]`, so it was excluded from default startup.
- Attempting to start the UI explicitly exposed a second gap:
  - the Docker bootstrap story installed the Compose plugin
  - but it did not install the `buildx` plugin
  - the UI Dockerfile depends on BuildKit features via `RUN --mount=type=cache`
- The UI build context was much larger than it should be because `ui-next` had no `.dockerignore`.
- On this machine, `ui-next/node_modules` alone was about `740M`, which is exactly the kind of local-only artifact we do not want leaking into image build contexts.

### Problems Encountered

#### 1. The shell session could not see installed Docker tooling

Problem:

- `docker`, `colima`, and `limactl` existed under `~/.local/bin`
- `docker-compose` existed under `~/.docker/cli-plugins`
- but the active command environment did not include those paths

Fix:

- exported the userland paths explicitly before runtime checks:

```bash
export PATH="$HOME/.local/bin:$HOME/.docker/cli-plugins:$PATH"
```

Why it mattered:

- without that fix, every runtime check would have looked like a missing-tool problem instead of a real control-plane validation

#### 2. The shared `observability-net` network was missing

Problem:

- the control plane expects an external Docker network named `observability-net`
- a fresh machine did not have it yet

Fix:

- created it explicitly:

```bash
docker network inspect observability-net >/dev/null 2>&1 || docker network create observability-net
```

Why it mattered:

- this is the network contract that lets the control plane see the application repos
- it also maps cleanly to the future Kubernetes mental model of shared service discovery rather than localhost-only coupling

#### 3. Default Compose startup did not include the UI

Problem:

- docs advertised `docker compose up -d` as the main quick start
- docs also advertised the UI at `http://localhost:4000`
- but `devops-monitor-ui` was behind a Compose profile and did not start by default

Fix:

- removed the `ui` profile gate from `devops-monitor-ui` so the default stack includes the UI

Why it mattered:

- the operator contract should be boring and predictable
- this fix aligns the real startup path with the docs and makes the control plane feel closer to a Kubernetes deployment where the UI is a first-class control-plane component

#### 4. UI image build failed because `buildx` was missing

Problem:

- starting the UI path triggered:

```text
Docker Compose requires buildx plugin to be installed
```

- and the build later failed with:

```text
the --mount option requires BuildKit
```

Fix:

- added Docker `buildx` plugin installation to both bootstrap scripts
- updated the workstation bootstrap guide to verify `docker buildx version`

Why it mattered:

- this was not just a one-machine quirk
- it was a real bootstrap gap that would break onboarding for anyone trying to build the control-plane UI image

#### 5. UI build context was bloated by local artifacts

Problem:

- `ui-next` had no `.dockerignore`
- Docker sent hundreds of megabytes of local build context, including `node_modules`

Fix:

- added `Obervability-Stack/ui-next/.dockerignore`
- excluded `node_modules`, `.next`, local env files, logs, coverage, and other local-only artifacts

Why it mattered:

- smaller image build contexts reduce build time and make the local-to-Kubernetes transition cleaner
- they also lower the chance of accidental environment leakage into container builds

#### 6. Compose emitted an obsolete schema warning

Problem:

- Compose warned that the top-level `version` field is obsolete

Fix:

- removed the obsolete `version` key from `Obervability-Stack/docker-compose.yml`

Why it mattered:

- it removes avoidable operator noise during startup
- it keeps the Compose file closer to the modern format we want to normalize around before translating more of this into Kubernetes

#### 7. The repo was set up to ignore its own `.dockerignore`

Problem:

- `Obervability-Stack/ui-next/.gitignore` explicitly ignored `.dockerignore`
- that meant the new Docker build hygiene file would not be tracked by Git unless it was force-added

Fix:

- removed the `.dockerignore` ignore rule from `Obervability-Stack/ui-next/.gitignore`

Why it mattered:

- this makes the faster and safer build context a normal tracked part of the repo instead of a one-machine fix

### Fixes Applied

- removed the obsolete Compose `version` field from `Obervability-Stack/docker-compose.yml`
- made `devops-monitor-ui` part of the default startup path in `Obervability-Stack/docker-compose.yml`
- added `Obervability-Stack/ui-next/.dockerignore`
- removed the conflicting `.dockerignore` ignore rule from `Obervability-Stack/ui-next/.gitignore`
- added Docker `buildx` plugin installation to:
  - `scripts/bootstrap-macos-userland.sh`
  - `scripts/bootstrap-linux-userland.sh`
- updated `WORKSTATION-BOOTSTRAP.md` to include Docker Buildx in the installed tool list and verification commands
- clarified the direct Compose path in `Obervability-Stack/docs/README.md`

### Verification

```bash
bash -n scripts/bootstrap-macos-userland.sh
bash -n scripts/bootstrap-linux-userland.sh
docker compose -f Obervability-Stack/docker-compose.yml config
docker buildx version
docker compose -f Obervability-Stack/docker-compose.yml build devops-monitor-ui
docker compose -f Obervability-Stack/docker-compose.yml up -d devops-monitor-ui
docker compose -f Obervability-Stack/docker-compose.yml ps
curl -sS -o /dev/null -w 'UI %{http_code}\n' http://localhost:4000/
```

Results:

- both bootstrap scripts passed `bash -n`
- Compose config rendered cleanly without the obsolete schema warning
- Docker now detects both plugins:
  - Compose
  - Buildx
- the `devops-monitor-ui` image built successfully with BuildKit enabled
- the final UI health check returned `200` from `http://localhost:4000/`

### Remaining Notes

- the UI image build still prints NextAuth and `DATABASE_URL` warnings during static generation when secure production env vars are not provided
- those warnings did not block the image build or local runtime startup in this pass
- they should be addressed later as part of a stricter production-env hardening slice

### Why This Step Mattered

- this is the first Phase 3 pass that exercised the real control plane instead of just reading code and docs
- it turned abstract startup assumptions into verified runtime behavior
- it removed friction that would otherwise hit every new contributor and every future Kubernetes packaging effort
- it also tightened the operator contract for the control plane so the default path behaves the way the docs say it behaves

### Follow-Up Work

- add a small control-plane smoke-check section that validates both infrastructure endpoints and the UI/API surface together
- decide whether the UI build should tolerate missing production auth/database env vars more quietly in local mode, or whether we want to keep the warnings loud

---

## Phase 3: Control Plane Smoke Check Hardening

### Goal

Replace the stale `Obervability-Stack` health path with a real control-plane smoke check that works on macOS and Linux, validates the default Compose service set, and exercises the UI and API surface together.

### Commands

```bash
sed -n '1,260p' Obervability-Stack/scripts/devops-monitor.sh
rg -n "health|smoke|status|compose up|curl|localhost:4000|devops-monitor.sh" Obervability-Stack/README.md Obervability-Stack/docs -g '!**/node_modules/**'
ls -la Obervability-Stack/scripts
sed -n '1,240p' Obervability-Stack/scripts/README.md
sed -n '1,280p' Obervability-Stack/scripts/health-check.sh
sed -n '280,520p' Obervability-Stack/scripts/health-check.sh
sed -n '220,380p' Obervability-Stack/scripts/devops-monitor.sh
bash Obervability-Stack/scripts/health-check.sh
nl -ba Obervability-Stack/scripts/health-check.sh | sed -n '1,80p'
bash -n Obervability-Stack/scripts/health-check.sh
sed -n '1,120p' Obervability-Stack/scripts/start.sh
sed -n '1,220p' Obervability-Stack/scripts/start-full-stack.sh
sed -n '1,240p' Obervability-Stack/ui-next/app/api/services/health/route.ts
curl -fsS http://localhost:4000/api/services/health | head -c 600
curl -fsS http://localhost:4000/api/apps | jq -r '.apps | length'
curl -fsS http://localhost:4000/api/apps/health | jq -r '.apps | length'
sed -n '1,220p' Obervability-Stack/ui-next/app/api/apps/health/route.ts
sed -n '1,240p' Obervability-Stack/ui-next/lib/health-api.ts
```

### What We Learned

- The repo already had a health-check script and a `devops-monitor.sh health` entrypoint, so the best path was to repair and modernize that flow instead of adding a second competing command.
- The existing `health-check.sh` was not just stale; it was broken:
  - it had a syntax error in the `SCRIPT_DIR` line
  - it assumed services like `cadvisor` and `promtail` were always directly checkable
  - it used Linux-only commands like `free`, which do not exist on macOS
- The Next.js control plane already exposes the right smoke-check APIs:
  - `/api/services/health`
  - `/api/apps`
  - `/api/apps/health`
- Those APIs are a better validation target than raw container checks alone because they prove the UI server and its backend integrations are actually functioning.

### Problems Encountered

#### 1. The legacy health script did not parse

Problem:

- `bash Obervability-Stack/scripts/health-check.sh` failed immediately
- `bash -n` confirmed a syntax error caused by a broken `SCRIPT_DIR` command substitution

Fix:

- replaced the script with a new implementation instead of patching the broken one line by line

Why it mattered:

- a runbook command that cannot even parse is worse than a missing command because it creates false confidence in the docs

#### 2. The old health model no longer matched the default Compose stack

Problem:

- the script expected `cadvisor` and `promtail` endpoints in ways that do not reflect the current default startup contract
- `cadvisor` is profile-gated
- `promtail` does not expose a public health endpoint in the current Compose setup

Fix:

- made the smoke check derive the default service set from `docker compose config --services`
- treated `cadvisor` as optional and only checked it when it is actually running
- removed the invalid `promtail` endpoint assumption from the smoke path

Why it mattered:

- this keeps the smoke check aligned with the real control-plane contract instead of a historical one

#### 3. The old resource checks were Linux-only

Problem:

- the script used `free`, which breaks on macOS

Fix:

- added cross-platform resource checks:
  - macOS memory via `vm_stat` and `sysctl`
  - Linux memory via `free`

Why it mattered:

- this project now has an explicit cross-platform bootstrap story, so the smoke checks need to honor that too

#### 4. macOS Bash does not support `mapfile`

Problem:

- the first rewrite of the smoke script used `mapfile`
- the bundled macOS Bash on this machine does not provide that builtin

Fix:

- replaced `mapfile` with a `while read` loop that works on older Bash versions

Why it mattered:

- the smoke check needs to work on the same fresh macOS setup we just bootstrapped, not only on newer Linux shells

#### 5. The documented wrapper script was not executable

Problem:

- `Obervability-Stack/scripts/devops-monitor.sh` was tracked without the executable bit
- that made documented commands like `./scripts/devops-monitor.sh health` fail with `permission denied`

Fix:

- set the executable bit on both:
  - `Obervability-Stack/scripts/devops-monitor.sh`
  - `Obervability-Stack/scripts/health-check.sh`

Why it mattered:

- docs that tell contributors to run a script directly should match the actual file mode in Git

#### 6. Grafana health validation was too strict on JSON formatting

Problem:

- the first body check looked for `"database":"ok"`
- Grafana returned valid JSON with whitespace: `"database": "ok"`

Fix:

- changed the smoke check to use a regex body match that tolerates JSON whitespace

Why it mattered:

- we want failures to indicate real service problems, not harmless response formatting differences

### Fixes Applied

- replaced `Obervability-Stack/scripts/health-check.sh` with a new control-plane smoke check
- made the new script:
  - prepend the userland Docker paths used by our workstation bootstrap
  - validate Docker access and Compose config
  - inspect the live default Compose service set
  - check public endpoints for Prometheus, Grafana, Loki, Alertmanager, Blackbox Exporter, Node Exporter, and the UI
  - verify the control-plane API layer through `/api/services/health`, `/api/apps`, and `/api/apps/health`
  - run cross-platform disk and memory checks
- updated `Obervability-Stack/scripts/devops-monitor.sh` so:
  - `health` runs the repaired smoke check via an absolute script path
  - `smoke` is available as an alias
  - startup output no longer advertises `cadvisor` as a default service
- updated:
  - `Obervability-Stack/scripts/README.md`
  - `Obervability-Stack/README.md`
  - `Obervability-Stack/docs/README.md`

### Why This Step Mattered

- it converts the control-plane verification flow from “best effort documentation” into an actual operator tool
- it checks the exact surfaces we care about before the Kubernetes migration:
  - container runtime health
  - control-plane public endpoints
  - control-plane API behavior
  - workspace app inventory visibility

### Follow-Up Work

- decide whether to add a smaller `--quick` mode later, or keep one canonical smoke path
- decide whether the macOS memory check should stay informational or evolve into a stronger thresholded check later

### Verification

```bash
chmod +x Obervability-Stack/scripts/devops-monitor.sh Obervability-Stack/scripts/health-check.sh
bash -n Obervability-Stack/scripts/health-check.sh
bash -n Obervability-Stack/scripts/devops-monitor.sh
./Obervability-Stack/scripts/health-check.sh
./Obervability-Stack/scripts/devops-monitor.sh health
curl -fsS http://localhost:3000/api/health
```

Results:

- both scripts passed `bash -n`
- both operator entrypoints completed successfully
- the smoke check passed `26/26` checks on this Mac
- Grafana confirmed the expected health payload

---

## Phase 3: Local Auth Runtime Alignment

### Goal

Fix the local `Obervability-Stack` login path so the sign-in page and the actual auth backend agree about demo access, and so database-backed local auth has a real SQLite path inside the UI container.

### Commands

```bash
sed -n '1,220p' Obervability-Stack/ui-next/lib/auth-runtime.ts
sed -n '1,220p' Obervability-Stack/ui-next/env.example
sed -n '1,240p' Obervability-Stack/docs/AUTH_ACCESS_MODEL.md
rg -n "AUTH_MODE|ENABLE_DEMO_LOGIN|NEXT_PUBLIC_AUTH_MODE|NEXT_PUBLIC_ENABLE_DEMO_LOGIN" Obervability-Stack/docker-compose.yml Obervability-Stack/ui-next/env.example Obervability-Stack/ui-next/app/auth/signin/page.tsx Obervability-Stack/ui-next/lib/auth-runtime.ts Obervability-Stack/ui-next/lib/auth.ts
sed -n '1,240p' Obervability-Stack/ui-next/app/auth/signin/page.tsx
sed -n '300,350p' Obervability-Stack/docker-compose.yml
sed -n '1,260p' Obervability-Stack/ui-next/lib/auth.ts
sed -n '1,220p' Obervability-Stack/ui-next/app/api/auth/register/route.ts
sed -n '1,220p' Obervability-Stack/ui-next/prisma/schema.prisma
sed -n '1,240p' Obervability-Stack/ui-next/lib/prisma-server.ts
cat Obervability-Stack/ui-next/package.json
docker exec devops-monitor-ui sh -lc 'pwd; ls -la; ls -la prisma 2>/dev/null || true; printenv | grep -E "AUTH_MODE|ENABLE_DEMO_LOGIN|DATABASE_URL|NEXT_PUBLIC_AUTH_MODE|NEXT_PUBLIC_ENABLE_DEMO_LOGIN|NEXTAUTH_URL|NEXTAUTH_SECRET" | sort || true'
docker exec devops-monitor-ui sh -lc 'DATABASE_URL=file:./dev.db node -e '\''const { PrismaClient } = require("@prisma/client"); const prisma = new PrismaClient(); prisma.user.count().then(async (c) => { console.log("user_count=" + c); await prisma.$disconnect(); }).catch(async (e) => { console.error(e); await prisma.$disconnect(); process.exit(1); });'\'''
curl -sS -o /tmp/register.json -w '%{http_code}\n' -X POST http://localhost:4000/api/auth/register -H 'Content-Type: application/json' -d '{"name":"Test User","email":"test.user@example.com","password":"password123"}' && cat /tmp/register.json
```

### What We Learned

- The sign-in page was accurately showing the live container build state: `database` auth mode, but demo login disabled.
- The root cause was not just runtime configuration drift:
  - `docker-compose.yml` was not passing `AUTH_MODE`, `ENABLE_DEMO_LOGIN`, `NEXT_PUBLIC_AUTH_MODE`, `NEXT_PUBLIC_ENABLE_DEMO_LOGIN`, or `DATABASE_URL`
  - the sign-in page is a client component, so the `NEXT_PUBLIC_*` values also need to be present at image build time, not just container runtime
- The UI container already includes a usable Prisma SQLite file under the app bundle, and querying it with `DATABASE_URL=file:./dev.db` returned `user_count=3`.
- Registration was failing with a `500` because the live container had no `DATABASE_URL` configured.

### Problems Encountered

#### 1. Runtime and build-time auth state were diverging

Problem:

- Next.js client code reads `NEXT_PUBLIC_*` auth flags at build time
- the auth backend reads server env at runtime
- the container had neither set correctly

Fix:

- added auth-related build args and runtime env vars for the UI image and container

Why it mattered:

- otherwise the sign-in page could keep saying “demo disabled” even after the backend started accepting demo credentials

#### 2. The local database path was missing from the container env

Problem:

- Prisma-backed registration and login were trying to start without `DATABASE_URL`

Fix:

- set the local UI container database path to `file:./dev.db`

Why it mattered:

- this aligns the container with the bundled Prisma SQLite file that already exists in the image

### Fixes Applied

- updated `Obervability-Stack/docker-compose.yml` so `devops-monitor-ui` now passes:
  - `DATABASE_URL`
  - `AUTH_MODE`
  - `ENABLE_DEMO_LOGIN`
  - `NEXT_PUBLIC_AUTH_MODE`
  - `NEXT_PUBLIC_ENABLE_DEMO_LOGIN`
- added matching build args in `Obervability-Stack/docker-compose.yml` so the Next.js client bundle sees the same auth flags at image build time
- updated `Obervability-Stack/ui-next/Dockerfile` so the builder and runner stages both receive the local auth/runtime values needed for the Dockerized local path

### Verification

```bash
docker compose -f Obervability-Stack/docker-compose.yml build devops-monitor-ui
docker compose -f Obervability-Stack/docker-compose.yml up -d devops-monitor-ui
docker compose -f Obervability-Stack/docker-compose.yml config | rg -n "DATABASE_URL|AUTH_MODE|ENABLE_DEMO_LOGIN|NEXT_PUBLIC_AUTH_MODE|NEXT_PUBLIC_ENABLE_DEMO_LOGIN"
docker exec devops-monitor-ui sh -lc 'printenv | grep -E "AUTH_MODE|ENABLE_DEMO_LOGIN|DATABASE_URL|NEXT_PUBLIC_AUTH_MODE|NEXT_PUBLIC_ENABLE_DEMO_LOGIN|NEXTAUTH_URL|NEXTAUTH_SECRET" | sort'
curl -sS -o /tmp/register2.json -w '%{http_code}\n' -X POST http://localhost:4000/api/auth/register -H 'Content-Type: application/json' -d '{"name":"Test User","email":"test.user@example.com","password":"password123"}' && cat /tmp/register2.json
```

Additional verification:

- queried the bundled Prisma SQLite database inside the running container with `DATABASE_URL=file:./dev.db` and confirmed it already contained users
- completed a credentials callback flow for:
  - `demo@example.com` / `demo123`
  - `test.user@example.com` / `password123`
- both returned a dashboard redirect URL and a `next-auth.session-token` cookie, confirming successful login

Results:

- the UI container now has the correct auth env vars at runtime
- database-backed registration returned `201`
- demo login works
- database-backed local login works

### Follow-Up Work

- reduce the Docker build warnings about using `ARG`/`ENV` for auth-related values by splitting true secrets from non-secret local build flags more cleanly later

---

## Phase 3: Inventory Validation Automation

### Goal

Turn the monitored app inventory contract into a runnable validation command so Phase 3 inventory integrity is not only documented but also executable.

### Commands

```bash
sed -n '1,360p' Obervability-Stack/ui-next/lib/monitored-apps.ts
sed -n '1,220p' Obervability-Stack/docs/WORKSPACE_APP_INVENTORY_AUDIT.md
ls -la Obervability-Stack/scripts
ls -la Obervability-Stack/ui-next
find Obervability-Stack/ui-next -maxdepth 2 -type d | sort | sed -n '1,120p'
test -x Obervability-Stack/ui-next/node_modules/.bin/tsx && echo yes || echo no
```

### What We Learned

- the control plane already had good inventory documentation, but no first-class command to validate whether the monitored app model stayed internally consistent
- `ui-next/lib/monitored-apps.ts` is the strongest source of truth for this check because it contains app IDs, endpoint metadata, runbooks, docker aliases, and Kubernetes metadata in one place
- the local repo already has the `tsx` runtime available inside `ui-next/node_modules/.bin/tsx`, so we can add a typed validator without inventing another global dependency

### Fixes Applied

- added `Obervability-Stack/ui-next/scripts/validate-monitored-apps.ts`
- added `Obervability-Stack/scripts/inventory-audit.sh`
- updated `Obervability-Stack/scripts/devops-monitor.sh` with an `inventory` command
- updated:
  - `Obervability-Stack/scripts/README.md`
  - `Obervability-Stack/README.md`
  - `Obervability-Stack/docs/README.md`
  - `Obervability-Stack/docs/WORKSPACE_APP_INVENTORY_AUDIT.md`
  - `PROJECT-ROADMAP.md`

### Why This Step Mattered

- it turns inventory integrity into a repeatable operator command
- it reduces the risk of Phase 4 onboarding work drifting away from the control-plane model
- it also strengthens the later Kubernetes migration path, because service metadata mistakes can be caught before we start translating more of the platform into cluster resources

### Follow-Up Work

- decide whether inventory validation should eventually be folded into the broader smoke-check path or stay as its own explicit control-plane command

---

## Phase 4 Bridge: SwiftPay Onboarding Audit

### Goal

Start the first real app-onboarding bridge by turning `SwiftPay`'s control-plane integration contract into a runnable audit.

### Commands

```bash
sed -n '1,260p' SwiftPay/docker-compose.yml
sed -n '1,260p' Obervability-Stack/prometheus/prometheus.yml
sed -n '1,260p' Obervability-Stack/ui-next/app/api/apps/swiftpay/business/route.ts
rg -n "swiftpay|business metrics|queue|wallet|transaction|api-gateway|auth-service|notification-service" Obervability-Stack/ui-next/lib Obervability-Stack/ui-next/app -g '!**/node_modules/**'
rg -n "swiftpay:pending_transactions|swiftpay:pending_amount|swiftpay:transaction_queue_depth|swiftpay:transaction_failure_rate_5m|swiftpay:wallet_failed_transfer_rate_5m|swiftpay:wallet_circuit_breaker_state|pending_transactions|queue_depth|circuit_breaker" SwiftPay Obervability-Stack -g '!**/node_modules/**'
rg -n "swiftpay-frontend|swiftpay-api-gateway|swiftpay-auth-service|swiftpay-wallet-service|swiftpay-transaction-service|swiftpay-notification-service" SwiftPay/docker-compose.yml SwiftPay/docs Obervability-Stack/prometheus/prometheus.yml Obervability-Stack/ui-next/lib/monitored-apps.ts -g '!**/node_modules/**'
sed -n '1,260p' Obervability-Stack/prometheus/recording_rules.yml
```

### What We Learned

- `SwiftPay` is already the deepest app integration in the control plane, so it is the right place to start Phase 4 bridge work.
- The integration contract currently spans several files:
  - `SwiftPay/docker-compose.yml`
  - `Obervability-Stack/ui-next/lib/monitored-apps.ts`
  - `Obervability-Stack/prometheus/prometheus.yml`
  - `Obervability-Stack/prometheus/recording_rules.yml`
  - `Obervability-Stack/ui-next/app/api/apps/swiftpay/business/route.ts`
  - `SwiftPay/docs/observability-runbook.md`
- That makes it easy for drift to creep in unless we validate the whole chain together.

### Fixes Applied

- added `Obervability-Stack/scripts/swiftpay-audit.sh`
- updated `Obervability-Stack/scripts/devops-monitor.sh` with a `swiftpay` command
- updated:
  - `Obervability-Stack/scripts/README.md`
  - `Obervability-Stack/README.md`
  - `Obervability-Stack/docs/README.md`
  - `PROJECT-ROADMAP.md`

### Why This Step Mattered

- it gives the flagship workload a real onboarding audit instead of relying on scattered human checks
- it creates a pattern we can later adapt for `OpenSIS`, `FoodPulse`, and `MemFlip`
- it moves the roadmap forward without skipping the reliability discipline we want before Kubernetes

### Follow-Up Work

- decide whether the next Phase 4 slice should validate live SwiftPay metrics end to end or extend the same audit pattern to another app

### Verification

```bash
chmod +x Obervability-Stack/scripts/swiftpay-audit.sh
bash -n Obervability-Stack/scripts/swiftpay-audit.sh
bash -n Obervability-Stack/scripts/devops-monitor.sh
./Obervability-Stack/scripts/swiftpay-audit.sh
./Obervability-Stack/scripts/devops-monitor.sh swiftpay
```

Results:

- both entrypoints completed successfully
- the SwiftPay audit passed with:
  - `Checks passed: 52/52`
  - `Failures: 0`

### Verification

```bash
chmod +x Obervability-Stack/scripts/inventory-audit.sh
bash -n Obervability-Stack/scripts/inventory-audit.sh
bash -n Obervability-Stack/scripts/devops-monitor.sh
./Obervability-Stack/scripts/inventory-audit.sh
./Obervability-Stack/scripts/devops-monitor.sh inventory
```

Results:

- the inventory wrapper script passed `bash -n`
- both entrypoints completed successfully
- the inventory validator passed with:
  - `Apps checked: 4`
  - `Errors: 0`
  - `Warnings: 0`

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

---

## Phase 3: Control Plane Auth Hardening

### Goal

Move the control plane away from a pure hardcoded-demo auth posture and make database-backed auth the primary path, while keeping demo access as an explicit mode or fallback.

### Commands

```bash
sed -n '1,260p' Obervability-Stack/ui-next/lib/auth-simple.ts
sed -n '1,260p' Obervability-Stack/ui-next/prisma/schema.prisma
rg -n "demo@example.com|demo123|auth-simple|NEXTAUTH|prisma|login|credentials|demo users|production" Obervability-Stack/ui-next Obervability-Stack/docs Obervability-Stack/README.md -g '!**/node_modules/**' | sed -n '1,260p'
sed -n '1,280p' Obervability-Stack/ui-next/lib/auth.ts
sed -n '1,260p' Obervability-Stack/ui-next/lib/prisma-server.ts
sed -n '1,260p' Obervability-Stack/ui-next/prisma/seed.ts
sed -n '1,220p' Obervability-Stack/ui-next/app/api/auth/register/route.ts
sed -n '1,220p' Obervability-Stack/ui-next/env.example
sed -n '1,220p' Obervability-Stack/ui-next/app/page.tsx
sed -n '1,220p' Obervability-Stack/ui-next/app/layout.tsx
sed -n '1,260p' 'Obervability-Stack/ui-next/app/api/auth/[...nextauth]/route.ts'
sed -n '1,320p' Obervability-Stack/ui-next/app/auth/signin/page.tsx
sed -n '1,260p' Obervability-Stack/ui-next/app/auth/signup/page.tsx
sed -n '1,220p' Obervability-Stack/ui-next/lib/auth-config-check.ts
rg -n "@/lib/auth-simple|from \\\"@/lib/auth\\\"|from '@/lib/auth'" Obervability-Stack/ui-next -g '!**/node_modules/**' | sed -n '1,220p'
sed -n '1,260p' Obervability-Stack/docs/PRODUCTION_SETUP.md
sed -n '1,260p' Obervability-Stack/docs/AUTHENTICATION_MULTI_TENANCY_GUIDE.md
npm ci
npm run type-check
git add Obervability-Stack/ui-next/lib/auth-runtime.ts Obervability-Stack/docs/AUTH_ACCESS_MODEL.md Obervability-Stack/ui-next/lib/auth.ts Obervability-Stack/ui-next/lib/auth-simple.ts Obervability-Stack/ui-next/app/page.tsx Obervability-Stack/ui-next/app/layout.tsx 'Obervability-Stack/ui-next/app/api/auth/[...nextauth]/route.ts' Obervability-Stack/ui-next/app/api/auth/register/route.ts Obervability-Stack/ui-next/app/auth/signin/page.tsx Obervability-Stack/ui-next/app/auth/signup/page.tsx Obervability-Stack/ui-next/env.example Obervability-Stack/docs/README.md Obervability-Stack/docs/PRODUCTION_SETUP.md PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md
git commit -m "Harden control plane auth model"
git push origin main
```

### Problems Encountered

#### 1. The active auth path was not the strongest auth path in the repo

Problem:

- the app was still wired to `auth-simple.ts`
- `auth-simple.ts` only supported hardcoded demo credentials
- a stronger Prisma-backed auth path already existed in `auth.ts`, but it was not the active runtime path

Why it mattered:

- this kept the control plane in a prototype-grade auth posture
- it also created duplication and ambiguity about which auth path was real

#### 2. Validation was blocked at first by missing local dependencies

Problem:

- `npm run type-check` initially failed because `ui-next/node_modules` was not installed and `tsc` was missing

Why it mattered:

- this was a tooling gap, not an application-code failure
- it meant we needed to install the app dependencies before trusting type-check results

#### 3. TypeScript caught a real provider-array typing issue

Problem:

- after dependencies were installed, `tsc` failed because the providers array was inferred too narrowly around the credentials provider shape

Why it mattered:

- this was a real code-level issue introduced during hardening
- it was exactly the sort of issue we wanted type-check to catch before commit

### What We Changed

#### 1. Promoted the stronger auth model into the active path

- wired the app entrypoints to `ui-next/lib/auth.ts`
- converted `ui-next/lib/auth-simple.ts` into a compatibility shim that re-exports from `auth.ts`

#### 2. Added explicit auth runtime controls

- created `ui-next/lib/auth-runtime.ts`
- introduced:
  - `AUTH_MODE`
  - `ENABLE_DEMO_LOGIN`
  - `NEXT_PUBLIC_AUTH_MODE`
  - `NEXT_PUBLIC_ENABLE_DEMO_LOGIN`

#### 3. Made auth behavior explicit instead of accidental

- defaulted to database-backed auth
- kept demo login as an explicit mode or fallback
- enabled OAuth providers only when their credentials are actually configured
- made registration create real Prisma-backed users in database mode
- kept registration disabled in demo mode

#### 4. Reconciled auth docs with the new runtime model

- added `Obervability-Stack/docs/AUTH_ACCESS_MODEL.md`
- updated the control-plane docs index
- updated `PRODUCTION_SETUP.md`
- updated the roadmap to reflect that auth hardening has started inside Phase 3

### Verification

```bash
cd Obervability-Stack/ui-next
npm ci
npm run type-check
```

Result:

- `npm ci` completed successfully
- `npm run type-check` completed successfully after fixing the provider-array typing

### Why This Step Mattered

- it turned auth from a demo-only assumption into a deliberate runtime model
- it reduced ambiguity inside the control plane codebase
- it moved the hub repo closer to a real operator posture without giving up local demo convenience

### Follow-Up Work

- reconcile deeper auth and multi-tenancy docs that still describe a more aspirational architecture than the current runtime
- decide whether to surface auth mode more clearly inside the UI itself
- continue Phase 3 documentation reconciliation in the control plane

---

## Phase 3: Auth UX And Guide Reconciliation

### Goal

Make the sign-in experience and the older authentication guide reflect the control-plane auth runtime we just hardened, instead of leaving the UI and docs in an aspirational or ambiguous state.

### Commands

```bash
sed -n '1,260p' Obervability-Stack/docs/AUTHENTICATION_MULTI_TENANCY_GUIDE.md
sed -n '260,560p' Obervability-Stack/docs/AUTHENTICATION_MULTI_TENANCY_GUIDE.md
sed -n '1,260p' Obervability-Stack/ui-next/app/auth/signin/page.tsx
sed -n '1,220p' Obervability-Stack/docs/AUTH_ACCESS_MODEL.md
npm run type-check
git add Obervability-Stack/docs/AUTHENTICATION_MULTI_TENANCY_GUIDE.md Obervability-Stack/ui-next/app/auth/signin/page.tsx JOURNEY-RUNBOOK.md
git commit -m "Align auth docs and sign-in UX"
git push origin main
```

### What We Changed

#### 1. Surfaced auth runtime state in the sign-in UI

- added visible auth-mode and demo-login status badges to the sign-in page
- added an operator-mode message for environments where demo login is disabled

#### 2. Reconciled the older auth guide with the current runtime

- added a "Current Runtime Note" to `AUTHENTICATION_MULTI_TENANCY_GUIDE.md`
- pointed readers to the new auth access model and live runtime files
- corrected stale assumptions around:
  - unconditional OAuth availability
  - unconditional demo credentials
  - the old `NEXTAUTH_URL` port
  - the older "fully implemented" tone for broader multi-tenancy ideas

### Verification

```bash
cd Obervability-Stack/ui-next
npm run type-check
```

Result:

- type-check completed successfully

### Why This Step Mattered

- it reduced the gap between what operators read, what they see, and what the control plane actually does
- it turned auth mode from an environment-variable detail into an explicit part of the operator experience
- it kept Phase 3 focused on trustworthiness, not just code changes

### Follow-Up Work

- continue reconciling deeper control-plane docs that still carry older assumptions
- decide whether to expose auth/runtime status elsewhere in the UI beyond sign-in
- move into control-plane reliability checks after the remaining doc drift is reduced

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

---

## Phase 14: SwiftPay Live Control-Plane Audit

### Goal

Move beyond static SwiftPay onboarding checks and prove that the control plane can observe a real end-to-end SwiftPay transaction flow while the stack is live.

### Commands

```bash
docker compose -f SwiftPay/docker-compose.yml ps
curl http://localhost:4000/api/apps/swiftpay/business | jq .
curl http://localhost:4000/api/apps/health | jq '.summary, (.apps[] | select(.id=="swiftpay"))'
sed -n '260,460p' SwiftPay/docker-compose.yml
sed -n '1,220p' SwiftPay/docs/observability-runbook.md
docker network inspect observability-net >/dev/null 2>&1 || docker network create observability-net
sed -n '1,260p' Obervability-Stack/ui-next/lib/app-observability.ts
docker compose -f SwiftPay/docker-compose.yml up -d
source ~/.zprofile >/dev/null 2>&1; which docker && docker compose -f SwiftPay/docker-compose.yml ps
curl -fsS http://localhost:3007/health
curl -fsSI http://localhost:8081
curl -fsS http://localhost:4000/api/apps/health
curl -fsS http://localhost:4000/api/apps/swiftpay/business
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=up{job=~"swiftpay-.+"}'
rg -n "app_business|pendingTransactions|queueDepth|circuitBreaker|register|login|transfer|wallet" SwiftPay/services -g '!*node_modules*'
sed -n '1,240p' Obervability-Stack/ui-next/app/api/apps/swiftpay/business/route.ts
curl -fsS http://localhost:3007/metrics | rg 'swiftpay|transaction|wallet|queue|circuit|failure|pending'
curl -fsS http://localhost:3008/metrics | rg 'swiftpay|transaction|wallet|queue|circuit|failure|pending'
rg -n "APIClient|register\\(|login\\(|createTransaction|/api/transactions|fromUserId|toUserId|amount" SwiftPay/services/frontend/src
sed -n '1,260p' SwiftPay/services/frontend/src/App.js
rg -n "authenticate|Authorization|Bearer|token" SwiftPay/services/frontend/src
sed -n '1,340p' SwiftPay/services/frontend/src/lib/api-client.js
curl -fsS http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name|test("swiftpay";"i"))'
set -euo pipefail
TS=$(date +%s)
EMAIL1="live.audit.$TS.a@example.com"
EMAIL2="live.audit.$TS.b@example.com"
PASS='Password123!'
NAME1='Live Audit A'
NAME2='Live Audit B'
RESP1=$(curl -fsS -X POST http://localhost:3007/api/auth/register -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL1\",\"password\":\"$PASS\",\"name\":\"$NAME1\"}")
RESP2=$(curl -fsS -X POST http://localhost:3007/api/auth/register -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL2\",\"password\":\"$PASS\",\"name\":\"$NAME2\"}")
TOKEN1=$(printf '%s' "$RESP1" | jq -r '.accessToken')
USER1=$(printf '%s' "$RESP1" | jq -r '.user.id // .userId')
USER2=$(printf '%s' "$RESP2" | jq -r '.user.id // .userId')
WALLETS=$(curl -fsS http://localhost:3007/api/wallets -H "Authorization: Bearer $TOKEN1")
TXN=$(curl -fsS -X POST http://localhost:3007/api/transactions -H "Authorization: Bearer $TOKEN1" -H 'Content-Type: application/json' -H "Idempotency-Key: live-audit-$TS" -d "{\"fromUserId\":\"$USER1\",\"toUserId\":\"$USER2\",\"amount\":25.5}")
sleep 5
WALLET1=$(curl -fsS http://localhost:3007/api/wallets/$USER1 -H "Authorization: Bearer $TOKEN1")
TXNS=$(curl -fsS "http://localhost:3007/api/transactions?userId=$USER1" -H "Authorization: Bearer $TOKEN1")
BUSINESS=$(curl -fsS http://localhost:4000/api/apps/swiftpay/business)
PROM_Q1=$(curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=swiftpay:transaction_queue_depth')
PROM_Q2=$(curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=swiftpay_transaction_volume_dollars_total')
PROM_Q3=$(curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=transactions_total{job="swiftpay-transaction-service"}')
bash -n Obervability-Stack/scripts/swiftpay-live-audit.sh
chmod +x Obervability-Stack/scripts/swiftpay-live-audit.sh
./Obervability-Stack/scripts/swiftpay-live-audit.sh
./Obervability-Stack/scripts/devops-monitor.sh swiftpay-live
```

### What We Learned

- `SwiftPay` was not running at the start of this slice, so the control plane correctly marked it down while still returning zero-valued business metrics from recording rules that use `or vector(0)` fallbacks.
- Once `SwiftPay` was started, the control plane immediately saw it as healthy through `/api/apps/health`, and Prometheus reported all five SwiftPay metrics jobs as `up`.
- A real end-to-end transaction through the public gateway worked:
  - user registration succeeded
  - the gateway created wallets for the new users
  - the transfer entered the queue as `PENDING`
  - the transaction completed asynchronously
  - the sender wallet balance dropped from `1000.00` to `974.50`
- The control-plane SwiftPay business endpoint can still show all zeros after a successful transfer, and that turned out to be expected for a healthy path.

### Problems Encountered

#### 1. `docker` was not visible in one command-execution path

Problem:

- one shell invocation reported `zsh:1: command not found: docker`
- this was not a real machine-level Docker failure
- it was a command-environment issue where the userland tool path from `~/.zprofile` was not loaded

Fix:

- re-ran the Docker-dependent check with:

```bash
source ~/.zprofile >/dev/null 2>&1
```

Why it mattered:

- we needed to distinguish a shell-path problem from an actual control-plane or SwiftPay runtime problem

#### 2. The first business-metrics reading looked misleading

Problem:

- `/api/apps/swiftpay/business` returned zeros before and after the successful transfer
- at first glance that looked like a broken control-plane query path

What we found:

- the business endpoint in `Obervability-Stack/ui-next/app/api/apps/swiftpay/business/route.ts` only reports:
  - pending transaction count
  - pending amount
  - queue depth
  - transaction failure rate
  - wallet failure rate
  - wallet circuit-breaker state
- those metrics legitimately return `0` on a healthy happy-path transfer when nothing is stuck, failing, or tripping a breaker

Fix:

- documented this behavior explicitly
- encoded it into a new live audit so operators do not misread healthy zero values as broken instrumentation

Why it mattered:

- this is exactly the kind of subtle observability misunderstanding that creates false alarms later

#### 3. The static onboarding audit was not enough

Problem:

- `Obervability-Stack/scripts/swiftpay-audit.sh` validated config contracts only
- it did not prove that a live transfer path worked through the real stack

Fix:

- added `Obervability-Stack/scripts/swiftpay-live-audit.sh`
- wired it into `Obervability-Stack/scripts/devops-monitor.sh` as:

```bash
./scripts/devops-monitor.sh swiftpay-live
```

Why it mattered:

- Phase 3 is about making the control plane trustworthy
- that means proving live operator behavior, not just static file alignment

### What We Changed

- added `Obervability-Stack/scripts/swiftpay-live-audit.sh`
- updated `Obervability-Stack/scripts/devops-monitor.sh` with a `swiftpay-live` command
- updated:
  - `Obervability-Stack/scripts/README.md`
  - `Obervability-Stack/README.md`
  - `Obervability-Stack/docs/README.md`
  - `PROJECT-ROADMAP.md`
  - `JOURNEY-RUNBOOK.md`

### Validation

Validated successfully:

- `bash -n Obervability-Stack/scripts/swiftpay-live-audit.sh`
- `./Obervability-Stack/scripts/swiftpay-live-audit.sh`
- `./Obervability-Stack/scripts/devops-monitor.sh swiftpay-live`

### Why This Mattered

This step closes an important gap between:

- "the config says SwiftPay is onboarded"
- and "an operator can prove SwiftPay really works through the live control plane"

That is a much stronger Phase 3 outcome, and it sets us up to move into broader app integration work with less ambiguity.

### Follow-Up Work

- decide whether the SwiftPay business panel should later include one success-oriented metric so healthy activity is more visually obvious
- use the same live-audit pattern for the next onboarded workload instead of relying on config-only checks

---

## Phase 15: SwiftPay Success Signal

### Goal

Add one positive SwiftPay business signal so a healthy successful transfer is visible in the control plane instead of reading like "all zeros".

### Commands

```bash
rg -n "swiftpay:pending_transactions|swiftpay:pending_amount|swiftpay:transaction_queue_depth|wallet_circuit_breaker_state|transactionFailureRate|pendingTransactions|business" Obervability-Stack/prometheus Obervability-Stack/ui-next -g '!**/node_modules/**'
sed -n '1,220p' Obervability-Stack/prometheus/recording_rules.yml
sed -n '1,220p' Obervability-Stack/ui-next/app/api/apps/swiftpay/business/route.ts
sed -n '1,180p' Obervability-Stack/ui-next/lib/hooks/use-swiftpay-business-metrics.ts
sed -n '410,450p' Obervability-Stack/ui-next/app/dashboard/page.tsx
sed -n '560,630p' Obervability-Stack/ui-next/app/dashboard/page.tsx
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=transactions_total{job="swiftpay-transaction-service",service="transaction-service",status="completed",type="transfer"}' | jq .
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=swiftpay_transaction_volume_dollars_total{job="swiftpay-transaction-service"}' | jq .
curl -fsS http://localhost:3008/metrics | rg 'swiftpay_transaction_volume_dollars_total|transactions_total\\{|swiftpay_average_transaction_size_dollars'
rg -n "swiftpay:pending_transactions|swiftpay:pending_amount|swiftpay:transaction_queue_depth|swiftpay:transaction_failure_rate_5m|swiftpay:wallet_failed_transfer_rate_5m|swiftpay:wallet_circuit_breaker_state" SwiftPay/docs/observability-runbook.md Obervability-Stack/scripts/swiftpay-audit.sh JOURNEY-RUNBOOK.md -g '!**/node_modules/**'
sed -n '1,220p' SwiftPay/docs/observability-runbook.md
bash -n Obervability-Stack/scripts/swiftpay-audit.sh
bash -n Obervability-Stack/scripts/swiftpay-live-audit.sh
npm run type-check
docker compose -f Obervability-Stack/docker-compose.yml exec -T prometheus promtool check rules /etc/prometheus/recording_rules.yml
docker compose -f Obervability-Stack/docker-compose.yml exec -T prometheus wget -qO- --post-data='' http://localhost:9090/-/reload
curl -fsS http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name=="swiftpay_recording_rules") | .rules[] | select(.name=="swiftpay:completed_transfers_total")'
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=transactions_total{job="swiftpay-transaction-service",service="transaction-service",status="completed",type="transfer"}' | jq .
docker compose -f Obervability-Stack/docker-compose.yml up -d --build devops-monitor-ui
docker compose -f Obervability-Stack/docker-compose.yml ps devops-monitor-ui
curl -fsS http://localhost:4000/api/apps/swiftpay/business | jq .
./Obervability-Stack/scripts/swiftpay-audit.sh
./Obervability-Stack/scripts/swiftpay-live-audit.sh
```

### What We Learned

- The most reliable positive signal already present in the live SwiftPay stack is the completed transfer counter:

```text
transactions_total{job="swiftpay-transaction-service",service="transaction-service",status="completed",type="transfer"}
```

- The more ambitious transaction-volume counter was not yet emitting samples in the live stack, so it was not the right choice for an operator-facing dashboard card.
- Adding `swiftpay:completed_transfers_total` gives the dashboard an obvious healthy-activity signal without changing the meaning of the existing pending, failure, queue, or circuit-breaker metrics.
- After rebuilding the UI and reloading Prometheus, the running business API returned:

```json
{
  "app": "swiftpay",
  "metrics": {
    "pendingTransactions": 0,
    "pendingAmount": 0,
    "queueDepth": 0,
    "completedTransfersTotal": 3,
    "transactionFailureRate": 0,
    "walletFailureRate": 0,
    "walletCircuitBreakerState": 0
  }
}
```

That is a much clearer operator experience because the panel now shows both:

- a healthy path with no backlog or failure
- proof that real successful transfers have happened

### Problems Encountered

#### 1. TypeScript caught an existing safety gap in the inventory validator

Problem:

- `npm run type-check` failed with:

```text
scripts/validate-monitored-apps.ts(164,9): error TS18048: 'endpoint.kubernetes' is possibly 'undefined'.
```

Fix:

- changed the namespace comparison to use optional chaining:

```ts
endpoint.kubernetes?.namespace
```

Why it mattered:

- this was not part of the new SwiftPay metric directly
- but Phase 3 is about trustworthiness, and leaving the type-check red would weaken that

#### 2. The rebuilt UI API was hit too early once

Problem:

- right after `docker compose up -d --build devops-monitor-ui`, the first immediate `curl` returned:

```text
curl: (52) Empty reply from server
```

Fix:

- waited for `devops-monitor-ui` to report healthy
- then re-ran the API checks

Why it mattered:

- this was just startup timing, not a broken build
- recording that distinction keeps the runbook honest for the next operator

### What We Changed

- added `swiftpay:completed_transfers_total` to `Obervability-Stack/prometheus/recording_rules.yml`
- exposed `completedTransfersTotal` in:
  - `Obervability-Stack/ui-next/app/api/apps/swiftpay/business/route.ts`
  - `Obervability-Stack/ui-next/lib/hooks/use-swiftpay-business-metrics.ts`
- added a `Completed Transfers` card to:
  - `Obervability-Stack/ui-next/app/dashboard/page.tsx`
- updated:
  - `Obervability-Stack/scripts/swiftpay-audit.sh`
  - `Obervability-Stack/scripts/swiftpay-live-audit.sh`
  - `SwiftPay/docs/observability-runbook.md`
- fixed a TypeScript safety issue in:
  - `Obervability-Stack/ui-next/scripts/validate-monitored-apps.ts`

### Validation

Validated successfully:

- `bash -n Obervability-Stack/scripts/swiftpay-audit.sh`
- `bash -n Obervability-Stack/scripts/swiftpay-live-audit.sh`
- `npm run type-check`
- `docker compose -f Obervability-Stack/docker-compose.yml exec -T prometheus promtool check rules /etc/prometheus/recording_rules.yml`
- `./Obervability-Stack/scripts/swiftpay-audit.sh`
- `./Obervability-Stack/scripts/swiftpay-live-audit.sh`
- live API response from `http://localhost:4000/api/apps/swiftpay/business`

### Why This Mattered

This change makes the SwiftPay control-plane view more truthful.

Before:

- a perfectly healthy successful transfer could still make the business panel look inert

After:

- operators can see the absence of backlog and failures
- and they can also see clear evidence of successful business activity

That is a better Phase 3 control-plane experience and gives us a cleaner pattern for other onboarded workloads later.

---

## Phase 16: MemFlip Static And Live Audits

### Goal

Extend the control-plane audit pattern from `SwiftPay` to a second workload by making `MemFlip` runnable, coexistent, and verifiable through both static and live audits.

### Commands

```bash
rg -n "memflip" Obervability-Stack/ui-next/lib/monitored-apps.ts Obervability-Stack/prometheus/prometheus.yml Obervability-Stack/prometheus/recording_rules.yml Obervability-Stack/scripts Obervability-Stack/README.md Obervability-Stack/docs/README.md PROJECT-ROADMAP.md -g '!**/node_modules/**'
sed -n '1,220p' MemFlip/docker-compose.yml
rg -n "health|metrics|leaderboard|score|game|/api" MemFlip/backend MemFlip/frontend/src MemFlip/docs MemFlip/README.md -g '!**/node_modules/**'
docker compose -f MemFlip/docker-compose.yml ps
sed -n '1,240p' MemFlip/backend/server.js
sed -n '1,260p' MemFlip/backend/routes/game.js
sed -n '1,260p' MemFlip/backend/routes/leaderboard.js
sed -n '1,260p' MemFlip/backend/routes/scores.js
sed -n '1,280p' MemFlip/frontend/src/scripts/game.js
sed -n '1,280p' MemFlip/backend/middleware/metrics.js
docker network inspect observability-net >/dev/null 2>&1 || docker network create observability-net
docker compose -f MemFlip/docker-compose.yml up -d
docker compose -f MemFlip/docker-compose.yml ps
curl -fsS http://localhost:8080/api/health
curl -fsS http://localhost:3101/health
curl -fsSI http://localhost:8080
curl -fsS http://localhost:4000/api/apps/health | jq '.summary, (.apps[] | select(.appId=="memflip"))'
curl -fsS http://localhost:3101/metrics | rg 'game_scores_total|active_games_current|http_requests_total|app_health_status'
curl -fsS 'http://localhost:9115/probe?target=http://memflip-frontend/api/health&module=http_2xx'
docker logs --tail=100 humor-game-frontend
docker inspect humor-game-frontend --format '{{json .NetworkSettings.Networks}}'
curl -fsS http://localhost:4000/api/apps/health | jq '(.apps[] | select(.appId=="memflip"))'
rg -n "localhost:3001|:3001|API_PORT|FRONTEND_HOST_PORT|backend port|8080" MemFlip/README.md MemFlip/docs/local MemFlip/.env.example WORKSPACE-SETUP-MATRIX.md WORKSPACE-ARCHITECTURE.md -g '!**/node_modules/**'
sed -n '146,165p' MemFlip/README.md
sed -n '1,220p' MemFlip/.env.example
docker compose -f MemFlip/docker-compose.yml up -d --build backend
curl -fsS -X POST http://localhost:8080/api/scores/user -H 'Content-Type: application/json' -d '{"username":"memflipaudit..."}'
curl -fsS -X POST http://localhost:8080/api/game/start -H 'Content-Type: application/json' -d '{"username":"memflipaudit...","difficulty":"easy"}'
curl -fsS -X POST http://localhost:8080/api/game/match -H 'Content-Type: application/json' -d '{"gameId":"...","card1Id":"...","card2Id":"...","matchTime":1000}'
curl -fsS -X POST http://localhost:8080/api/game/complete -H 'Content-Type: application/json' -d '{"gameId":"...","timeElapsed":60000,"finalScore":0}'
curl -fsS http://localhost:8080/api/leaderboard
curl -fsS http://localhost:8080/api/scores/memflipaudit...
curl -fsS http://localhost:3101/metrics | rg 'http_requests_total|game_scores_total|active_games_current'
docker logs --tail=120 humor-game-backend
sed -n '340,420p' MemFlip/backend/middleware/metrics.js
sed -n '1,80p' MemFlip/backend/package.json
chmod +x Obervability-Stack/scripts/memflip-audit.sh Obervability-Stack/scripts/memflip-live-audit.sh
bash -n Obervability-Stack/scripts/memflip-audit.sh
bash -n Obervability-Stack/scripts/memflip-live-audit.sh
bash -n Obervability-Stack/scripts/devops-monitor.sh
./Obervability-Stack/scripts/memflip-audit.sh
./Obervability-Stack/scripts/memflip-live-audit.sh
./Obervability-Stack/scripts/devops-monitor.sh memflip-live
```

### What We Learned

- `MemFlip` already had the right shape for onboarding:
  - frontend proxy health at `http://localhost:8080/api/health`
  - backend health at `http://localhost:3101/health`
  - a real game flow through `/api/game/start`, `/api/game/match`, and `/api/game/complete`
  - a backend metrics endpoint at `/metrics`
- The control plane already knew how to blackbox-probe the `MemFlip` frontend and backend through:
  - `http://memflip-frontend/api/health`
  - `http://memflip-backend:3001/health`
- Once the app was stable, `Obervability-Stack` correctly reported `MemFlip` as healthy.
- A complete synthetic game flow works through the frontend proxy:
  - create user
  - start game
  - derive a valid matching pair from returned cards
  - submit a successful match
  - complete the game
  - fetch leaderboard and user stats
- After the backend fixes, the metrics endpoint recorded:
  - request counters for `/start`, `/match`, and `/complete`
  - a `game_scores_total` sample for the synthetic completed game

### Problems Encountered

#### 1. `MemFlip` collided with `SwiftPay` on host port `3001`

Problem:

- `MemFlip` published its backend on host port `3001`
- `SwiftPay` already used `3001` for the wallet service
- starting both locally caused:

```text
Bind for 0.0.0.0:3001 failed: port is already allocated
```

Fix:

- changed the published MemFlip backend port to:

```text
${BACKEND_HOST_PORT:-3101}:3001
```

- updated:
  - `MemFlip/.env.example`
  - `MemFlip/README.md`
  - `WORKSPACE-SETUP-MATRIX.md`

Why it mattered:

- this is exactly the kind of local coexistence issue that breaks a multi-app platform story
- fixing it now keeps the workspace usable as a shared lab instead of a one-app-at-a-time setup

#### 2. MemFlip backend metrics code was wired incorrectly

Problem:

- the game routes called `updateGameMetrics`
- but `MemFlip/backend/routes/game.js` did not import it
- backend logs showed:

```text
updateGameMetrics is not defined
```

Fix:

- imported `updateGameMetrics` from `../middleware/metrics`
- also reset active-game gauge to `0` when the synthetic game completes

Why it mattered:

- without that fix, the live audit could prove the user flow but not the metrics flow
- Phase 3 is about trust in the control plane and supporting app instrumentation

#### 3. Express rate limiting complained about the frontend proxy

Problem:

- the backend runs behind nginx in the local Compose path
- backend logs showed:

```text
ERR_ERL_UNEXPECTED_X_FORWARDED_FOR
```

Fix:

- enabled proxy awareness in `MemFlip/backend/server.js`:

```js
app.set('trust proxy', 1);
```

Why it mattered:

- this warning would create noise and eventually make operator debugging harder
- it is also the correct local behavior for an app that is intentionally running behind a frontend proxy

#### 4. `scores.js` referenced `database` without importing it

Problem:

- the achievements helper in `MemFlip/backend/routes/scores.js` called `database.query(...)`
- but the file did not import `database`

Fix:

- added:

```js
const database = require('../models/database');
```

Why it mattered:

- even though the route still returned a response, it emitted noisy errors during the synthetic user-stats flow
- clean logs matter when we are building operator trust

#### 5. We hit transient startup timing twice

Problem:

- the control plane briefly showed `MemFlip` as degraded before the frontend blackbox probe caught up
- after rebuilding the backend, the frontend proxy briefly returned `502` while the backend was restarting

Fix:

- waited for the health checks and blackbox probes to settle
- only then ran the final static and live audits

Why it mattered:

- these were timing issues, not structural breakages
- recording that distinction prevents future operators from chasing false failures

### What We Changed

- updated `MemFlip/docker-compose.yml` so the backend publishes on `${BACKEND_HOST_PORT:-3101}`
- updated `MemFlip/.env.example` and `MemFlip/README.md`
- updated `WORKSPACE-SETUP-MATRIX.md`
- fixed:
  - `MemFlip/backend/server.js`
  - `MemFlip/backend/routes/game.js`
  - `MemFlip/backend/routes/scores.js`
- added:
  - `Obervability-Stack/scripts/memflip-audit.sh`
  - `Obervability-Stack/scripts/memflip-live-audit.sh`
- updated:
  - `Obervability-Stack/scripts/devops-monitor.sh`
  - `Obervability-Stack/scripts/README.md`
  - `Obervability-Stack/README.md`
  - `Obervability-Stack/docs/README.md`
  - `PROJECT-ROADMAP.md`
  - `JOURNEY-RUNBOOK.md`

### Validation

Validated successfully:

- `bash -n Obervability-Stack/scripts/memflip-audit.sh`
- `bash -n Obervability-Stack/scripts/memflip-live-audit.sh`
- `bash -n Obervability-Stack/scripts/devops-monitor.sh`
- `./Obervability-Stack/scripts/memflip-audit.sh`
- `./Obervability-Stack/scripts/memflip-live-audit.sh`
- `./Obervability-Stack/scripts/devops-monitor.sh memflip-live`

### Why This Mattered

This step proved that the audit pattern is no longer SwiftPay-specific.

We now have the same control-plane shape for two workloads:

- a static onboarding audit
- a live operator audit
- a documented runbook trail of the real issues encountered and fixed

That is a stronger Phase 3 position and a much cleaner bridge into Phase 4 app onboarding.

---

## Phase 3: OpenSIS And FoodPulse Audit Expansion

### Goal

Carry the static-plus-live audit pattern through `OpenSIS` and `FoodPulse` so the control-plane handoff is not limited to `SwiftPay` and `MemFlip`.

### Commands

```bash
rg -n "opensis|foodpulse" Obervability-Stack/ui-next/lib/monitored-apps.ts Obervability-Stack/prometheus/prometheus.yml Obervability-Stack/scripts Obervability-Stack/README.md Obervability-Stack/docs/README.md PROJECT-ROADMAP.md -g '!**/node_modules/**'
sed -n '1,220p' OpenSIS/.env.example
sed -n '1,220p' OpenSIS/scripts/compose-start.sh
sed -n '1,220p' OpenSIS/README.md
sed -n '1,260p' OpenSIS/docker-compose.yaml
sed -n '1,220p' OpenSIS/docker-compose.buildlocal.yaml
test -f OpenSIS/.env || cp OpenSIS/.env.example OpenSIS/.env
docker compose -f OpenSIS/docker-compose.yaml config
docker compose -f OpenSIS/docker-compose.yaml up -d
docker compose -f OpenSIS/docker-compose.yaml -f OpenSIS/docker-compose.buildlocal.yaml up -d --build
docker compose -f OpenSIS/docker-compose.yaml -f OpenSIS/docker-compose.buildlocal.yaml ps -a
docker compose -f OpenSIS/docker-compose.yaml -f OpenSIS/docker-compose.buildlocal.yaml logs --tail=120 vault-bootstrap vault-seed opensis-db opensis-ui vault-agent-app vault-agent-db
curl -fsSI http://localhost:8088
curl -fsS http://localhost:8200/v1/sys/health
curl -fsS http://localhost:4000/api/apps/health | jq '.apps[] | select(.appId=="opensis")'
curl -fsSL http://localhost:8088/install/index.php | sed -n '1,40p'

sed -n '1,220p' FoodPulse/.env.example
sed -n '1,260p' FoodPulse/docker-compose.yml
sed -n '1,320p' FoodPulse/scripts/cluster-status.sh
sed -n '1,260p' FoodPulse/scripts/pg-failover-drill.sh
sed -n '1,220p' FoodPulse/scripts/redis-failover-drill.sh
rg -n "localhost|9090|3000|9093|8404|5432|5433|6379|26379|80:80|UI_URL|APP_STATS_URL" FoodPulse/README.md FoodPulse/scripts FoodPulse/docker-compose.yml FoodPulse/monitoring -g '!**/node_modules/**'
test -f FoodPulse/.env || cp FoodPulse/.env.example FoodPulse/.env
docker compose -f FoodPulse/docker-compose.yml config
docker compose -f FoodPulse/docker-compose.yml up -d
docker compose -f FoodPulse/docker-compose.yml down && docker compose -f FoodPulse/docker-compose.yml up -d
docker compose -f FoodPulse/docker-compose.yml ps -a
docker logs --tail=120 foodpulse-yelb-appserver
docker logs --tail=120 foodpulse-pg-haproxy
docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' foodpulse-pg-haproxy
docker run --rm --network foodpulse_yelbnet postgres:14 getent hosts yelb-db-replica1 yelb-db-replica2 yelb-db-replica3
docker restart foodpulse-pg-haproxy
curl -fsSI http://localhost:8090
curl -fsSI http://localhost:8090/api/getstats
curl -fsS http://localhost:4000/api/apps/health | jq '.apps[] | select(.appId=="foodpulse")'
curl -fsS http://localhost:4000/api/apps | jq '.apps[] | select(.id=="foodpulse") | {id, browserUrl: .observability.endpoints[0].browserUrl, localStart: .runbooks.localStart, healthCheck: .runbooks.healthCheck}'

docker compose -f Obervability-Stack/docker-compose.yml up -d --build devops-monitor-ui
./Obervability-Stack/scripts/opensis-audit.sh
./Obervability-Stack/scripts/opensis-live-audit.sh
./Obervability-Stack/scripts/foodpulse-audit.sh
./Obervability-Stack/scripts/foodpulse-live-audit.sh
FoodPulse/scripts/cluster-status.sh
```

### What We Learned

- `OpenSIS` was already close to the target audit pattern, but Apple Silicon exposed a real deployment gap: the published `opensis-ui:dev` image does not ship an `arm64` manifest.
- The repo already had the right escape hatch in `docker-compose.buildlocal.yaml` and `./scripts/compose-start.sh --build-local`; we just needed to treat that path as first-class operator guidance instead of an edge case.
- `FoodPulse` was farther from a shared-workspace-ready state than the UI-only health signal suggested.
- It had multiple direct host-port collisions with the control plane and generic container names like `prometheus`, `grafana`, and `alertmanager` that would collide globally on a monorepo workstation.
- `FoodPulse` also had env contract drift: the repo's committed Redis and replication configs still expected `admin` and `replicatorpass`, while `.env.example` advertised different values.
- The control-plane source update for FoodPulse's browser URL did not become visible at runtime until we rebuilt `devops-monitor-ui`.

### Problems Encountered

#### 1. OpenSIS published image was not multi-arch

Problem:

- `docker compose -f OpenSIS/docker-compose.yaml up -d` failed on this Mac mini because `docker.io/eseosaiyangbe/opensis-ui:dev` had no `linux/arm64/v8` manifest.

Fix:

- switched to the existing local build override:

```bash
docker compose -f OpenSIS/docker-compose.yaml -f OpenSIS/docker-compose.buildlocal.yaml up -d --build
```

- documented the Apple Silicon preference for `./scripts/compose-start.sh --build-local`
- built the OpenSIS UI locally and then validated the live browser and Vault paths

Why it mattered:

- this is exactly the kind of platform reality we need in the runbook before any Kubernetes move
- the repo already had the right mechanism, but it was not yet treated as part of the normal operator contract

#### 2. FoodPulse could not coexist cleanly with the workspace

Problem:

- `FoodPulse/docker-compose.yml` published conflicting host ports like `80`, `3000`, `9090`, and `9093`
- it also used generic global container names like `prometheus`, `grafana`, and `alertmanager`

Fix:

- normalized FoodPulse host ports into root env vars
- moved the browser path to `http://localhost:8090`
- renamed containers to `foodpulse-*` to avoid collisions with the control plane and other repos

Why it mattered:

- without this step, `FoodPulse` could look healthy in isolation but still break the monorepo operator experience

#### 3. FoodPulse env defaults did not match the real lab config

Problem:

- the appserver returned `500` on `/api/getstats`
- `foodpulse-yelb-appserver` logs showed `Redis::CommandError - WRONGPASS`
- Postgres replicas also depended on a replication password that did not match the hardcoded bootstrap SQL

Fix:

- changed `FoodPulse/.env.example` to match the real lab defaults:
  - `YELB_REDIS_PASSWORD=admin`
  - `PG_REPLICATOR_PASSWORD=replicatorpass`
- refreshed the local `.env`
- recreated the FoodPulse stack

Why it mattered:

- the app UI was up, but the meaningful lab path was broken
- this was a real configuration drift issue, not just a warm-up delay

#### 4. FoodPulse helper scripts assumed Docker was globally installed

Problem:

- `FoodPulse/scripts/cluster-status.sh` and the failover drill helpers ran in non-interactive shells that did not inherit the user-space Docker install paths on this new Mac
- the result looked like application degradation, but the deeper issue was the same PATH gap we had already seen earlier on the workstation

Fix:

- sourced `~/.zprofile` at the top of:
  - `FoodPulse/scripts/cluster-status.sh`
  - `FoodPulse/scripts/pg-failover-drill.sh`
  - `FoodPulse/scripts/redis-failover-drill.sh`
- exported `PATH="$HOME/.local/bin:$HOME/.docker/cli-plugins:$PATH"` inside those helpers

Why it mattered:

- operators should not have to remember shell-specific PATH priming before the repo's own helpers work

#### 5. FoodPulse Postgres helper defaults were aimed at the wrong database

Problem:

- `cluster-status.sh` and `pg-failover-drill.sh` defaulted to `PG_DB=postgres`
- the lab actually bootstraps `yelbdatabase`

Fix:

- changed the helper default to `PG_DB=yelbdatabase`

Why it mattered:

- the helper would otherwise report empty or misleading Postgres results even when the actual application database path was healthy

#### 6. FoodPulse HAProxy relied on replica hostnames that were missing after normalization

Problem:

- after normalizing container names, `foodpulse-pg-haproxy` kept restarting
- logs showed it could not resolve `yelb-db-replica1`, `yelb-db-replica2`, and `yelb-db-replica3`

Fix:

- added those names back as `yelbnet` aliases on the replica services
- restarted `foodpulse-pg-haproxy` once the aliases were present

Why it mattered:

- this preserved the safer workspace-wide container names while restoring the lab's internal HAProxy topology assumptions

#### 7. FoodPulse HAProxy stats path was wrong in the live audit

Problem:

- the live audit initially checked `http://localhost:8410/`
- the HAProxy config exposes the human-readable stats UI at `/stats`

Fix:

- updated the live audit and README to use:

```text
http://localhost:8410/stats
```

Why it mattered:

- the stats service existed; the validation path was wrong
- documenting the exact path avoids a false negative for future operators

### What We Changed

- added:
  - `Obervability-Stack/scripts/opensis-audit.sh`
  - `Obervability-Stack/scripts/opensis-live-audit.sh`
  - `Obervability-Stack/scripts/foodpulse-audit.sh`
  - `Obervability-Stack/scripts/foodpulse-live-audit.sh`
- updated:
  - `Obervability-Stack/scripts/devops-monitor.sh`
  - `Obervability-Stack/scripts/README.md`
  - `Obervability-Stack/README.md`
  - `Obervability-Stack/docs/README.md`
  - `Obervability-Stack/ui-next/lib/monitored-apps.ts`
  - `PROJECT-ROADMAP.md`
  - `WORKSPACE-SETUP-MATRIX.md`
  - `JOURNEY-RUNBOOK.md`
- normalized `FoodPulse`:
  - `FoodPulse/docker-compose.yml`
  - `FoodPulse/.env.example`
  - `FoodPulse/README.md`
  - `FoodPulse/scripts/cluster-status.sh`
  - `FoodPulse/scripts/pg-failover-drill.sh`
  - `FoodPulse/scripts/redis-failover-drill.sh`

### Validation

Validated successfully:

- `bash -n Obervability-Stack/scripts/opensis-audit.sh`
- `bash -n Obervability-Stack/scripts/opensis-live-audit.sh`
- `bash -n Obervability-Stack/scripts/foodpulse-audit.sh`
- `bash -n Obervability-Stack/scripts/foodpulse-live-audit.sh`
- `docker compose -f OpenSIS/docker-compose.yaml -f OpenSIS/docker-compose.buildlocal.yaml config`
- `docker compose -f FoodPulse/docker-compose.yml config`
- `./Obervability-Stack/scripts/opensis-audit.sh`
- `./Obervability-Stack/scripts/opensis-live-audit.sh`
- `./Obervability-Stack/scripts/foodpulse-audit.sh`
- `./Obervability-Stack/scripts/foodpulse-live-audit.sh`
- `FoodPulse/scripts/cluster-status.sh`

### Why This Mattered

This completed the control-plane audit pattern across all four managed workloads in the workspace:

- `SwiftPay`
- `MemFlip`
- `OpenSIS`
- `FoodPulse`

That is the real handoff point for Phase 3.

We are no longer proving that the control plane can monitor one flagship app plus one small demo.
We now have:

- a modern microservices workload
- a lightweight frontend/backend demo
- a legacy monolith with Vault-backed bootstrap
- a resilience lab with HAProxy, replication, and local monitoring surfaces

That shifts the next bottleneck from control-plane trust to richer app onboarding and workflow design, which is exactly the Phase 4 handoff we wanted.

## 2026-04-19 04:35 EDT - Fix the main FoodPulse UI vote flow

### Objective

Repair the actual `FoodPulse` app interaction path so clicking restaurants in the main Yelb UI works again, not just the control-plane card that links to it.

### Commands Run

```bash
git status --short
sed -n '1,260p' FoodPulse/docker-compose.yml
sed -n '1,260p' FoodPulse/yelb/yelb-appserver/yelb-appserver.rb
sed -n '1,220p' FoodPulse/yelb/yelb-appserver/modules/restaurantsdbread.rb
sed -n '1,220p' FoodPulse/yelb/yelb-appserver/modules/restaurantsdbupdate.rb
sed -n '1,220p' FoodPulse/yelb/yelb-appserver/Dockerfile
sed -n '1,200p' FoodPulse/.env.example
curl -fsSL http://localhost:8090 | sed -n '1,220p'
curl -fsSL http://localhost:8090/env.js | sed -n '1,120p'
rg -n "env.js|YELB_APPSERVER_ENDPOINT|appserver|api/getvotes|api/outback|api/vote|base href|appserver" FoodPulse/yelb/yelb-ui FoodPulse/yelb -g '!**/node_modules/**'
source ~/.zprofile >/dev/null 2>&1; docker logs --tail=120 foodpulse-yelb-ui
source ~/.zprofile >/dev/null 2>&1; docker logs --tail=120 foodpulse-yelb-appserver
ruby -c FoodPulse/yelb/yelb-appserver/yelb-appserver.rb
ruby -c FoodPulse/yelb/yelb-appserver/modules/restaurantsdbread.rb
ruby -c FoodPulse/yelb/yelb-appserver/modules/restaurantsdbupdate.rb
source ~/.zprofile >/dev/null 2>&1; docker compose -f FoodPulse/docker-compose.yml config >/tmp/foodpulse-compose.out && tail -n 20 /tmp/foodpulse-compose.out
source ~/.zprofile >/dev/null 2>&1; docker compose -f FoodPulse/docker-compose.yml up -d --build yelb-appserver yelb-ui
curl -sS -o /tmp/fp-getvotes.out -w '%{http_code}\n' http://localhost:8090/api/getvotes && echo '---' && cat /tmp/fp-getvotes.out
curl -sS -o /tmp/fp-vote.out -w '%{http_code}\n' http://localhost:8090/api/outback && echo '---' && cat /tmp/fp-vote.out
source ~/.zprofile >/dev/null 2>&1; docker logs --tail=80 foodpulse-yelb-appserver
curl -sS http://localhost:8090/api/getvotes
curl -sS http://localhost:8090/api/getstats
```

### Problem

The main `FoodPulse` UI loaded, but clicking restaurants felt broken because the backend vote endpoints were failing with `500`.

The key symptom chain was:

- `http://localhost:8090/api/getstats` returned `200`
- `http://localhost:8090/api/getvotes` returned `500`
- restaurant vote routes like `/api/outback` returned `500`
- `foodpulse-yelb-appserver` logs showed:

```text
PG::ConnectionBad - FATAL: role "postgres" does not exist
```

### Root Cause

The appserver was only partially normalized for this workspace.

`FoodPulse` had already moved its Postgres bootstrap to the repo's env contract:

- `YELB_DB_USER`
- `YELB_DB_PASSWORD`
- database name `yelbdatabase`

But the vendored Yelb Ruby modules were still hardcoded to the upstream defaults:

- user: `postgres`
- password: `postgres_password`

That meant the read and write paths behind the UI clicks were trying to authenticate as a role this repo does not create.

There was a second deployment gap too:

- `FoodPulse/docker-compose.yml` was still pulling `eseosaiyangbe/yelb-appserver:v2`
- so even after fixing local source, the running service would not have changed unless the compose service used a local build

### Fix

Updated the vendored appserver code to honor the repo's environment contract:

- added global DB settings in:
  - `FoodPulse/yelb/yelb-appserver/yelb-appserver.rb`
- replaced hardcoded Postgres credentials in:
  - `FoodPulse/yelb/yelb-appserver/modules/restaurantsdbread.rb`
  - `FoodPulse/yelb/yelb-appserver/modules/restaurantsdbupdate.rb`

Updated the compose runtime so the fixed local source is what actually runs:

- changed `FoodPulse/docker-compose.yml` so `yelb-appserver` builds from `./yelb/yelb-appserver`
- passed:
  - `YELB_DB_NAME`
  - `YELB_DB_USER`
  - `YELB_DB_PASSWORD`

Updated the documented env contract:

- added `YELB_DB_NAME` to `FoodPulse/.env.example`
- documented the local-build expectation in `FoodPulse/README.md`

### Validation

Syntax and config checks passed:

- `ruby -c FoodPulse/yelb/yelb-appserver/yelb-appserver.rb`
- `ruby -c FoodPulse/yelb/yelb-appserver/modules/restaurantsdbread.rb`
- `ruby -c FoodPulse/yelb/yelb-appserver/modules/restaurantsdbupdate.rb`
- `docker compose -f FoodPulse/docker-compose.yml config`

Runtime validation passed:

- `GET http://localhost:8090/api/getvotes` returned `200`
- `GET http://localhost:8090/api/outback` returned `200`
- a follow-up `GET http://localhost:8090/api/getvotes` showed `outback` increment from `0` to `1`

Observed healthy responses:

```json
[{"name": "outback", "value": 1},{"name": "bucadibeppo", "value": 0},{"name": "ihop", "value": 0}, {"name": "chipotle", "value": 0}]
```

### Why This Mattered

This fixed the actual user-facing `FoodPulse` experience, not just the monitoring shell around it.

It also moved the repo one step closer to a Kubernetes-friendly model:

- app configuration now comes from explicit environment variables instead of hidden upstream constants
- the running service now builds from workspace-owned source
- the database contract is consistent between bootstrap, compose, and application code

## 2026-04-19 04:46 EDT - Modernize FoodPulse and remove duplicates

### Objective

Modernize the `FoodPulse` repo structure and remove obvious duplicates/noise without breaking the HA lab or the future Kubernetes migration path.

### Commands Run

```bash
find FoodPulse -maxdepth 3 -type d | sort
find FoodPulse -maxdepth 3 -type f | sort
du -sh FoodPulse/* FoodPulse/.* 2>/dev/null | sort -h
rg -n "TODO|FIXME|deprecated|duplicate|upstream|vendored|legacy|obsolete" FoodPulse -g '!**/node_modules/**'
diff -u FoodPulse/yelb-db/init-yelb-db.sh FoodPulse/yelb/yelb-db/init-yelb-db.sh || true
find FoodPulse/ui -maxdepth 3 -type f -print -exec sed -n '1,200p' {} \;
find FoodPulse/yelb/deployments -maxdepth 4 -type f | sed -n '1,200p'
sed -n '1,240p' FoodPulse/yelb/README.md
rg -n "ui-setup\.sh|yelb-ui-ng|FoodPulse/ui|Dashboards/Grafana1\.json|Grafana1\.json" . -g '!**/node_modules/**'
find FoodPulse/Dashboards -maxdepth 3 -type f -print -exec sed -n '1,80p' {} \;
sed -n '1,260p' FoodPulse/monitoring/prometheus.yml
find FoodPulse/monitoring/grafana -maxdepth 4 -type f -print -exec sed -n '1,120p' {} \;
rg --files -g '.gitignore'
sed -n '1,240p' .gitignore
git ls-files FoodPulse/.DS_Store FoodPulse/yelb/.DS_Store FoodPulse/yelb/deployments/.DS_Store FoodPulse/ui/ui-setup.sh FoodPulse/Dashboards/Grafana1.json FoodPulse/yelb-db/init-yelb-db.sh
rg -n "grafana|Dashboards|provisioning|dashboard" FoodPulse/docker-compose.yml FoodPulse/README.md
sed -n '200,360p' FoodPulse/docker-compose.yml
wc -l FoodPulse/Dashboards/Grafana1.json && sed -n '1,40p' FoodPulse/Dashboards/Grafana1.json
mkdir -p FoodPulse/monitoring/grafana/dashboards && mv FoodPulse/Dashboards/Grafana1.json FoodPulse/monitoring/grafana/dashboards/yelb-observability.json && rmdir FoodPulse/Dashboards && rmdir FoodPulse/ui && rm -f FoodPulse/.DS_Store FoodPulse/yelb/.DS_Store FoodPulse/yelb/deployments/.DS_Store && chmod +x FoodPulse/scripts/start.sh FoodPulse/scripts/stop.sh && git status --short
bash -n FoodPulse/scripts/start.sh && bash -n FoodPulse/scripts/stop.sh && bash -n FoodPulse/scripts/cluster-status.sh && bash -n FoodPulse/scripts/pg-failover-drill.sh && bash -n FoodPulse/scripts/redis-failover-drill.sh
source ~/.zprofile >/dev/null 2>&1; docker compose -f FoodPulse/docker-compose.yml config >/tmp/foodpulse-modernize.out && tail -n 40 /tmp/foodpulse-modernize.out
find FoodPulse -maxdepth 3 \( -name '.DS_Store' -o -path 'FoodPulse/ui' -o -path 'FoodPulse/Dashboards' \) -print
./FoodPulse/scripts/start.sh
source ~/.zprofile >/dev/null 2>&1; docker exec foodpulse-grafana sh -lc 'ls -1 /var/lib/grafana/dashboards && echo --- && ls -1 /etc/grafana/provisioning/dashboards && echo --- && sed -n "1,80p" /etc/grafana/provisioning/dashboards/dashboard.yml'
curl -fsSI http://localhost:8090 | sed -n '1,20p' && echo '---' && curl -fsSI http://localhost:3010 | sed -n '1,20p'
rg -n "FoodPulse/Dashboards|Dashboards/Grafana1.json|FoodPulse/ui|ui-setup.sh|yelb-db/init-yelb-db.sh" . -g '!**/node_modules/**'
```

### What We Found

The repo had three kinds of clutter:

1. Actual duplicates

- `FoodPulse/yelb-db/init-yelb-db.sh` was a duplicate copy of the vendored upstream DB bootstrap at `FoodPulse/yelb/yelb-db/init-yelb-db.sh`

2. Dead scaffolding

- `FoodPulse/ui/ui-setup.sh` was a standalone Angular scaffold script that was not referenced by the running stack

3. Orphaned assets

- `FoodPulse/Dashboards/Grafana1.json` contained a useful dashboard, but it was not wired into Grafana provisioning

### Problems

#### 1. The repo had two database bootstrap entrypoints for one database contract

Problem:

- the Compose stack mounted `FoodPulse/yelb-db/init-yelb-db.sh`
- the vendored application also already had `FoodPulse/yelb/yelb-db/init-yelb-db.sh`
- they were effectively the same bootstrap with only formatting differences

Fix:

- changed `FoodPulse/docker-compose.yml` to mount the vendored canonical bootstrap
- deleted the duplicate root-level copy

Why it mattered:

- there should be one source of truth for the application schema bootstrap
- duplicate bootstrap files become drift traps during future Kubernetes work

#### 2. A root `ui/` directory looked important but was not part of the runtime

Problem:

- `FoodPulse/ui/ui-setup.sh` described an alternative Angular rebuild path
- it was not referenced by Compose, the app runtime, or operator docs

Fix:

- removed the orphaned `ui/` folder

Why it mattered:

- dead scaffolding makes the repo look less trustworthy than it is
- it also makes onboarding harder because operators cannot tell what is canonical

#### 3. Grafana dashboard JSON existed, but Grafana was not actually provisioning it

Problem:

- `FoodPulse/Dashboards/Grafana1.json` was useful
- Grafana only mounted datasource provisioning, not dashboard provisioning

Fix:

- moved the dashboard to:
  - `FoodPulse/monitoring/grafana/dashboards/yelb-observability.json`
- added:
  - `FoodPulse/monitoring/grafana/provisioning/dashboards/dashboard.yml`
- updated `FoodPulse/docker-compose.yml` to mount both the dashboard provider config and the dashboard directory

Why it mattered:

- observability assets should be live runtime configuration, not loose files sitting beside the repo
- this makes the repo more reproducible and more Kubernetes-friendly

#### 4. FoodPulse lacked a canonical start/stop wrapper

Problem:

- the repo relied on people remembering manual `docker compose` and network steps
- this is easy to get wrong on a fresh workstation or after shell/PATH resets

Fix:

- added:
  - `FoodPulse/scripts/start.sh`
  - `FoodPulse/scripts/stop.sh`

The new start path:

- loads user-space toolchain paths
- checks for `.env`
- creates `observability-net` if needed
- rebuilds the local `yelb-appserver`
- starts the rest of the stack

Why it mattered:

- operator entrypoints should be explicit
- this is the kind of contract we will want again when moving to Kubernetes

#### 5. The appserver and UI build contexts were looser than they needed to be

Problem:

- the local build contexts could include unnecessary repo files

Fix:

- added:
  - `FoodPulse/yelb/yelb-appserver/.dockerignore`
  - `FoodPulse/yelb/yelb-ui/.dockerignore`

Why it mattered:

- smaller build contexts are easier to reason about and cheaper to rebuild

### Validation

Validated successfully:

- `bash -n FoodPulse/scripts/start.sh`
- `bash -n FoodPulse/scripts/stop.sh`
- `bash -n FoodPulse/scripts/cluster-status.sh`
- `bash -n FoodPulse/scripts/pg-failover-drill.sh`
- `bash -n FoodPulse/scripts/redis-failover-drill.sh`
- `docker compose -f FoodPulse/docker-compose.yml config`
- `./FoodPulse/scripts/start.sh`
- `curl -fsSI http://localhost:8090`
- `curl -fsSI http://localhost:3010`
- `docker exec foodpulse-grafana ...` confirmed:
  - the dashboard file exists at `/var/lib/grafana/dashboards`
  - the provisioning file exists at `/etc/grafana/provisioning/dashboards/dashboard.yml`

### Why This Mattered

This was not just cosmetic cleanup.

It made `FoodPulse` more intentional in the ways that matter operationally:

- one canonical bootstrap path
- one canonical local startup path
- live Grafana provisioning instead of stray dashboard files
- less ambiguity about what is runtime code versus historical scaffolding

That gives us a cleaner repo now and reduces future migration debt when we carry this workload into Kubernetes.

## 2026-04-19 05:00 EDT - Remove duplicate observability from FoodPulse

### Objective

Remove the embedded observability stack from `FoodPulse` so the repo focuses on the application and HA lab, while the central `Obervability-Stack` remains the single monitoring layer for the workspace.

### Commands Run

```bash
rg -n "FoodPulse/monitoring|prometheus|grafana|alertmanager|blackbox|postgres-exporter|redis-exporter|9095|3010|9096|8410|Prometheus|Grafana|Alertmanager" FoodPulse Obervability-Stack WORKSPACE-SETUP-MATRIX.md PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md -g '!**/node_modules/**'
sed -n '1,260p' FoodPulse/docker-compose.yml
sed -n '1,240p' FoodPulse/README.md
sed -n '1,260p' Obervability-Stack/scripts/foodpulse-audit.sh
sed -n '1,320p' Obervability-Stack/scripts/foodpulse-live-audit.sh
sed -n '1,260p' FoodPulse/.env.example
sed -n '1,260p' FoodPulse/scripts/cluster-status.sh
sed -n '1,240p' WORKSPACE-SETUP-MATRIX.md
sed -n '240,340p' Obervability-Stack/ui-next/lib/monitored-apps.ts
rg -n "8410|HAPROXY_STATS|/stats|8404|8405" FoodPulse Obervability-Stack WORKSPACE-SETUP-MATRIX.md JOURNEY-RUNBOOK.md -g '!**/node_modules/**'
sed -n '1,240p' FoodPulse/haproxy/haproxy.cfg
sed -n '1,240p' FoodPulse/haproxy/haproxy-redis.cfg
find FoodPulse/monitoring -maxdepth 4 -type f | sort
rg -n "cp \\.env\\.example \\.env && docker compose up -d|cp \\.env\\.example \\.env && \\./scripts/start\\.sh|Prometheus|Grafana|Alertmanager|9095|3010|9096|8410|monitoring/" Obervability-Stack/ui-next/lib/monitored-apps.ts WORKSPACE-SETUP-MATRIX.md FoodPulse/README.md JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md -g '!**/node_modules/**'
rm -rf FoodPulse/monitoring
bash -n FoodPulse/scripts/start.sh && bash -n FoodPulse/scripts/stop.sh && bash -n Obervability-Stack/scripts/foodpulse-audit.sh && bash -n Obervability-Stack/scripts/foodpulse-live-audit.sh
source ~/.zprofile >/dev/null 2>&1; docker compose -f FoodPulse/docker-compose.yml config >/tmp/foodpulse-no-obs.out && tail -n 40 /tmp/foodpulse-no-obs.out
./FoodPulse/scripts/start.sh
source ~/.zprofile >/dev/null 2>&1; docker ps --format '{{.Names}}' | rg '^foodpulse-(prometheus|grafana|alertmanager|postgres-exporter|redis-exporter|blackbox-exporter)$' || true
./Obervability-Stack/scripts/foodpulse-audit.sh
./Obervability-Stack/scripts/foodpulse-live-audit.sh
curl -i http://localhost:8090/api/getstats
source ~/.zprofile >/dev/null 2>&1; docker logs --tail=120 foodpulse-yelb-ui
source ~/.zprofile >/dev/null 2>&1; docker logs --tail=120 foodpulse-yelb-appserver
curl -fsS http://localhost:8090/api/getstats
```

### Problems

#### 1. FoodPulse still carried a second monitoring stack

Problem:

- `FoodPulse/docker-compose.yml` still defined:
  - Prometheus
  - Grafana
  - Alertmanager
  - blackbox-exporter
  - postgres-exporter
  - redis-exporter
- the repo also still had a full `FoodPulse/monitoring/` tree

Why it mattered:

- the workspace already has `Obervability-Stack` as the central monitoring plane
- leaving a second stack inside `FoodPulse` created duplication, extra ports, and extra operator confusion

Fix:

- removed the observability services from `FoodPulse/docker-compose.yml`
- removed the related env variables from `FoodPulse/.env.example`
- deleted the `FoodPulse/monitoring/` tree

#### 2. HAProxy still exposed stats and metrics frontends that only existed for the deleted local monitoring stack

Problem:

- both HAProxy configs still exposed:
  - stats UI on `8404`
  - Prometheus exporter endpoint on `8405`
- `pg-haproxy` also still published the stats port to the host

Fix:

- removed those frontends from:
  - `FoodPulse/haproxy/haproxy.cfg`
  - `FoodPulse/haproxy/haproxy-redis.cfg`
- removed the host stats port from `FoodPulse/docker-compose.yml`

Why it mattered:

- once the local Prometheus/Grafana stack was gone, these surfaces were just leftover observability baggage

#### 3. FoodPulse startup left old observability containers behind as orphans

Problem:

- a plain `docker compose up` can leave removed services running as orphan containers
- on a workstation that had already started the old FoodPulse stack, the deleted observability containers would remain alive until explicitly removed

Fix:

- updated:
  - `FoodPulse/scripts/start.sh`
  - `FoodPulse/scripts/stop.sh`
- both now use `--remove-orphans`

Why it mattered:

- this ensures the repo cleanup actually takes effect on existing machines

#### 4. Rebuilding the appserver could leave `yelb-ui` pointing at a dead upstream IP

Problem:

- after removing the local monitoring stack and rerunning startup, `foodpulse-yelb-ui` briefly returned `404` for `/api/getstats`
- nginx logs showed it was still trying to reach the old `yelb-appserver` container IP after the appserver had been recreated

Fix:

- updated `FoodPulse/scripts/start.sh` to force-recreate `yelb-ui` after rebuilding `yelb-appserver`

Why it mattered:

- without that step, a valid appserver rebuild could still leave the FoodPulse UI in a broken state

#### 5. The control-plane audits still expected FoodPulse to own Prometheus and Grafana

Problem:

- `Obervability-Stack/scripts/foodpulse-audit.sh` still checked for local Prometheus/Grafana/Alertmanager containers and ports
- `Obervability-Stack/scripts/foodpulse-live-audit.sh` still tried to hit FoodPulse’s deleted monitoring endpoints

Fix:

- rewrote the static audit to verify:
  - the local browser URL
  - the control-plane inventory contract
  - the absence of a local Prometheus/Grafana/Alertmanager stack
- rewrote the live audit to verify:
  - FoodPulse UI health
  - FoodPulse proxied stats endpoint
  - control-plane app health
  - central Prometheus blackbox visibility

Also updated:

- `Obervability-Stack/ui-next/lib/monitored-apps.ts`
- `WORKSPACE-SETUP-MATRIX.md`

### Validation

Validated successfully:

- `bash -n FoodPulse/scripts/start.sh`
- `bash -n FoodPulse/scripts/stop.sh`
- `bash -n Obervability-Stack/scripts/foodpulse-audit.sh`
- `bash -n Obervability-Stack/scripts/foodpulse-live-audit.sh`
- `docker compose -f FoodPulse/docker-compose.yml config`
- `./FoodPulse/scripts/start.sh`
- `./Obervability-Stack/scripts/foodpulse-audit.sh`
- `./Obervability-Stack/scripts/foodpulse-live-audit.sh`

Runtime validation confirmed:

- no `foodpulse-prometheus`, `foodpulse-grafana`, `foodpulse-alertmanager`, `foodpulse-postgres-exporter`, `foodpulse-redis-exporter`, or `foodpulse-blackbox-exporter` containers remained
- `GET http://localhost:8090/api/getstats` returned live app telemetry again after the `yelb-ui` recreation fix
- the control plane still saw `FoodPulse` as healthy via `/api/apps/health`
- central Prometheus still reported healthy FoodPulse blackbox targets

### Why This Mattered

This removed a duplicated platform concern from the workspace.

`FoodPulse` is now back to being what it should be:

- a resilience and failover lab
- a stateful application target
- a workload observed by `Obervability-Stack`

That makes the repo simpler now and closer to the cluster shape we want later, where app repos own workloads and the control plane owns monitoring.
