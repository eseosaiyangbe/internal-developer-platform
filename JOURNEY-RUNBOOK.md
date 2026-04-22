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

## 2026-04-19 05:13 EDT - Collapse the duplicate `yelb-db` folders in FoodPulse

### Objective

Clean up the remaining duplicate-looking `yelb-db` structure in `FoodPulse` so the repo has:

- one vendored app DB source at `yelb/yelb-db/`
- one workspace-owned Postgres extension path under `postgres/`

### Commands Run

```bash
find FoodPulse/yelb-db -maxdepth 2 -type f | sort && printf '\n---\n' && find FoodPulse/yelb/yelb-db -maxdepth 2 -type f | sort
sed -n '1,220p' FoodPulse/yelb-db/02-create-replicator.sql && printf '\n---\n' && sed -n '1,220p' FoodPulse/yelb-db/03-pghba-override.sh && printf '\n---VENDORED---\n' && sed -n '1,220p' FoodPulse/yelb/yelb-db/Dockerfile && printf '\n---\n' && sed -n '1,220p' FoodPulse/yelb/yelb-db/README.md
rg -n "yelb-db/02-create-replicator.sql|yelb-db/03-pghba-override.sh|./yelb-db|FoodPulse/yelb-db" FoodPulse Obervability-Stack WORKSPACE-SETUP-MATRIX.md JOURNEY-RUNBOOK.md -g '!**/node_modules/**'
rmdir FoodPulse/yelb-db && echo removed-yelb-db-dir || ls -la FoodPulse/yelb-db
rg -n "./yelb-db|FoodPulse/yelb-db|postgres/initdb|root-level duplicate copy|workspace-specific replication bootstrap" FoodPulse Obervability-Stack WORKSPACE-SETUP-MATRIX.md JOURNEY-RUNBOOK.md -g '!**/node_modules/**'
bash -n FoodPulse/postgres/initdb/03-pghba-override.sh && source ~/.zprofile >/dev/null 2>&1; docker compose -f FoodPulse/docker-compose.yml config >/tmp/foodpulse-db-cleanup.out && tail -n 40 /tmp/foodpulse-db-cleanup.out
./Obervability-Stack/scripts/foodpulse-audit.sh
```

### Problem

Even after the earlier cleanup, `FoodPulse` still had two folders that looked like competing database sources:

- `FoodPulse/yelb/yelb-db/`
- `FoodPulse/yelb-db/`

What they actually were:

- `FoodPulse/yelb/yelb-db/` was the vendored upstream application database source
- `FoodPulse/yelb-db/` only held two workspace-specific replication bootstrap files:
  - `02-create-replicator.sql`
  - `03-pghba-override.sh`

Why it mattered:

- the directory names implied a duplicate app DB implementation
- that makes the repo harder to understand and weakens the “vendored app code versus workspace platform glue” boundary

### Fix

Moved the workspace-owned replication bootstrap files to:

- `FoodPulse/postgres/initdb/02-create-replicator.sql`
- `FoodPulse/postgres/initdb/03-pghba-override.sh`

Updated `FoodPulse/docker-compose.yml` so the Postgres primary now mounts:

- `./yelb/yelb-db/init-yelb-db.sh`
- `./postgres/initdb/02-create-replicator.sql`
- `./postgres/initdb/03-pghba-override.sh`

Then removed the now-empty root `FoodPulse/yelb-db/` directory.

### Validation

Validated successfully:

- `bash -n FoodPulse/postgres/initdb/03-pghba-override.sh`
- `docker compose -f FoodPulse/docker-compose.yml config`
- `./Obervability-Stack/scripts/foodpulse-audit.sh`

### Why This Mattered

This makes the repo structure tell the truth more clearly:

- `yelb/yelb-db/` is the vendored upstream app DB layer
- `postgres/initdb/` is the workspace-specific bootstrap extension layer

That is a much better boundary for future Kubernetes work than having a second root-level `yelb-db/` folder that looks like a duplicate implementation.

## 2026-04-19 05:40 EDT - Rebrand the FoodPulse runtime layer from Yelb to FoodPulse

### Objective

Rename the workspace-facing `FoodPulse` runtime from `yelb` to `foodpulse` without doing a reckless full rewrite of the vendored upstream source tree.

The boundary for this change was deliberate:

- rename the runtime surfaces operators and users actually touch
- keep the vendored upstream source tree under `FoodPulse/yelb/` for now
- preserve compatibility fallbacks for old `YELB_*` local env files while standardizing on `FOODPULSE_*`

### Commands Run

```bash
git status --short
source ~/.zprofile >/dev/null 2>&1; docker compose -f FoodPulse/docker-compose.yml config >/tmp/foodpulse-compose.out && tail -n 20 /tmp/foodpulse-compose.out
bash -n FoodPulse/scripts/start.sh FoodPulse/scripts/cluster-status.sh FoodPulse/scripts/pg-failover-drill.sh FoodPulse/scripts/redis-failover-drill.sh FoodPulse/postgres/replica-entrypoint.sh
source ~/.zprofile >/dev/null 2>&1; ./FoodPulse/scripts/start.sh
rg -n "yelb|YELB" FoodPulse --glob '!FoodPulse/yelb/deployments/**' --glob '!FoodPulse/yelb/README*' --glob '!FoodPulse/yelb/**/README*' --glob '!FoodPulse/yelb/**/*.md'
rg -n "platform:" FoodPulse/docker-compose.yml
source ~/.zprofile >/dev/null 2>&1; ./FoodPulse/scripts/start.sh
git diff --stat -- FoodPulse
```

### Problems Encountered

#### 1. Full repo-wide rename would have been too risky

`FoodPulse` still contains hundreds of `yelb` references inside vendored upstream material.

Why that mattered:

- many are historical deployment examples or upstream code symbols
- a blind global replace would have created a large, hard-to-review fork
- that kind of rewrite would make future upstream comparison or selective borrowing much harder

#### 2. Building the rebranded runtime exposed an Apple Silicon emulation failure

After switching the runtime to build from local source, `foodpulse-appserver` failed while the compose stack still forced every service to `platform: linux/amd64`.

Observed failure:

- the Ruby `pg` gem native extension crashed the compiler inside the emulated `amd64` build with an internal compiler error

Why it mattered:

- this Mac is Apple Silicon
- forcing the entire stack through `amd64` emulation creates avoidable fragility and startup latency
- that is exactly the wrong direction if we want a clean path toward Kubernetes later

#### 3. The vendored UI toolchain is not really multi-arch

After removing global `amd64` forcing, the appserver built natively, but the legacy Angular UI failed because:

- `phantomjs-prebuilt` has no `linux/arm64` binary
- the UI build still pulls a very old PhantomJS-dependent toolchain

Why it mattered:

- the runtime rename worked conceptually, but it surfaced real modernization debt in the vendored UI
- we needed a pragmatic runtime fix instead of pretending the old toolchain is modern

### Fixes Applied

#### Runtime rebrand

Renamed the workspace-owned runtime layer across:

- `FoodPulse/docker-compose.yml`
- `FoodPulse/.env.example`
- `FoodPulse/scripts/start.sh`
- `FoodPulse/scripts/cluster-status.sh`
- `FoodPulse/scripts/pg-failover-drill.sh`
- `FoodPulse/scripts/redis-failover-drill.sh`
- `FoodPulse/postgres/replica-entrypoint.sh`
- `FoodPulse/haproxy/haproxy.cfg`
- `FoodPulse/haproxy/haproxy-redis.cfg`
- `FoodPulse/haproxy/haproxy-redis.cfg.template.production`
- `FoodPulse/README.md`

Key runtime changes:

- service names changed from `yelb-*` to `foodpulse-*`
- operator env vars changed from `YELB_*` to `FOODPULSE_*`
- browser/runtime branding changed from `Yelb` to `FoodPulse`
- startup and drill scripts now prefer `FOODPULSE_*` while still accepting old `YELB_*` fallbacks

#### Native-first platform correction

Removed blanket `platform: linux/amd64` forcing from the stack so:

- `foodpulse-appserver`
- Postgres
- Redis
- Sentinel
- HAProxy data-plane services

can run natively on Apple Silicon and other multi-arch developer machines.

That fixed the appserver compiler crash by taking the hot path off full emulation.

#### UI containment fix

The legacy UI remains special-cased:

- `foodpulse-ui` was pinned back to `platform: linux/amd64`

Why:

- the vendored UI still depends on old x64-only PhantomJS binaries
- isolating emulation to the UI is far better than forcing the whole stack into `amd64`

### Validation

Successful checks during this slice:

- `bash -n` passed for the renamed helper scripts
- `docker compose -f FoodPulse/docker-compose.yml config` passed after each compose edit
- the appserver image successfully rebuilt once the full-stack `amd64` forcing was removed

Live end-to-end validation is still tied to the legacy UI build finishing, because the rebrand intentionally switched the UI from a stale external image to a local source build so the `FoodPulse` branding can actually show up at runtime.

### Why This Mattered

This was more than a cosmetic rename.

It clarified the real architecture boundary:

- `FoodPulse` is the workspace-owned runtime and operator contract
- `yelb/` is still the vendored upstream source tree

It also surfaced two important platform truths early:

- native-first multi-arch development matters on modern Macs
- the vendored UI is the real modernization bottleneck, not the appserver or data plane

That is valuable information for the later Kubernetes move, because it tells us where the actual risk lives instead of letting the old UI debt stay hidden behind prebuilt images.

## 2026-04-19 05:55 EDT - Replace the legacy FoodPulse app with an owned modern application

### Objective

Turn `FoodPulse` into an application we actually own:

- replace the inherited legacy UI and Ruby appserver with a modern UI/API stack
- preserve the Redis, Sentinel, Postgres, and HAProxy lab topology
- eliminate `yelb*` from the `FoodPulse` repo
- keep the control-plane contract intact so the existing audits still work

### Commands Run

```bash
find FoodPulse -maxdepth 3 -type d | sort
rg --files FoodPulse | sort
sed -n '1,260p' FoodPulse/docker-compose.yml
sed -n '1,240p' Obervability-Stack/scripts/foodpulse-live-audit.sh
sed -n '1,220p' Obervability-Stack/scripts/foodpulse-audit.sh
sed -n '1,260p' FoodPulse/yelb/yelb-db/init-yelb-db.sh
sed -n '1,260p' FoodPulse/yelb/yelb-appserver/yelb-appserver.rb
sed -n '1,260p' FoodPulse/yelb/yelb-ui/clarity-seed-newfiles/src/app/app.component.html
sed -n '1,220p' FoodPulse/scripts/cluster-status.sh
sed -n '1,200p' FoodPulse/sentinel/sentinel-01.conf
sed -n '1,160p' FoodPulse/redis/replica/redis.conf
mkdir -p FoodPulse/api/src FoodPulse/ui/src FoodPulse/postgres/initdb
rm -rf FoodPulse/yelb
rg -n "yelb|YELB|odilia" FoodPulse
npm install --package-lock-only
npm ci
npm run build
bash -n FoodPulse/scripts/start.sh FoodPulse/scripts/stop.sh FoodPulse/scripts/cluster-status.sh FoodPulse/scripts/pg-failover-drill.sh FoodPulse/scripts/redis-failover-drill.sh FoodPulse/postgres/replica-entrypoint.sh
docker compose -f FoodPulse/docker-compose.yml config
cp FoodPulse/.env.example FoodPulse/.env
./FoodPulse/scripts/start.sh
docker compose -f FoodPulse/docker-compose.yml down --remove-orphans
docker compose -f FoodPulse/docker-compose.yml down -v --remove-orphans
docker logs --tail 120 foodpulse-api
docker logs --tail 80 foodpulse-db
docker exec -i foodpulse-db psql -U postgres -d foodpulse -c "SELECT venue_slug, count(*) FROM vote_events GROUP BY venue_slug ORDER BY venue_slug;"
docker exec -i foodpulse-db psql -U postgres -d foodpulse <<'SQL'
ALTER DATABASE foodpulse OWNER TO foodpulse;
ALTER SCHEMA public OWNER TO foodpulse;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO foodpulse;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO foodpulse;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO foodpulse;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO foodpulse;
SQL
docker compose -f FoodPulse/docker-compose.yml restart foodpulse-api
curl -fsS http://localhost:8090/api/getstats
curl -fsS http://localhost:8090/api/venues
curl -fsS -X POST http://localhost:8090/api/vote -H 'Content-Type: application/json' -d '{"venueSlug":"greenhouse-kitchen"}'
curl -fsS http://localhost:8090/api/getvotes
./Obervability-Stack/scripts/foodpulse-audit.sh
./Obervability-Stack/scripts/foodpulse-live-audit.sh
```

### Problems Encountered

#### 1. The new Compose file had a duplicate `external: true` key

Observed failure:

- `docker compose -f FoodPulse/docker-compose.yml config` failed with a YAML parse error

Fix:

- removed the duplicated `external` key from the `observability-net` definition

#### 2. The first startup still carried forward old local database state

Observed failure:

- `foodpulse-api` restarted with `role "foodpulse" does not exist`

Why it happened:

- an older local Postgres volume predated the new owned app role and schema bootstrap

Fix:

- rewrote the database bootstrap into `FoodPulse/postgres/initdb/01-init-foodpulse.sh`
- created the owned app role and owned database explicitly
- reset the local FoodPulse volumes with `docker compose down -v --remove-orphans`

#### 3. The API was still too eager at startup

Observed failure:

- even after the role existed, the API could still fail with `Connection terminated unexpectedly`

Why it happened:

- Postgres was still finishing bootstrap when the API tried its first dependency check

Fix:

- added a startup retry loop in `FoodPulse/api/src/index.js`
- the API now waits and retries instead of crash-looping immediately

#### 4. The app role could connect but could not read seeded tables

Observed failure:

- the API logged `permission denied for table venues`

Fix:

- granted ownership and table/sequence privileges to the `foodpulse` role
- updated the bootstrap script so future resets get the same privileges automatically
- applied the grant fix to the current local database too

#### 5. The seeded price-band strings were corrupted

Observed failure:

- venue payloads showed values like `152` and `152$` instead of `$$` and `$$$`

Why it happened:

- shell expansion inside the init script treated `$$` as the current process ID

Fix:

- escaped the dollar signs in the bootstrap script
- corrected the already-seeded rows in the running local database

### Implementation Summary

Owned app surface created:

- `FoodPulse/ui`
- `FoodPulse/api`

Legacy runtime removed:

- deleted the entire `FoodPulse/yelb` tree

Infrastructure alignment updated:

- `FoodPulse/docker-compose.yml`
- `FoodPulse/redis/replica/redis.conf`
- `FoodPulse/sentinel/sentinel-01.conf`
- `FoodPulse/sentinel/sentinel-02.conf`
- `FoodPulse/sentinel/sentinel-03.conf`
- `FoodPulse/haproxy/haproxy-redis.cfg`
- `FoodPulse/haproxy/haproxy-redis.cfg.template.production`

Operator contract updated:

- `FoodPulse/.env.example`
- `FoodPulse/README.md`
- `FoodPulse/scripts/start.sh`
- `FoodPulse/scripts/cluster-status.sh`
- `FoodPulse/scripts/pg-failover-drill.sh`
- `FoodPulse/scripts/redis-failover-drill.sh`
- `FoodPulse/command.sh`
- `WORKSPACE-SETUP-MATRIX.md`
- `WORKSPACE-ARCHITECTURE.md`

### Validation

Successful checks:

- `npm ci` and `npm run build` in `FoodPulse/ui`
- `npm ci` in `FoodPulse/api`
- `bash -n` on the FoodPulse scripts and replica bootstrap
- `docker compose -f FoodPulse/docker-compose.yml config`
- `curl -fsS http://localhost:8090/api/getstats`
- `curl -fsS http://localhost:8090/api/venues`
- `curl -fsS http://localhost:8090/health`
- `curl -fsS -X POST http://localhost:8090/api/vote -H 'Content-Type: application/json' -d '{"venueSlug":"greenhouse-kitchen"}'`
- `curl -fsS http://localhost:8090/api/getvotes`
- `./Obervability-Stack/scripts/foodpulse-audit.sh`
- `./Obervability-Stack/scripts/foodpulse-live-audit.sh`

### Why This Mattered

This was the real ownership cutover for `FoodPulse`.

The repo is no longer a rebranded wrapper around inherited application code.
It now contains:

- a modern app we own
- a clearer UI/API boundary for future Kubernetes Services
- explicit health and metrics surfaces
- the same HA lab value underneath

That makes `FoodPulse` much stronger both as a demo app and as a platform-engineering case study.

---

## Phase 4: Onboarding Template And Operator Matrix

### Why We Did This

Phase 4 is supposed to make onboarding repeatable, visible, and useful.

At this point we already had:

- inventory validation
- control-plane smoke checks
- app-specific contract audits
- app-specific live audits

What we did not yet have was the shared operator layer that explains how a new or existing workload should fit into the platform without reverse-engineering four different examples.

That gap would make a sixth app feel improvised, which is exactly what Phase 4 is meant to prevent.

### Commands Run

```bash
sed -n '1,260p' PROJECT-ROADMAP.md
git status --short
rg -n "Phase 4|Phase 3|Current Focus|in progress|complete" JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md WORKSPACE-HYGIENE-CHECKLIST.md
sed -n '300,430p' PROJECT-ROADMAP.md
ls -1 Obervability-Stack/scripts
sed -n '1,260p' Obervability-Stack/scripts/devops-monitor.sh
sed -n '1,260p' Obervability-Stack/scripts/README.md
sed -n '1,260p' Obervability-Stack/ui-next/lib/monitored-apps.ts
sed -n '1,240p' WORKSPACE-SETUP-MATRIX.md
sed -n '1,260p' Obervability-Stack/docs/WORKSPACE_APP_INVENTORY_AUDIT.md
sed -n '1,260p' Obervability-Stack/docs/README.md
tail -n 80 JOURNEY-RUNBOOK.md
find Obervability-Stack/docs -maxdepth 1 -type f | sort
```

### What We Added

We added two new Phase 4 documents:

- `Obervability-Stack/docs/APP_ONBOARDING_TEMPLATE.md`
- `Obervability-Stack/docs/OPERATOR_APP_MATRIX.md`

We also updated:

- `Obervability-Stack/docs/README.md`
- `PROJECT-ROADMAP.md`

### Why These Changes Matter

`APP_ONBOARDING_TEMPLATE.md` captures the reusable app contract:

- startup contract
- browser contract
- health contract
- alias contract
- inventory contract
- metrics and logs expectations
- Kubernetes-readiness lens

`OPERATOR_APP_MATRIX.md` captures the operator-facing reality of the current managed workloads:

- what each app demonstrates
- how to start it
- what health check matters most
- which audit and live audit to run
- why the app is interesting from a platform perspective

### Outcome

This is the first Phase 4 slice that turns earlier audit work into a reusable onboarding model instead of repo-specific knowledge.

That makes the platform story more transferable and gives us a cleaner bridge into Phase 5 incident and workflow work later.

---

## Phase 4: OpenSIS Operator Guide In The Control Plane

### Why We Did This

Phase 4 is not only about getting apps into the platform.
It is also about making the platform useful once the app is there.

The dashboard already had an OpenSIS-specific latency, uptime, logs, and alert view.
What it did not yet have was the operator layer:

- where to look first
- which dependency matters next
- which command to run before guessing

That meant the control plane still depended too heavily on repo docs for first-response work.

### Commands Run

```bash
rg -n "apps/\\[appId\\]|overview|runbook|opensis|vault|health" Obervability-Stack/ui-next/app Obervability-Stack/ui-next/lib Obervability-Stack/ui-next/components -g '!**/node_modules/**'
sed -n '1,240p' 'Obervability-Stack/ui-next/app/api/apps/[appId]/overview/route.ts'
find Obervability-Stack/ui-next/app -maxdepth 4 | sort | rg '/apps|dashboard|services'
sed -n '1,260p' Obervability-Stack/ui-next/lib/app-observability.ts
sed -n '1,220p' Obervability-Stack/ui-next/app/dashboard/page.tsx
sed -n '220,380p' Obervability-Stack/ui-next/app/dashboard/page.tsx
sed -n '1,220p' OpenSIS/README.md
sed -n '1,260p' OpenSIS/docs/06-architecture-reference.md
sed -n '1,220p' OpenSIS/docs/04-operations-runbook.md
sed -n '1,240p' OpenSIS/docs/05-troubleshooting-guide.md
git diff -- Obervability-Stack/ui-next/app/dashboard/page.tsx | sed -n '1,260p'
npm run type-check
```

### What We Changed

We extended the main control-plane dashboard in:

- `Obervability-Stack/ui-next/app/dashboard/page.tsx`

The new dashboard slice adds:

- an OpenSIS operator summary banner driven by the live OpenSIS overview state
- dependency-oriented quick checks for:
  - browser path
  - Vault health
  - MariaDB state
  - the local wrapper startup path
- first-response command blocks
- guidance on how to interpret common OpenSIS failure shapes

### Why This Matters

This turns the control plane from "OpenSIS is up or down" into "here is how to respond when it is not healthy."

That is a stronger Phase 4 outcome because:

- the control plane now carries more of the operator workflow itself
- the OpenSIS integration is more than charts and logs
- the next Phase 5 incident work can build on a real operator panel instead of starting from scratch

---

## Phase 4: FoodPulse Failover Guide In The Control Plane

### Why We Did This

`FoodPulse` is the resilience lab in this workspace.

That means a useful control-plane integration is not only:

- "is the app up?"

It also has to answer:

- when should I trust the browser path?
- when should I run `cluster-status.sh`?
- when is a Redis drill appropriate?
- when is a Postgres drill intentionally disruptive?

Without that layer, `FoodPulse` would still be visible in the platform, but not well explained by it.

### Commands Run

```bash
git status --short
sed -n '1,260p' FoodPulse/README.md
sed -n '1,260p' FoodPulse/scripts/cluster-status.sh
sed -n '1,260p' FoodPulse/scripts/redis-failover-drill.sh
sed -n '1,260p' FoodPulse/scripts/pg-failover-drill.sh
sed -n '220,320p' Obervability-Stack/ui-next/lib/monitored-apps.ts
sed -n '360,980p' Obervability-Stack/ui-next/app/dashboard/page.tsx
curl -fsS http://localhost:4000/api/apps/foodpulse/overview | jq '.app.id, .health.status, (.alerts|length), (.recentLogs|length)'
./Obervability-Stack/scripts/foodpulse-live-audit.sh
npm run type-check
```

### What We Changed

We extended:

- `Obervability-Stack/ui-next/app/dashboard/page.tsx`

The new dashboard slice adds:

- a FoodPulse operator summary driven by the live FoodPulse overview state
- quick checks for:
  - browser path
  - cluster baseline
  - Redis failover drill
  - Postgres promotion drill
- first-response command blocks
- guidance on how to interpret FoodPulse lab failures

### Why This Matters

This gives `FoodPulse` a real operator story inside the control plane.

The dashboard now explains that:

- browser reachability comes first
- `cluster-status.sh` is the baseline truth for lab health
- Redis failover drills are the cleaner resilience exercise
- Postgres promotion drills are educational but intentionally disruptive

That is a much better Phase 4 integration than a simple uptime tile.

---

## Phase 4: MemFlip Onboarding Guide In The Control Plane

### Why We Did This

`MemFlip` is supposed to be the easiest onboarding example in the workspace.

That means the control plane should show the exact path we want future browser-first apps to follow:

- frontend-proxied health
- backend fallback health
- synthetic user flow
- backend metrics confirmation

Without that, `MemFlip` would be present in the platform but not fully useful as the reference onboarding model.

### Commands Run

```bash
git status --short
sed -n '1,260p' MemFlip/README.md
sed -n '1,220p' MemFlip/docs/local/README.md
sed -n '1,220p' MemFlip/docs/local/02-compose.md
sed -n '1,260p' Obervability-Stack/scripts/memflip-live-audit.sh
curl -fsS http://localhost:4000/api/apps/memflip/overview | jq '.app.id, .health.status, (.alerts|length), (.recentLogs|length)'
npm run type-check
./Obervability-Stack/scripts/memflip-live-audit.sh
```

### What We Changed

We extended:

- `Obervability-Stack/ui-next/app/dashboard/page.tsx`

The new dashboard slice adds:

- a MemFlip operator summary driven by live MemFlip overview state
- quick checks for:
  - frontend proxy health
  - backend API health
  - synthetic game flow
  - backend metrics
- first-response command blocks
- guidance on how to interpret MemFlip onboarding failures

### Why This Matters

This completes the current Phase 4 deepening pattern across the managed workloads.

The control plane now explains:

- OpenSIS as the legacy-platform case
- FoodPulse as the failover lab
- MemFlip as the clean onboarding reference

That gives us a much stronger handoff into Phase 5, because the dashboard now contains operator-oriented guidance for all the main workload stories instead of only generic health state.

---

## Phase 4 Correction: SwiftPay Operator Guidance

### Why We Did This

SwiftPay already had the strongest workload-specific dashboard section through `SwiftPay Money Flow`.

That section was useful because it explained:

- pending transactions
- pending amount
- queue depth
- completed transfers
- wallet circuit state
- failure rates

But it was not the same thing as an operator guide.

The missing piece was first-response guidance:

- what to check when the gateway is down
- what to do when queue depth rises
- how to interpret a flat completed-transfer signal
- why an open wallet circuit is a downstream-protection event

The user called this out before we moved deeper into Phase 5, and that was the right correction.

### Commands Run

```bash
git status --short
sed -n '1,260p' SwiftPay/docs/observability-runbook.md
sed -n '1,280p' Obervability-Stack/scripts/swiftpay-live-audit.sh
rg -n "SwiftPay Money Flow|MemFlip Onboarding Guide|FoodPulse Failover Guide|OpenSIS Operator Guide|get.*OperatorSummary|swiftpayMetrics" Obervability-Stack/ui-next/app/dashboard/page.tsx
sed -n '480,660p' Obervability-Stack/ui-next/app/dashboard/page.tsx
sed -n '740,850p' Obervability-Stack/ui-next/app/dashboard/page.tsx
sed -n '360,450p' PROJECT-ROADMAP.md
```

### What We Changed

We extended:

- `Obervability-Stack/ui-next/app/dashboard/page.tsx`

The new SwiftPay operator panel adds:

- live SwiftPay overview fetching through `/api/apps/swiftpay/overview`
- an operator summary driven by both app health and business metrics
- quick checks for:
  - gateway path
  - async worker path
  - positive completed-transfer signal
  - wallet circuit protection
- first-response command blocks
- failure interpretation guidance

We also updated:

- `PROJECT-ROADMAP.md`
- `Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md`

### Why This Matters

This closes the gap in the Phase 4 dashboard pattern.

The control plane now gives operator-style guidance for:

- SwiftPay
- OpenSIS
- FoodPulse
- MemFlip

That makes the Phase 5 handoff cleaner because the flagship app is no longer treated as "metrics only" while the other workloads have explicit operator guidance.

---

## Phase 5: Operator Workflow Entry Point And Incident Matrix

### Why We Did This

At this point, the current bottleneck is no longer app onboarding.

We now have:

- static and live audits across the managed workloads
- operator-oriented dashboard guidance for the main workload stories
- a reusable onboarding template
- an operator-facing app matrix

That means the next useful step is to give operators one standard first-response workflow and one small incident vocabulary instead of making them remember a different starting pattern for every app.

### Commands Run

```bash
sed -n '1,220p' PROJECT-ROADMAP.md
sed -n '300,520p' PROJECT-ROADMAP.md
git status --short
rg -n "Phase 5|operator workflow|incident|drill|runbook" JOURNEY-RUNBOOK.md Obervability-Stack/docs -g '!**/node_modules/**'
sed -n '260,520p' Obervability-Stack/scripts/devops-monitor.sh
sed -n '1,260p' Obervability-Stack/scripts/health-check.sh
sed -n '1,220p' Obervability-Stack/scripts/inventory-audit.sh
curl -fsS http://localhost:4000/api/apps/health | jq .
```

### What We Added

We added:

- `Obervability-Stack/scripts/operator-first-check.sh`
- `Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md`
- `Obervability-Stack/docs/INCIDENT_MATRIX.md`

We also updated:

- `Obervability-Stack/scripts/devops-monitor.sh`
- `Obervability-Stack/scripts/README.md`
- `Obervability-Stack/docs/README.md`
- `PROJECT-ROADMAP.md`

### Why These Changes Matter

The new `operator` command gives the workspace one repeatable first-response entrypoint:

- smoke-check the control plane
- validate the monitored app inventory
- print the workspace app-health snapshot

The new docs establish the first real Phase 5 artifacts:

- the standard health workflow
- the first incident matrix

### Outcome

This is the point where the roadmap legitimately moves from Phase 4 into Phase 5.

The platform is no longer only teaching how apps join the control plane.
It is now starting to teach how operators should respond when the platform looks wrong.

---

## Phase 5: SwiftPay Operator Runbook

### Why We Did This

After adding the shared operator workflow and incident matrix, the next useful step was to make the pattern concrete for one real app.

SwiftPay is the right first workload because it has the richest operational story:

- multiple services
- a browser frontend
- an API gateway
- PostgreSQL, Redis, and RabbitMQ dependencies
- async transaction processing
- business metrics
- circuit-breaker behavior

This runbook becomes the template we can carry into MemFlip, OpenSIS, and FoodPulse.

### Commands Run

```bash
rg --files SwiftPay Obervability-Stack/docs Obervability-Stack/scripts | sort
git status --short
sed -n '1,220p' PROJECT-ROADMAP.md
sed -n '1,240p' Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md
sed -n '1,240p' Obervability-Stack/docs/README.md
sed -n '1,260p' Obervability-Stack/docs/OPERATOR_APP_MATRIX.md
sed -n '1,240p' SwiftPay/docker-compose.yml
sed -n '1,220p' Obervability-Stack/scripts/swiftpay-live-audit.sh
sed -n '220,520p' SwiftPay/docker-compose.yml
sed -n '220,520p' Obervability-Stack/scripts/swiftpay-live-audit.sh
sed -n '1,220p' Obervability-Stack/scripts/swiftpay-audit.sh
sed -n '1,180p' SwiftPay/docs/RUNBOOK.md
sed -n '180,420p' SwiftPay/docs/RUNBOOK.md
tail -n 180 JOURNEY-RUNBOOK.md
```

### What We Added

We added:

- `Obervability-Stack/docs/SWIFTPAY_OPERATOR_RUNBOOK.md`

The runbook documents:

- what SwiftPay does
- startup commands
- health checks
- ports and URLs
- service roles
- metrics to watch
- logs to check
- common failure scenarios
- recovery commands
- Kubernetes mapping
- deeper SwiftPay docs to consult

### What We Updated

We updated:

- `Obervability-Stack/docs/README.md`
- `Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md`
- `PROJECT-ROADMAP.md`
- `JOURNEY-RUNBOOK.md`

### Why This Matters

The platform now has its first full app operator runbook.

This matters because dashboard panels and live audits are good at saying what is happening, but runbooks teach the operator what to do next and why.

The SwiftPay runbook also keeps the Kubernetes future in view by mapping Docker Compose operations to `kubectl` operations without forcing us to migrate yet.

---

## Phase 5: MemFlip Operator Runbook

### Why We Did This

After SwiftPay, we carried the same operator-runbook pattern into MemFlip.

MemFlip is the right second workload because it is intentionally simpler:

- one browser frontend
- one backend API
- Postgres and Redis dependencies
- a synthetic game flow
- direct backend metrics

This gives us a clean operator contrast:

- SwiftPay teaches complex microservice and async money-flow operations.
- MemFlip teaches the smallest complete onboarding and browser-first validation path.

### Commands Run

```bash
rg --files MemFlip Obervability-Stack/docs Obervability-Stack/scripts | sort
git status --short
sed -n '1,260p' MemFlip/docker-compose.yml
sed -n '1,260p' Obervability-Stack/scripts/memflip-live-audit.sh
sed -n '260,520p' Obervability-Stack/scripts/memflip-live-audit.sh
sed -n '1,260p' Obervability-Stack/scripts/memflip-audit.sh
sed -n '1,240p' MemFlip/README.md
sed -n '1,240p' MemFlip/docs/local/02-compose.md
sed -n '1,220p' MemFlip/docs/troubleshooting.md
git diff --check -- JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md Obervability-Stack/docs/MEMFLIP_OPERATOR_RUNBOOK.md
rg -n "MEMFLIP_OPERATOR_RUNBOOK|MemFlip Operator Runbook|memflip-live|localhost:8080|localhost:3101|game_scores_total|kubectl" Obervability-Stack/docs/MEMFLIP_OPERATOR_RUNBOOK.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md
git diff --stat -- JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md Obervability-Stack/docs/MEMFLIP_OPERATOR_RUNBOOK.md
git status --short
./Obervability-Stack/scripts/devops-monitor.sh memflip
./Obervability-Stack/scripts/devops-monitor.sh memflip-live
```

### What We Added

We added:

- `Obervability-Stack/docs/MEMFLIP_OPERATOR_RUNBOOK.md`

The runbook documents:

- what MemFlip does
- startup commands
- health checks
- ports and URLs
- service roles
- metrics to watch
- logs to check
- common failure scenarios
- recovery commands
- Kubernetes mapping
- deeper MemFlip docs to consult

### What We Updated

We updated:

- `Obervability-Stack/docs/README.md`
- `Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md`
- `PROJECT-ROADMAP.md`
- `JOURNEY-RUNBOOK.md`

### Why This Matters

The platform now has app operator runbooks for both ends of the current workload spectrum:

- a complex flagship microservices app
- a simple onboarding/reference app

That makes the next runbooks easier because the pattern is no longer theoretical. We can adapt it to OpenSIS for legacy-platform operations and FoodPulse for resilience/failover operations.

---

## Phase 5: OpenSIS Operator Runbook

### Why We Did This

After SwiftPay and MemFlip, we carried the operator-runbook pattern into OpenSIS.

OpenSIS is the right third workload because it teaches the legacy-platform story:

- a large PHP/MariaDB application
- local Docker Compose startup sequencing
- Vault bootstrap and seed behavior
- Vault Agent rendered secrets
- MariaDB health and credential drift
- blackbox monitoring rather than rich app-native business metrics
- a serious Kubernetes/GitOps path around a stateful legacy system

### Commands Run

```bash
rg --files OpenSIS Obervability-Stack/docs Obervability-Stack/scripts | sort
git status --short
sed -n '1,260p' Obervability-Stack/scripts/opensis-live-audit.sh
sed -n '1,260p' Obervability-Stack/scripts/opensis-audit.sh
sed -n '1,260p' OpenSIS/docker-compose.yaml
sed -n '1,220p' OpenSIS/scripts/compose-start.sh
sed -n '1,260p' OpenSIS/README.md
sed -n '1,240p' OpenSIS/docs/04-operations-runbook.md
sed -n '260,620p' OpenSIS/docker-compose.yaml
sed -n '240,520p' OpenSIS/docs/04-operations-runbook.md
sed -n '1,260p' OpenSIS/docs/05-troubleshooting-guide.md
sed -n '1,220p' OpenSIS/.env.example
git diff --check -- JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md Obervability-Stack/docs/OPENSIS_OPERATOR_RUNBOOK.md
rg -n "OPENSIS_OPERATOR_RUNBOOK|OpenSIS Operator Runbook|opensis-live|localhost:8088|localhost:8200|probe_success|Vault|MariaDB|kubectl" Obervability-Stack/docs/OPENSIS_OPERATOR_RUNBOOK.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md
git diff --stat -- JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md Obervability-Stack/docs/OPENSIS_OPERATOR_RUNBOOK.md
git status --short
./Obervability-Stack/scripts/devops-monitor.sh opensis
./Obervability-Stack/scripts/devops-monitor.sh opensis-live
```

### What We Added

We added:

- `Obervability-Stack/docs/OPENSIS_OPERATOR_RUNBOOK.md`

The runbook documents:

- what OpenSIS does
- startup commands
- health checks
- ports and URLs
- service roles
- Vault and MariaDB dependency checks
- blackbox probe expectations
- logs to check
- common failure scenarios
- recovery commands
- Kubernetes mapping
- deeper OpenSIS docs to consult

### What We Updated

We updated:

- `Obervability-Stack/docs/README.md`
- `Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md`
- `PROJECT-ROADMAP.md`
- `JOURNEY-RUNBOOK.md`

### Why This Matters

The platform now has operator runbooks for three distinct workload patterns:

- SwiftPay for microservices and async business flows
- MemFlip for simple onboarding and browser-first validation
- OpenSIS for legacy-platform operations with Vault and MariaDB

This makes the remaining FoodPulse runbook easier to position as the resilience and failover story.

---

## Phase 5: FoodPulse Operator Runbook

### Why We Did This

After SwiftPay, MemFlip, and OpenSIS, we carried the operator-runbook pattern into FoodPulse.

FoodPulse is the right fourth workload because it completes the app-level runbook set with the resilience/failover story:

- a modern owned UI and API
- Postgres primary/replica topology
- Redis master/replica topology with Sentinel
- HAProxy routing for Postgres and Redis
- central blackbox monitoring through the shared observability stack
- explicit Redis and Postgres failover drills

### Commands Run

```bash
rg --files FoodPulse Obervability-Stack/docs Obervability-Stack/scripts | sort
git status --short
sed -n '1,280p' Obervability-Stack/scripts/foodpulse-live-audit.sh
sed -n '1,260p' Obervability-Stack/scripts/foodpulse-audit.sh
sed -n '1,320p' FoodPulse/docker-compose.yml
sed -n '1,260p' FoodPulse/README.md
sed -n '1,260p' FoodPulse/scripts/cluster-status.sh
sed -n '1,260p' FoodPulse/scripts/start.sh
sed -n '260,560p' FoodPulse/scripts/cluster-status.sh
sed -n '1,260p' FoodPulse/scripts/redis-failover-drill.sh
sed -n '1,280p' FoodPulse/scripts/pg-failover-drill.sh
git diff --check -- JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md Obervability-Stack/docs/FOODPULSE_OPERATOR_RUNBOOK.md
rg -n "FOODPULSE_OPERATOR_RUNBOOK|FoodPulse Operator Runbook|foodpulse-live|localhost:8090|cluster-status|redis-failover|pg-failover|probe_success|kubectl" Obervability-Stack/docs/FOODPULSE_OPERATOR_RUNBOOK.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md
git diff --stat -- JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md Obervability-Stack/docs/FOODPULSE_OPERATOR_RUNBOOK.md
git status --short
./Obervability-Stack/scripts/devops-monitor.sh foodpulse
./Obervability-Stack/scripts/devops-monitor.sh foodpulse-live
```

### What We Added

We added:

- `Obervability-Stack/docs/FOODPULSE_OPERATOR_RUNBOOK.md`

The runbook documents:

- what FoodPulse does
- startup commands
- health checks
- ports and URLs
- service roles
- Postgres and Redis HA topology checks
- blackbox probe expectations
- logs to check
- common failure scenarios
- Redis and Postgres failover drill guidance
- recovery commands
- Kubernetes mapping
- deeper FoodPulse docs and scripts to consult

### What We Updated

We updated:

- `Obervability-Stack/docs/README.md`
- `Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md`
- `PROJECT-ROADMAP.md`
- `JOURNEY-RUNBOOK.md`

### Why This Matters

The platform now has operator runbooks for all four managed workload patterns:

- SwiftPay for microservices and async business flows
- MemFlip for simple onboarding and browser-first validation
- OpenSIS for legacy-platform operations with Vault and MariaDB
- FoodPulse for resilience, failover, and HA topology reasoning

This closes the first major app-runbook milestone in Phase 5.

### Validation

The documentation checks passed with no whitespace errors.

The FoodPulse static audit passed:

- `21/21` checks
- compose and inventory contracts aligned
- browser URL and startup path matched the control plane
- FoodPulse remained free of duplicate local Prometheus, Grafana, and Alertmanager services
- central Prometheus blackbox target was present
- cluster-status helper used the normalized browser port and HAProxy container names

The FoodPulse live audit passed:

- `16/16` checks
- FoodPulse responded on `localhost:8090`
- stats endpoint returned app telemetry through the UI proxy
- control plane saw FoodPulse as healthy
- Prometheus saw FoodPulse blackbox target health and all targets were up
- `cluster-status.sh` reported a healthy lab

### Validation

The documentation checks passed with no whitespace errors.

The OpenSIS static audit passed:

- `26/26` checks
- compose files and startup helper were present
- OpenSIS UI and Vault port publishing matched the control-plane contract
- build-local startup path was documented and wired
- Prometheus blackbox target and `app=opensis` label were present
- MariaDB credential environment contract was present

The OpenSIS live audit passed:

- `18/18` checks
- OpenSIS responded on `localhost:8088`
- OpenSIS root page returned HTML with application branding
- Vault health endpoint responded
- Vault reported initialized and unsealed
- control plane saw OpenSIS as healthy
- Prometheus saw OpenSIS blackbox targets and all were up

### Validation

The documentation checks passed with no whitespace errors.

The MemFlip static audit passed:

- `24/24` checks
- compose aliases and control-plane inventory aligned
- expected host ports documented
- Prometheus blackbox targets present
- backend `/health`, `/api/health`, and `/metrics` surfaces present

The MemFlip live audit passed:

- `34/34` checks
- frontend proxy health passed
- backend health passed
- control plane saw MemFlip as healthy
- synthetic user creation passed
- synthetic game start, match, complete, leaderboard, and stats flow passed
- backend metrics recorded the synthetic game flow

---

## Phase 5: Incident Drill Catalog

### Why We Did This

After building platform-facing operator runbooks for SwiftPay, MemFlip, OpenSIS, and FoodPulse, the next Phase 5 step was to connect those runbooks to intentional break/fix practice.

Healthy apps are useful, but an operations lab becomes much more real when it can teach:

- what to break
- how to detect it
- which evidence matters
- how to recover safely
- how the same thinking maps to Kubernetes later

We added the first incident drill catalog as documentation only. We did not intentionally stop services during this step.

### Commands Run

```bash
sed -n '1,260p' Obervability-Stack/docs/INCIDENT_MATRIX.md
sed -n '1,180p' Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md
sed -n '1,220p' PROJECT-ROADMAP.md
git status --short
sed -n '1,80p' Obervability-Stack/docs/README.md
tail -n 220 JOURNEY-RUNBOOK.md
rg -n "## Phase 5|Operator workflows|incident drills|Current Status|Deliverables|Success Criteria" PROJECT-ROADMAP.md
sed -n '397,475p' PROJECT-ROADMAP.md
git diff --check -- JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md Obervability-Stack/docs/INCIDENT_MATRIX.md Obervability-Stack/docs/INCIDENT_DRILLS.md
rg -n "INCIDENT_DRILLS|Incident Drill Catalog|transaction worker|Redis Failover|Postgres Promotion|selected drills|drill catalog" Obervability-Stack/docs/INCIDENT_DRILLS.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md Obervability-Stack/docs/INCIDENT_MATRIX.md PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md
./Obervability-Stack/scripts/devops-monitor.sh operator
git diff --stat -- JOURNEY-RUNBOOK.md PROJECT-ROADMAP.md Obervability-Stack/docs/README.md Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md Obervability-Stack/docs/INCIDENT_MATRIX.md Obervability-Stack/docs/INCIDENT_DRILLS.md
```

### What We Added

We added:

- `Obervability-Stack/docs/INCIDENT_DRILLS.md`

The catalog includes controlled drills for:

- SwiftPay transaction worker failure
- SwiftPay wallet service failure
- SwiftPay RabbitMQ failure
- MemFlip backend failure
- MemFlip metrics-missing behavior
- OpenSIS Vault failure
- OpenSIS MariaDB failure
- OpenSIS blackbox mismatch
- FoodPulse Redis failover
- FoodPulse Postgres promotion
- FoodPulse app-healthy/topology-degraded behavior
- control-plane probe or inventory drift

### What We Updated

We updated:

- `Obervability-Stack/docs/README.md`
- `Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md`
- `Obervability-Stack/docs/INCIDENT_MATRIX.md`
- `PROJECT-ROADMAP.md`
- `JOURNEY-RUNBOOK.md`

### Why This Matters

This turns the Phase 5 runbooks into a training loop.

The platform now has:

- first-response workflow
- symptom matrix
- app operator runbooks
- controlled drill catalog

The remaining Phase 5 work is to execute selected drills for real, recover them, and record the evidence.

### Validation

The documentation checks passed with no whitespace errors.

The operator baseline passed without intentionally breaking any workload:

- control-plane smoke check passed `26/26`
- inventory validation passed with `0` errors and `0` warnings
- workspace app snapshot reported `4` total apps
- all `4` managed apps were healthy
- OpenSIS, SwiftPay, MemFlip, and FoodPulse all had healthy primary endpoints

We intentionally did not run the break/fix drills in this checkpoint. The next step is to execute selected drills one at a time, capture evidence, recover, and record the outcome.

---

## Incident Drill: MemFlip Backend Down

### Goal

Prove that the platform can detect and recover from a simple application backend failure.

This was selected as the first real drill because it has a small blast radius:

- no volumes are removed
- no database topology is changed
- only one backend service is stopped
- recovery is a normal `docker compose start backend`

### Commands Run

```bash
git status --short
./Obervability-Stack/scripts/devops-monitor.sh memflip-live
cd MemFlip && docker compose stop backend
./Obervability-Stack/scripts/devops-monitor.sh memflip-live
curl -fsS http://localhost:4000/api/apps/health | jq '.apps[] | select(.appId=="memflip")'
cd MemFlip && docker compose ps backend frontend
curl --max-time 5 -sS -o /tmp/memflip_frontend_health.out -w 'frontend_health_http=%{http_code}\n' http://localhost:8080/api/health
sed -n '1,80p' /tmp/memflip_frontend_health.out
curl --max-time 5 -sS -o /tmp/memflip_backend_health.out -w 'backend_health_http=%{http_code}\n' http://localhost:3101/health
sed -n '1,80p' /tmp/memflip_backend_health.out
cd MemFlip && docker compose logs --tail=80 backend frontend
cd MemFlip && docker compose start backend
./Obervability-Stack/scripts/devops-monitor.sh memflip-live
curl --max-time 10 -fsS http://localhost:8080/api/health | jq '.status'
cd MemFlip && docker compose ps backend frontend
sleep 20; ./Obervability-Stack/scripts/devops-monitor.sh memflip-live
sleep 20; curl -fsS http://localhost:4000/api/apps/health | jq '.apps[] | select(.appId=="memflip") | {status, endpoints: [.endpoints[] | {id, status, probeSuccess, lastChecked}]}'
./Obervability-Stack/scripts/devops-monitor.sh operator
```

### Baseline

Before breaking anything, MemFlip live audit passed:

- `34/34` checks
- frontend proxy health was healthy
- backend health was healthy
- synthetic game flow passed
- backend metrics checks passed
- control plane saw MemFlip as healthy

### Trigger

We stopped the MemFlip backend:

```bash
cd MemFlip
docker compose stop backend
```

Docker stopped:

- `humor-game-backend`

The frontend stayed up:

- `humor-game-frontend`

### Detection

The live audit detected the failure.

The first failed check was:

```text
FAIL MemFlip frontend health endpoint is unreachable
```

The direct frontend proxy health check returned:

```text
frontend_health_http=502
```

The response body was the Nginx `502 Bad Gateway` page.

The direct backend health check returned:

```text
backend_health_http=000
curl: (7) Failed to connect to localhost port 3101
```

The frontend logs explained the failure:

```text
connect() failed (113: Host is unreachable) while connecting to upstream
```

### Important Observation

Immediately after stopping the backend, the control-plane app health endpoint still showed MemFlip as healthy.

That was not because the app was healthy. It was because the control plane was still reporting the most recent blackbox probe result.

This is an important operator lesson:

- live audits detect direct failure faster
- control-plane probe state can lag by one scrape/probe interval
- operators should compare direct app checks with control-plane state before deciding what is true

### Recovery

We restarted the backend:

```bash
cd MemFlip
docker compose start backend
```

Docker waited for dependencies and started:

- `humor-game-postgres`
- `humor-game-redis`
- `humor-game-backend`

Direct health recovered quickly:

```bash
curl --max-time 10 -fsS http://localhost:8080/api/health | jq '.status'
```

Returned:

```json
"healthy"
```

### Post-Recovery Observation

The first post-recovery MemFlip live audit passed direct app checks and synthetic game checks, but failed one control-plane check:

```text
FAIL Control plane sees MemFlip as healthy
Checks passed: 33/34
```

That happened because the app had recovered before the control plane probe state refreshed.

After waiting for the probe refresh interval, MemFlip live audit passed again:

- `34/34` checks

The control plane then reported:

```json
{
  "status": "healthy",
  "endpoints": [
    {
      "id": "memflip-frontend",
      "status": "up",
      "probeSuccess": 1
    },
    {
      "id": "memflip-backend",
      "status": "up",
      "probeSuccess": 1
    }
  ]
}
```

### Final Verification

The full operator baseline passed after recovery:

- control-plane smoke check passed `26/26`
- inventory validation passed with `0` errors and `0` warnings
- workspace app snapshot reported `4` total apps
- all `4` managed apps were healthy
- OpenSIS, SwiftPay, MemFlip, and FoodPulse all had healthy primary endpoints

### Lessons

This drill taught three useful platform lessons:

- Direct live audits are the fastest way to prove app failure.
- Control-plane health is still valuable, but it can lag behind real-time app state.
- Recovery verification should include both direct app checks and a delayed control-plane check.

### Kubernetes Mapping

In Kubernetes, the equivalent drill would be:

```bash
kubectl scale deployment/backend --replicas=0 -n humor-game
kubectl scale deployment/backend --replicas=1 -n humor-game
kubectl rollout status deployment/backend -n humor-game
```

The same operator lesson applies in Kubernetes: pod/service readiness, ingress behavior, and Prometheus/blackbox state may not update at exactly the same moment.

---

## Incident Drill: SwiftPay Transaction Worker Down

### Goal

Prove that the platform can detect and recover from a SwiftPay transaction-service outage.

This drill was selected second because it moves the incident practice from a simple backend outage into a microservices money-flow path.

The expected learning goal was to observe async processing failure. The actual failure happened earlier: transfer creation returned HTTP `500` because the API gateway could not resolve the stopped transaction-service container.

### Commands Run

```bash
git status --short
./Obervability-Stack/scripts/devops-monitor.sh swiftpay-live
cd SwiftPay && docker compose ps transaction-service api-gateway wallet-service rabbitmq
cd SwiftPay && docker compose stop transaction-service
./Obervability-Stack/scripts/devops-monitor.sh swiftpay-live
curl -fsS http://localhost:4000/api/apps/swiftpay/business | jq '.metrics'
cd SwiftPay && docker compose ps transaction-service api-gateway wallet-service rabbitmq
cd SwiftPay && docker compose logs --tail=120 api-gateway transaction-service rabbitmq
curl -fsS http://localhost:4000/api/apps/health | jq '.apps[] | select(.appId=="swiftpay") | {status, endpoints: [.endpoints[] | {id, status, probeSuccess, lastChecked}]}'
curl --max-time 5 -sS -o /tmp/swiftpay_tx_health.out -w 'transaction_health_http=%{http_code}\n' http://localhost:3008/health
sed -n '1,80p' /tmp/swiftpay_tx_health.out
cd SwiftPay && docker compose start transaction-service
./Obervability-Stack/scripts/devops-monitor.sh swiftpay-live
curl --max-time 10 -fsS http://localhost:3008/health | jq '.status'
cd SwiftPay && docker compose ps transaction-service api-gateway wallet-service rabbitmq
sleep 30; ./Obervability-Stack/scripts/devops-monitor.sh swiftpay-live
sleep 30; curl -fsS http://localhost:4000/api/apps/health | jq '.apps[] | select(.appId=="swiftpay") | {status, endpoints: [.endpoints[] | {id, status, probeSuccess, lastChecked}]}'
sleep 30; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=up{job="swiftpay-transaction-service"}' | jq '.data.result'
./Obervability-Stack/scripts/devops-monitor.sh operator
```

### Baseline

Before the drill, SwiftPay live audit passed:

- `44/44` checks
- gateway health passed
- frontend health passed
- control plane saw SwiftPay as healthy
- all five SwiftPay Prometheus metric jobs were up
- synthetic transfer completed successfully
- completed-transfer metrics were present

The relevant services were healthy:

- `swiftpay-api-gateway-1`
- `swiftpay-rabbitmq-1`
- `swiftpay-transaction-service-1`
- `swiftpay-wallet-service-1`

### Trigger

We stopped only the transaction service:

```bash
cd SwiftPay
docker compose stop transaction-service
```

Docker stopped:

- `swiftpay-transaction-service-1`

The gateway, RabbitMQ, and wallet service stayed up.

### Detection

The first post-trigger SwiftPay live audit failed during synthetic transfer creation:

```text
curl: (22) The requested URL returned error: 500
FAIL Synthetic transfer request failed
```

The API gateway logged the root cause:

```text
Transaction failed: getaddrinfo ENOTFOUND transaction-service
```

Direct transaction service health failed:

```text
transaction_health_http=000
curl: (7) Failed to connect to localhost port 3008
```

The control plane refreshed shortly after and reported SwiftPay as degraded:

```json
{
  "status": "degraded",
  "endpoints": [
    {
      "id": "swiftpay-transaction-service",
      "status": "down",
      "probeSuccess": 0
    }
  ]
}
```

### Important Observation

This was not a queue-backlog incident.

Because the transaction API service itself was stopped, the gateway could not create the transaction request at all. That means:

- no pending transfer was created
- queue depth stayed at `0`
- pending transaction metrics stayed at `0`
- the failure showed up as gateway-to-service dependency failure

That is a useful distinction for operators:

- worker logic broken after request acceptance can create queue or pending pressure
- service unavailable before request acceptance can produce gateway `500` errors instead

### Recovery

We restarted the transaction service:

```bash
cd SwiftPay
docker compose start transaction-service
```

Docker waited for dependencies and started:

- `swiftpay-redis-1`
- `swiftpay-postgres-1`
- `swiftpay-wallet-service-1`
- `swiftpay-rabbitmq-1`
- `swiftpay-transaction-service-1`

Direct health recovered quickly:

```bash
curl --max-time 10 -fsS http://localhost:3008/health | jq '.status'
```

Returned:

```json
"healthy"
```

### Post-Recovery Observation

The first post-recovery SwiftPay live audit still failed `39/44`.

The direct service was healthy and synthetic transfer completed, but control-plane and Prometheus checks still had stale state:

- control plane had not yet marked SwiftPay healthy
- Prometheus had not yet shown all SwiftPay metric jobs up
- completed-transfer metric checks had not yet caught the fresh sample

After waiting for the next probe and scrape interval, SwiftPay live audit passed:

- `44/44` checks

The control plane then showed all SwiftPay endpoints up, including:

```json
{
  "id": "swiftpay-transaction-service",
  "status": "up",
  "probeSuccess": 1
}
```

Prometheus also reported:

```json
{
  "job": "swiftpay-transaction-service",
  "value": "1"
}
```

### Final Verification

The full operator baseline passed after recovery:

- control-plane smoke check passed `26/26`
- inventory validation passed with `0` errors and `0` warnings
- workspace app snapshot reported `4` total apps
- all `4` managed apps were healthy
- OpenSIS, SwiftPay, MemFlip, and FoodPulse all had healthy primary endpoints

### Lessons

This drill taught four useful platform lessons:

- SwiftPay can fail in the gateway-to-service path before a queue backlog exists.
- A stopped transaction service makes synthetic transfer creation fail with HTTP `500`.
- Direct service health recovers before Prometheus and control-plane state necessarily refresh.
- Recovery verification needs both immediate direct checks and delayed probe/scrape checks.

### Kubernetes Mapping

In Kubernetes, the equivalent drill would be:

```bash
kubectl scale deployment/transaction-service --replicas=0 -n swiftpay
kubectl scale deployment/transaction-service --replicas=1 -n swiftpay
kubectl rollout status deployment/transaction-service -n swiftpay
```

The same lesson applies in Kubernetes: service DNS, pod readiness, Prometheus scrape status, and app-level synthetic transactions can disagree briefly during failure and recovery windows.

---

## Incident Drill: OpenSIS Vault Unavailable

### Goal

Prove that the OpenSIS live audit catches a secret-control-plane dependency outage even when the user-facing UI can still appear healthy.

This drill was selected third because it teaches an important operator distinction: application reachability is not the same thing as dependency readiness.

### Commands Run

```bash
git status --short
./Obervability-Stack/scripts/devops-monitor.sh opensis-live
cd OpenSIS && docker compose ps vault vault-agent-app vault-agent-db opensis-ui opensis-db
cd OpenSIS && docker compose stop vault
./Obervability-Stack/scripts/devops-monitor.sh opensis-live
curl --max-time 5 -sS -o /tmp/opensis_vault_health.out -w 'vault_health_http=%{http_code}\n' http://localhost:8200/v1/sys/health
sed -n '1,80p' /tmp/opensis_vault_health.out
curl --max-time 5 -sS -o /tmp/opensis_ui.out -w 'opensis_ui_http=%{http_code}\n' http://localhost:8088
sed -n '1,20p' /tmp/opensis_ui.out
cd OpenSIS && docker compose ps vault vault-agent-app vault-agent-db opensis-ui opensis-db
cd OpenSIS && docker compose logs --tail=120 vault vault-agent-app vault-agent-db opensis-ui opensis-db
curl -fsS http://localhost:4000/api/apps/health | jq '.apps[] | select(.appId=="opensis") | {status, endpoints: [.endpoints[] | {id, status, probeSuccess, lastChecked}]}'
curl --max-time 5 -sS -o /tmp/opensis_ui_head.out -w 'opensis_ui_head_http=%{http_code}\n' -I http://localhost:8088
sed -n '1,20p' /tmp/opensis_ui_head.out
cd OpenSIS && docker compose start vault
cd OpenSIS && docker compose ps vault vault-agent-app vault-agent-db opensis-ui opensis-db
curl -fsS http://localhost:8200/v1/sys/health
./Obervability-Stack/scripts/devops-monitor.sh opensis-live
curl -sS http://localhost:8200/v1/sys/health
cd OpenSIS && docker compose ps --all vault vault-bootstrap vault-agent-app vault-agent-db
rg -n "vault-bootstrap|sys/health|vault operator unseal|VAULT_TOKEN|unseal" OpenSIS Obervability-Stack PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md
cd OpenSIS && docker compose up vault-bootstrap
curl -fsS http://localhost:8200/v1/sys/health
./Obervability-Stack/scripts/devops-monitor.sh opensis-live
./Obervability-Stack/scripts/devops-monitor.sh operator
```

### Baseline

Before the drill, OpenSIS live audit passed:

- `18/18` checks
- OpenSIS responded on `localhost:8088`
- the root page returned HTML with OpenSIS branding
- Vault health responded
- Vault reported initialized and unsealed
- control plane saw OpenSIS as healthy
- Prometheus blackbox target health was up

The relevant services were running:

- `opensis-db`
- `opensis-ui`
- `vault`
- `vault-agent-app`
- `vault-agent-db`

### Trigger

We stopped only Vault:

```bash
cd OpenSIS
docker compose stop vault
```

Docker stopped:

- `vault`

The OpenSIS UI, database, and Vault agents stayed running.

### Detection

The first post-trigger OpenSIS live audit failed at the Vault dependency check:

```text
curl: (7) Failed to connect to localhost port 8200
FAIL OpenSIS Vault health endpoint is unreachable
```

Direct Vault health also failed:

```text
vault_health_http=000
curl: (7) Failed to connect to localhost port 8200
```

The control plane still reported OpenSIS as healthy because its app health model currently tracks the OpenSIS UI endpoint:

```json
{
  "status": "healthy",
  "endpoints": [
    {
      "id": "opensis-ui",
      "status": "up",
      "probeSuccess": 1
    }
  ]
}
```

That was the main point of the drill: the general app dashboard can correctly say the UI is reachable while the app-specific live audit catches a deeper dependency outage.

### Important Observation

Stopping Vault sealed it during shutdown:

```text
Vault shutdown triggered
core: marked as sealed
core: pre-seal teardown starting
core: vault is sealed
```

After `docker compose start vault`, Vault came back as a running container, but the first recovery audit still failed because Vault returned HTTP `503`.

That was not a false alarm. The bootstrap logs showed the real state:

```text
Vault status: initialized=true sealed=true
Unsealing Vault...
Vault unsealed successfully.
Vault is initialized and unsealed.
Vault bootstrap completed successfully.
```

Host `curl` to `localhost:8088` intermittently returned HTTP `000` during the incident window, but the app-specific audit and control-plane probe both showed the UI path reachable. The durable incident signal was the Vault health failure, not the transient host-curl result.

### Recovery

We first started Vault:

```bash
cd OpenSIS
docker compose start vault
```

Docker started:

- `vault-volume-init`
- `vault`

The container became healthy, but Vault was still sealed from the application perspective. The correct repo-native recovery step was to rerun the one-shot bootstrap job:

```bash
cd OpenSIS
docker compose up vault-bootstrap
```

The bootstrap job:

- confirmed Vault was reachable
- found `initialized=true sealed=true`
- unsealed Vault
- reloaded OpenSIS Vault policies
- recreated AppRoles
- regenerated AppRole credentials
- exited successfully

Direct Vault health then returned:

```json
{
  "initialized": true,
  "sealed": false,
  "standby": false
}
```

### Final Verification

OpenSIS live audit passed after recovery:

- `18/18` checks
- Vault health endpoint responded
- Vault reported initialized
- Vault reported unsealed
- control plane saw OpenSIS as healthy
- all OpenSIS blackbox targets were up

The full operator baseline also passed:

- control-plane smoke check passed `26/26`
- inventory validation passed with `0` errors and `0` warnings
- workspace app snapshot reported `4` total apps
- all `4` managed apps were healthy
- OpenSIS, SwiftPay, MemFlip, and FoodPulse all had healthy primary endpoints

### Lessons

This drill taught four useful platform lessons:

- OpenSIS UI reachability does not prove Vault readiness.
- `opensis-live` is required because it checks dependency health beyond the control-plane UI endpoint.
- A restarted Vault container can be Docker-healthy while still sealed from the application perspective.
- Recovery for this local lab is `docker compose start vault` followed by `docker compose up vault-bootstrap` when Vault restarts sealed.

### Kubernetes Mapping

In Kubernetes, the equivalent drill would be:

```bash
kubectl scale statefulset/vault --replicas=0 -n vault
kubectl scale statefulset/vault --replicas=1 -n vault
kubectl get pods -n vault
kubectl logs -n vault vault-0
kubectl exec -n vault vault-0 -- vault status
```

The same lesson applies in Kubernetes: pod readiness, service reachability, Vault seal state, and user-facing OpenSIS UI behavior are related but not identical signals. A serious runbook must verify the dependency state directly.

---

## Incident Drill: FoodPulse Redis Failover

### Goal

Prove that FoodPulse can survive a Redis master failure through Sentinel promotion and that the operator workflow can verify the final Redis topology.

This drill was selected fourth because it brings the incident-drill pattern into FoodPulse without using the higher-risk Postgres promotion drill. The Postgres drill is intentionally data-risk because it can leave the replication topology dirty, so Redis failover was the safer next learning step.

### Commands Run

```bash
git status --short
sed -n '398,480p' PROJECT-ROADMAP.md
sed -n '35,90p' Obervability-Stack/docs/INCIDENT_DRILLS.md
./Obervability-Stack/scripts/devops-monitor.sh foodpulse-live
rg --files FoodPulse | rg 'cluster-status|failover|drill|compose|README|RUNBOOK|docs'
cd FoodPulse && docker compose ps
sed -n '1,260p' FoodPulse/scripts/redis-failover-drill.sh
sed -n '1,260p' FoodPulse/scripts/cluster-status.sh
sed -n '1,260p' FoodPulse/scripts/pg-failover-drill.sh
sed -n '1,220p' Obervability-Stack/scripts/foodpulse-live-audit.sh
cd FoodPulse && ./scripts/redis-failover-drill.sh
cd FoodPulse && ./scripts/redis-failover-drill.sh
cd FoodPulse && ./scripts/cluster-status.sh
./Obervability-Stack/scripts/devops-monitor.sh foodpulse-live
./Obervability-Stack/scripts/devops-monitor.sh operator
```

The first `redis-failover-drill.sh` attempt was cancelled before the stop prompt because the sandbox could not access the Colima Docker socket:

```text
permission denied while trying to connect to the docker API at unix:///Users/raymond/.colima/default/docker.sock
```

No Redis container had been stopped yet. The fix was to rerun the same script with Docker access approved, because this drill intentionally needs to inspect and stop/start containers.

### Baseline

Before the drill, FoodPulse live audit passed:

- `16/16` checks
- FoodPulse responded on `localhost:8090`
- frontend returned HTTP `200`
- stats endpoint responded through the UI proxy
- control plane saw FoodPulse as healthy
- Prometheus blackbox target health was up
- `cluster-status.sh` reported a healthy lab

The relevant services were running:

- `foodpulse-api`
- `foodpulse-ui`
- `foodpulse-redis-master`
- `foodpulse-redis-replica1`
- `foodpulse-redis-replica2`
- `foodpulse-redis-sentinel01`
- `foodpulse-redis-sentinel02`
- `foodpulse-redis-sentinel03`
- `foodpulse-redis-haproxy`

Baseline Redis roles were:

```text
foodpulse-redis-master: role:master
foodpulse-redis-replica1: role:slave, master_host:redis-master
foodpulse-redis-replica2: role:slave, master_host:redis-master
redis-haproxy view: role:master
```

### Trigger

The drill stopped the current Redis master:

```bash
cd FoodPulse
./scripts/redis-failover-drill.sh
```

At the first prompt, we pressed Enter to stop:

```text
foodpulse-redis-master
Waiting 15s for Sentinel failover...
```

### Detection

After the master stopped, Sentinel promoted a replica:

```text
role:slave
master_host:172.26.0.2
role:master
```

HAProxy still routed to a Redis master:

```text
role:master
```

The app did not go down during this window. This drill is primarily a topology drill, so the important signal was not a failed UI probe; it was the Redis role transition reported by the failover script and `cluster-status.sh`.

### Recovery

At the second prompt, we pressed Enter to start the old master again:

```text
foodpulse-redis-master
Waiting 10s for it to register with Sentinel...
```

The drill's immediate final output briefly looked ambiguous because the old master and promoted replica both reported `role:master`:

```text
role:master
role:slave
master_host:172.26.0.2
role:master
```

We did not accept that as final recovery proof. We ran the normal operator status helper immediately afterward:

```bash
cd FoodPulse
./scripts/cluster-status.sh
```

That follow-up check confirmed the topology had settled:

```text
foodpulse-redis-master:
  role:slave
  master_host:172.26.0.2
foodpulse-redis-replica1:
  role:slave
  master_host:172.26.0.2
foodpulse-redis-replica2:
  role:master
HAProxy view:
  role:master
```

### Final Verification

FoodPulse live audit passed after recovery:

- `16/16` checks
- frontend returned HTTP `200`
- stats endpoint responded through the UI proxy
- control plane saw FoodPulse as healthy
- Prometheus blackbox target health was up
- `cluster-status.sh` reported a healthy lab

The full operator baseline also passed:

- control-plane smoke check passed `26/26`
- inventory validation passed with `0` errors and `0` warnings
- workspace app snapshot reported `4` total apps
- all `4` managed apps were healthy
- OpenSIS, SwiftPay, MemFlip, and FoodPulse all had healthy primary endpoints

### Problems And Fixes

Problem: the first drill attempt could not access Docker from the sandbox.

Fix: cancel before the destructive prompt and rerun the same script with Docker access approved.

Problem: the immediate final output from the drill briefly appeared to show two Redis masters.

Fix: do not trust the first post-start snapshot alone. Run `cluster-status.sh` after Sentinel has a moment to converge. The follow-up check confirmed one master and two replicas.

### Lessons

This drill taught four useful platform lessons:

- FoodPulse can keep the application path healthy while Redis Sentinel promotes a new master.
- The most important signal for this drill is topology state, not just HTTP reachability.
- Recovery proof must include `cluster-status.sh`, because the script's immediate final output can catch Redis during convergence.
- The old Redis master can rejoin as a replica, which is the expected local-lab outcome after failover.

### Kubernetes Mapping

In Kubernetes, the equivalent drill would be:

```bash
kubectl delete pod redis-master-0 -n foodpulse
kubectl get pods -n foodpulse
kubectl logs -n foodpulse -l app=redis-sentinel
kubectl exec -n foodpulse deploy/redis-haproxy -- redis-cli INFO replication
```

The same lesson applies in Kubernetes: application readiness, Sentinel election state, HAProxy routing, and direct Redis node roles are separate signals. A good runbook verifies all of them before declaring recovery.

---

## Incident Drill: Control Plane Probe Drift

### Goal

Prove that operators can distinguish a real application outage from an observability/probe-layer outage.

This drill was selected after one real drill per major workload because it ties the platform story together. A DevOps operator needs to know when the app is broken, when the monitoring path is broken, and when both are true.

### Commands Run

```bash
git status --short
./Obervability-Stack/scripts/devops-monitor.sh operator
cd Obervability-Stack && docker compose ps blackbox-exporter prometheus devops-monitor-ui
cd Obervability-Stack && docker compose stop blackbox-exporter
./Obervability-Stack/scripts/devops-monitor.sh operator
curl -fsS http://localhost:4000/api/apps/health | jq '{overallStatus, apps: [.apps[] | {appId, status, primary: .primaryEndpoint.status}]}'
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=up{job="blackbox-http"}' | jq '.data.result'
curl -fsSI http://localhost:8080/api/health
curl -fsSI http://localhost:8081
curl -fsSI http://localhost:8088
curl -fsSI http://localhost:8090
sleep 20 && curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=up{job="blackbox-http"}' | jq '[.data.result[] | {app: .metric.app, component: .metric.component, value: .value[1]}]'
cd Obervability-Stack && docker compose ps blackbox-exporter prometheus devops-monitor-ui
cd Obervability-Stack && docker compose start blackbox-exporter
sleep 25 && curl -fsS http://localhost:9115/-/healthy
sleep 25 && curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=up{job="blackbox-http"}' | jq '[.data.result[] | {app: .metric.app, component: .metric.component, value: .value[1]}]'
sleep 25 && cd Obervability-Stack && docker compose ps blackbox-exporter prometheus devops-monitor-ui
./Obervability-Stack/scripts/devops-monitor.sh operator
```

### Baseline

Before the drill, the operator check passed:

- `26/26` checks
- all default observability services were running
- Prometheus, Grafana, Loki, Alertmanager, Blackbox Exporter, Node Exporter, and the DevOps Monitor UI responded
- the control plane returned all `4` monitored apps
- inventory validation passed with `0` errors and `0` warnings
- OpenSIS, SwiftPay, MemFlip, and FoodPulse were all healthy

The key observability services were running:

- `blackbox-exporter`
- `prometheus`
- `devops-monitor-ui`

### Trigger

We stopped only the blackbox exporter:

```bash
cd Obervability-Stack
docker compose stop blackbox-exporter
```

Docker stopped:

- `blackbox-exporter`

Prometheus and the DevOps Monitor UI stayed running.

### Detection

The first post-trigger operator check failed:

```text
FAIL Service not running: blackbox-exporter
FAIL Blackbox Exporter health returned HTTP 000 from http://localhost:9115/-/healthy
INFO Checks passed: 24/26
FAIL Failures: 2
```

The control-plane app API still showed the apps as healthy:

```json
{
  "apps": [
    {
      "appId": "opensis",
      "status": "healthy",
      "primary": "up"
    },
    {
      "appId": "swiftpay",
      "status": "healthy",
      "primary": "up"
    },
    {
      "appId": "memflip",
      "status": "healthy",
      "primary": "unknown"
    },
    {
      "appId": "foodpulse",
      "status": "healthy",
      "primary": "up"
    }
  ]
}
```

After waiting for a scrape interval, Prometheus reported all blackbox targets as down:

```json
[
  {
    "app": "foodpulse",
    "component": "frontend",
    "value": "0"
  },
  {
    "app": "memflip",
    "component": "backend",
    "value": "0"
  },
  {
    "app": "opensis",
    "component": "frontend",
    "value": "0"
  },
  {
    "app": "swiftpay",
    "component": "frontend",
    "value": "0"
  }
]
```

That Prometheus view looked like a broad app outage, but direct host probes showed the apps were still reachable:

```text
MemFlip: HTTP 200
SwiftPay: HTTP 200
OpenSIS: HTTP 302
FoodPulse: HTTP 200
```

### Important Observation

This was not a multi-app outage.

The shared probe service was down, so Prometheus could not execute the blackbox checks. That made monitored targets report `0`, but direct app health stayed good.

The operator clue was the blast radius:

- many unrelated app probes failed at the same time
- direct host probes still worked
- `blackbox-exporter` itself was stopped
- Prometheus and the control-plane UI were still reachable

That pattern points to probe-layer failure, not simultaneous failure across every workload.

### Recovery

We restarted the blackbox exporter:

```bash
cd Obervability-Stack
docker compose start blackbox-exporter
```

Docker started:

- `blackbox-exporter`

After waiting one scrape window, direct blackbox health returned:

```text
Healthy
```

Prometheus blackbox targets returned to `1`:

```json
[
  {
    "app": "foodpulse",
    "component": "frontend",
    "value": "1"
  },
  {
    "app": "memflip",
    "component": "backend",
    "value": "1"
  },
  {
    "app": "opensis",
    "component": "frontend",
    "value": "1"
  },
  {
    "app": "swiftpay",
    "component": "frontend",
    "value": "1"
  }
]
```

### Final Verification

The full operator baseline passed after recovery:

- control-plane smoke check passed `26/26`
- inventory validation passed with `0` errors and `0` warnings
- workspace app snapshot reported `4` total apps
- all `4` managed apps were healthy
- OpenSIS, SwiftPay, MemFlip, and FoodPulse all had healthy primary endpoints

### Lessons

This drill taught four useful platform lessons:

- A monitoring-layer outage can make many app probes fail at once.
- Direct app probes are the fastest way to separate app outage from probe outage.
- Recovery proof needs both service health and a fresh Prometheus scrape.
- Operators should suspect shared infrastructure when unrelated apps all appear to fail together.

### Kubernetes Mapping

In Kubernetes, the equivalent drill would be:

```bash
kubectl scale deployment/blackbox-exporter --replicas=0 -n observability
kubectl get pods -n observability
kubectl get servicemonitor -A
kubectl port-forward -n observability svc/prometheus 9090:9090
kubectl scale deployment/blackbox-exporter --replicas=1 -n observability
kubectl rollout status deployment/blackbox-exporter -n observability
```

The same lesson applies in Kubernetes: pod readiness, ServiceMonitor configuration, NetworkPolicy, DNS, and app reachability can diverge. A strong operator workflow checks the probe layer before declaring every workload down.

---

## Phase 5 Closeout: Operator Workflows And Incident Drills

Phase 5 is complete.

We now have a real operations lab instead of just a set of runnable apps.

The completed Phase 5 evidence includes:

- a standard operator health workflow
- a platform incident matrix
- app-facing operator runbooks
- an incident drill catalog
- executed and recovered drills for MemFlip, SwiftPay, OpenSIS, FoodPulse, and the shared observability layer
- documented command trails and recovery lessons for each real drill

The executed drill set now covers:

- simple backend outage
- microservice dependency outage
- secret-control-plane dependency outage
- Redis failover/topology convergence
- monitoring/probe-layer drift

This is enough to move into Phase 6 with confidence. The next phase should make the experience feel polished, teachable, and demo-ready without losing the operational realism we just built.

---

## Phase 6 Demo Front Door

### Goal

Start Phase 6 by giving the project a clear front door and a guided demo path.

Phase 5 proved the operational substance. Phase 6 needs to make that substance easier to understand quickly.

### Commands Run

```bash
git status --short
sed -n '488,560p' PROJECT-ROADMAP.md
git diff -- FoodPulse/ui/src/App.jsx FoodPulse/ui/src/styles.css Obervability-Stack/ui-next/app/services/page.tsx
ls -1
sed -n '1,220p' README.md
rg --files | rg 'DEMO|demo|README|OPERATOR|RUNBOOK|ROADMAP'
sed -n '1,220p' WORKSPACE-ARCHITECTURE.md
sed -n '1,220p' WORKSPACE-SETUP-MATRIX.md
sed -n '1,180p' WORKSTATION-BOOTSTRAP.md
sed -n '1,180p' Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md
```

### What We Found

There was no root `README.md`.

That meant the project had strong internal docs, but no single front-door document for someone arriving fresh from GitHub.

The existing supporting docs were already strong:

- `WORKSPACE-ARCHITECTURE.md` explains the platform model
- `WORKSPACE-SETUP-MATRIX.md` explains startup contracts, ports, health checks, and aliases
- `WORKSTATION-BOOTSTRAP.md` explains macOS/Linux tool setup
- `Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md` explains the first-response workflow

### What We Changed

We added:

- `README.md`
- `DEMO-WALKTHROUGH.md`

The root README now explains:

- what the workspace is
- what each repo does
- the platform story
- quick-start direction
- operator entry points
- executed incident drills
- key documentation links
- current Phase 6 status

The demo walkthrough now provides:

- a pre-demo checklist
- the story arc for a live walkthrough
- workload talking points
- app-specific audit choices
- incident drill catalog handoff
- journey runbook handoff
- Kubernetes direction
- a five-minute version
- demo safety notes

### Why This Matters

The project is now easier to evaluate from the outside.

Before this step, a reviewer had to infer the project story from several deep docs. Now the repo opens with a clear explanation of the platform and a guided path for showing it.

### Next Step

Continue Phase 6 by polishing the control-plane UX and app launch experience, especially:

- app card navigation
- app category/story labels
- demo-friendly service pages
- FoodPulse visual polish
- root docs alignment with the final UI experience

---

## Phase 6 UI Polish: FoodPulse And App Launch Cards

### Goal

Continue Phase 6 by making the live demo feel more intentional.

This pass focused on two visible demo moments:

- FoodPulse should look like a clean, owned app instead of an inherited demo UI.
- The control plane should let operators launch managed apps directly from the services page.

### Commands Run

```bash
git status --short
find FoodPulse/ui -maxdepth 2 -type f | sort
find Obervability-Stack/ui-next -maxdepth 2 -type f | sort | sed -n '1,160p'
git diff -- FoodPulse/ui/src/App.jsx FoodPulse/ui/src/styles.css Obervability-Stack/ui-next/app/services/page.tsx
cat FoodPulse/ui/package.json
cat Obervability-Stack/ui-next/package.json
sed -n '1,420p' Obervability-Stack/ui-next/app/services/page.tsx
sed -n '1,280p' FoodPulse/ui/src/App.jsx
npm run build
npm run type-check
npm run build
docker compose up -d --build foodpulse-ui
docker compose up -d --build devops-monitor-ui
./Obervability-Stack/scripts/devops-monitor.sh operator
./Obervability-Stack/scripts/devops-monitor.sh foodpulse-live
curl -fsS http://localhost:8090 | rg -n "FoodPulse|Welcome|Live Dining Board|Vote Split"
curl -fsSI http://localhost:4000/services
```

### What We Changed

FoodPulse UI now uses a cleaner board layout:

- top status bar
- centered welcome panel
- colored restaurant cards
- clean restaurant labels for category, neighborhood, price band, and energy score
- vote buttons per restaurant
- live vote split chart
- compact stats row for page views, serving node, top pick, and total votes

The previous progress-bar voting display was removed in favor of a chart and cleaner labels.

The control-plane services page now supports direct app launching from managed-app cards:

- cards with a configured browser URL are keyboard-focusable
- pressing Enter or Space opens the primary app URL
- the card has an accessible label such as `Open FoodPulse`
- each card also has an explicit `Open <app>` button

### Design Note

The FoodPulse visual direction was adjusted away from default Inter styling and toward a more deliberate `Manrope` + `JetBrains Mono` pairing.

That keeps the UI clean and practical while avoiding a generic dashboard feel.

### Verification

FoodPulse local production build passed:

```text
vite build
29 modules transformed
built in 653ms
```

Control-plane TypeScript check passed:

```text
tsc --noEmit
```

Control-plane production build passed:

```text
next build
Compiled successfully
Generating static pages using 9 workers (22/22)
```

The local production build printed expected environment warnings for:

- `NEXTAUTH_SECRET`
- `NEXTAUTH_URL`
- `DATABASE_URL`

The build still completed. The database warning is expected in this local build path because the app falls back to JWT-only mode when `DATABASE_URL` is not set.

### Runtime Rebuild

We rebuilt and restarted the affected running services:

```bash
cd FoodPulse
docker compose up -d --build foodpulse-ui

cd ../Obervability-Stack
docker compose up -d --build devops-monitor-ui
```

FoodPulse rebuild also recreated `foodpulse-api` because the Compose dependency graph includes the API image in the selected build set.

### Final Verification

The full operator check passed:

- control-plane smoke check passed `26/26`
- inventory validation passed with `0` errors and `0` warnings
- all `4` monitored apps were healthy

FoodPulse live audit passed:

- `16/16` checks
- frontend returned HTTP `200`
- stats endpoint responded through the UI proxy
- Prometheus blackbox target was healthy
- `cluster-status.sh` reported a healthy lab

The services page responded with the expected auth redirect:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fservices
```

### Why This Matters

Phase 6 is about making the project easier to understand and demo.

This pass improves the first impression in two places:

- FoodPulse now looks like a deliberate resilience-lab app.
- The control plane now behaves more like an app launcher, not only a health page.

### Next Step

Continue polishing the control-plane UX:

- make app categories more visually distinct
- tighten the services page story copy
- add a clearer demo path from app card to operator runbook
- revisit FoodPulse once we decide whether the existing layout should stay minimal or become more branded

---

## Phase 6 UI Polish: Simple Services Dashboard And App Detail Pages

### Goal

Simplify the managed-app dashboard and move detailed operational information onto app-specific pages.

The user feedback was clear:

- the dashboard had too much information
- managed app labels should open a page specific to that app
- each app page should include probe latency, uptime, alerts, recent logs, and operator guidance

### Commands Run

```bash
git status --short
find Obervability-Stack/ui-next/app -maxdepth 3 -type f | sort | sed -n '1,220p'
sed -n '1,260p' Obervability-Stack/ui-next/lib/monitored-apps.ts
sed -n '1,260p' Obervability-Stack/ui-next/lib/app-observability.ts
sed -n '260,520p' Obervability-Stack/ui-next/lib/monitored-apps.ts
find Obervability-Stack/ui-next/app/api/apps -maxdepth 3 -type f -print -exec sed -n '1,200p' {} \;
find Obervability-Stack/ui-next/components/ui -maxdepth 1 -type f -print | sort
find Obervability-Stack/ui-next/lib/hooks -maxdepth 1 -type f -print -exec sed -n '1,220p' {} \;
sed -n '420,900p' Obervability-Stack/ui-next/app/services/page.tsx
npm run type-check
git diff -- Obervability-Stack/ui-next/app/services/page.tsx 'Obervability-Stack/ui-next/app/services/[appId]/page.tsx'
npm run build
curl -fsS http://localhost:4000/api/apps/opensis/overview | jq '{app: .app.name, status: .health.status, endpoints: (.health.endpoints | length), alerts: (.alerts | length), logs: (.recentLogs | length), uptime: (.uptimeSeries | length), latency: (.latencySeries | length)}'
curl -fsS http://localhost:4000/api/apps/swiftpay/overview | jq '{app: .app.name, status: .health.status, endpoints: (.health.endpoints | length), alerts: (.alerts | length), logs: (.recentLogs | length), uptime: (.uptimeSeries | length), latency: (.latencySeries | length)}'
curl -fsS http://localhost:4000/api/apps/foodpulse/overview | jq '{app: .app.name, status: .health.status, endpoints: (.health.endpoints | length), alerts: (.alerts | length), logs: (.recentLogs | length), uptime: (.uptimeSeries | length), latency: (.latencySeries | length)}'
curl -fsS http://localhost:4000/api/apps/memflip/overview | jq '{app: .app.name, status: .health.status, endpoints: (.health.endpoints | length), alerts: (.alerts | length), logs: (.recentLogs | length), uptime: (.uptimeSeries | length), latency: (.latencySeries | length)}'
curl -fsSI http://localhost:4000/services
curl -fsSI http://localhost:4000/services/opensis
curl -fsSI http://localhost:4000/services/swiftpay
curl -fsSI http://localhost:4000/services/foodpulse
curl -fsSI http://localhost:4000/services/memflip
node scripts/validate-monitored-apps.ts
npx tsx scripts/validate-monitored-apps.ts
docker compose up -d --build devops-monitor-ui
curl -fsS http://localhost:4000/api/apps | jq '.apps[] | {id, category}'
./Obervability-Stack/scripts/devops-monitor.sh operator
curl -fsS http://localhost:4000/api/apps/foodpulse/overview | jq '{app: .app.name, status: .health.status, category: .app.category, uptime: (.uptimeSeries | length), latency: (.latencySeries | length)}'
```

### What We Changed

The Services page now acts as a simple managed-app launch board.

Instead of showing service-health cards, quick links, tabs, platform status cards, and app details all on the same page, it now focuses on:

- app name
- app category label
- app health label
- endpoint count
- primary latency
- click-through to the app operator page

Each managed app now has a dedicated page:

- `/services/opensis`
- `/services/swiftpay`
- `/services/foodpulse`
- `/services/memflip`

Each app page includes:

- probe latency
- uptime percentage from the last hour of blackbox samples
- alert count
- endpoint health count
- probe target table
- app-specific operator guide
- first-response commands
- recent alerts
- recent logs
- local start and health-check commands

### Label Improvements

The app categories now tell a clearer story:

- OpenSIS: `Legacy Platform`
- SwiftPay: `Microservices`
- FoodPulse: `HA Lab`
- MemFlip: `Demo App`

To support this, FoodPulse and MemFlip were separated in `monitored-apps.ts`:

- FoodPulse changed from `web-application` to `resilience-lab`
- MemFlip changed from `web-application` to `demo-app`

### Problem And Fix

Problem: I initially ran the monitored-app validator with plain `node`:

```bash
node scripts/validate-monitored-apps.ts
```

That failed because the script is TypeScript/ES module shaped and imports `lib/monitored-apps` without a compiled extension.

Fix: rerun it with the TypeScript runner:

```bash
npx tsx scripts/validate-monitored-apps.ts
```

That passed:

```text
Apps checked: 4
Errors: 0
Warnings: 0
Inventory validation passed.
```

### Verification

TypeScript passed:

```text
tsc --noEmit
```

Next production build passed and showed the new route:

```text
/services
/services/[appId]
```

As before, the local build printed expected warnings for missing production auth/database environment values:

- `NEXTAUTH_SECRET`
- `NEXTAUTH_URL`
- `DATABASE_URL`

The build still completed successfully.

All four app overview APIs returned healthy data with uptime and latency series:

- OpenSIS: `healthy`, `uptimeSeries=60`, `latencySeries=60`
- SwiftPay: `healthy`, `uptimeSeries=60`, `latencySeries=60`
- FoodPulse: `healthy`, `uptimeSeries=60`, `latencySeries=60`
- MemFlip: `healthy`, `uptimeSeries=60`, `latencySeries=60`

The protected pages returned the expected auth redirects:

```text
/services -> /auth/signin?from=%2Fservices
/services/opensis -> /auth/signin?from=%2Fservices%2Fopensis
/services/swiftpay -> /auth/signin?from=%2Fservices%2Fswiftpay
/services/foodpulse -> /auth/signin?from=%2Fservices%2Ffoodpulse
/services/memflip -> /auth/signin?from=%2Fservices%2Fmemflip
```

After rebuilding `devops-monitor-ui`, the full operator check passed:

- control-plane smoke check passed `26/26`
- inventory validation passed with `0` errors and `0` warnings
- all `4` monitored apps were healthy

### Why This Matters

This makes the control plane easier to explain.

The top-level Services page is no longer trying to be everything. It is now the starting point.

The app detail pages are where the operator depth lives. That is the right split for a teaching platform:

- simple dashboard first
- app-specific operational depth after click-through

### Next Step

Continue with the same pattern:

- add a clearer link from each app detail page to its Markdown operator runbook
- add small trend charts for uptime and latency
- consider moving platform service health into a separate `/services/platform` page

## Phase 6 UI Polish: Main Dashboard Simplified To Match The Services Pattern

### Date

2026-04-19

### Goal

The user could not see the simplified app-label experience on the dashboard.

The root cause was that the previous change simplified `/services`, but the main `/dashboard` route still had the older overloaded layout with SwiftPay business metrics, OpenSIS charts, logs, alerts, and long operator-guide sections.

We changed the actual dashboard route so it is now intentionally simple:

- top-level health summary
- firing alert count
- light infrastructure signals
- clean managed-app labels
- click-through from each app label to `/services/<appId>`

The deep operational content remains on the per-app pages:

- `/services/opensis`
- `/services/swiftpay`
- `/services/foodpulse`
- `/services/memflip`

### Commands Run

Checked whether the repo had pending changes:

```bash
git status --short
```

Confirmed the working directory:

```bash
pwd
```

Searched for the simplified Services page and the app detail page content:

```bash
rg -n "Choose an app to operate|Services|Managed|Probe latency|Operator Guide" Obervability-Stack/ui-next/app Obervability-Stack/ui-next/lib
```

Checked the running observability stack containers:

```bash
docker compose ps
```

Inspected the existing dashboard implementation:

```bash
sed -n '430,500p' Obervability-Stack/ui-next/app/dashboard/page.tsx
```

```bash
sed -n '1060,1140p' Obervability-Stack/ui-next/app/dashboard/page.tsx
```

```bash
sed -n '1140,1340p' Obervability-Stack/ui-next/app/dashboard/page.tsx
```

```bash
sed -n '1,120p' Obervability-Stack/ui-next/app/dashboard/page.tsx
```

Inspected more of the dashboard structure before replacing the overloaded page:

```bash
sed -n '120,260p' Obervability-Stack/ui-next/app/dashboard/page.tsx
```

```bash
sed -n '900,1085p' Obervability-Stack/ui-next/app/dashboard/page.tsx
```

```bash
sed -n '1340,1450p' Obervability-Stack/ui-next/app/dashboard/page.tsx
```

Checked package scripts:

```bash
sed -n '1,140p' Obervability-Stack/ui-next/package.json
```

Inspected the app health types and health hook so the simplified dashboard could use the right fields:

```bash
rg -n "export interface AppHealth|type AppHealth|interface AppHealth" Obervability-Stack/ui-next/lib/app-observability.ts Obervability-Stack/ui-next/lib -g '*.ts'
```

```bash
sed -n '1,180p' Obervability-Stack/ui-next/lib/app-observability.ts
```

```bash
sed -n '1,160p' Obervability-Stack/ui-next/lib/hooks/use-app-health.ts
```

Inspected monitored app metadata for category labels and descriptions:

```bash
sed -n '1,180p' Obervability-Stack/ui-next/lib/monitored-apps.ts
```

Viewed the current runbook tail before appending this section:

```bash
tail -n 120 JOURNEY-RUNBOOK.md
```

Ran TypeScript after the dashboard rewrite:

```bash
npm run type-check
```

Reviewed the dashboard diff:

```bash
git diff -- Obervability-Stack/ui-next/app/dashboard/page.tsx
```

Ran the production build:

```bash
npm run build
```

Searched for Google font dependencies after the build failed:

```bash
rg -n "next/font|Inter|fontSans|className" Obervability-Stack/ui-next/app Obervability-Stack/ui-next/components Obervability-Stack/ui-next/lib -g '*.tsx' -g '*.ts'
```

```bash
sed -n '1,120p' Obervability-Stack/ui-next/app/layout.tsx
```

```bash
sed -n '1,160p' Obervability-Stack/ui-next/app/globals.css
```

Confirmed the Google font references were removed:

```bash
rg -n "next/font/google|fonts.googleapis.com" Obervability-Stack/ui-next
```

Re-ran TypeScript:

```bash
npm run type-check
```

Re-ran the production build:

```bash
npm run build
```

The sandbox blocked Turbopack/PostCSS process creation, so the same build was run again with approval outside the sandbox:

```bash
npm run build
```

Rebuilt and restarted the running UI container:

```bash
docker compose up -d --build devops-monitor-ui
```

Verified the rebuilt UI container is healthy:

```bash
docker compose ps devops-monitor-ui
```

Verified the app health API still reports all managed apps:

```bash
curl -fsS http://localhost:4000/api/apps/health
```

Confirmed `/dashboard` is still protected by auth:

```bash
curl -fsS -I http://localhost:4000/dashboard
```

Checked the final working tree:

```bash
git status --short
```

### Changes Made

Replaced the overloaded dashboard implementation in:

```text
Obervability-Stack/ui-next/app/dashboard/page.tsx
```

The dashboard now has:

- a short hero explaining that deep operator work happens after selecting an app
- four top-level cards: healthy apps, firing alerts, CPU, network
- a simple managed-app label grid
- clickable labels linking to each app operator page

Removed the build-time Google Fonts dependency from:

```text
Obervability-Stack/ui-next/app/layout.tsx
Obervability-Stack/ui-next/app/globals.css
```

### Problems And Fixes

Problem: The user could not see the change on the dashboard.

Cause: We had simplified `/services`, but the visible `/dashboard` route still used the old overloaded dashboard.

Fix: Replace the main dashboard with the same app-label pattern and point every managed app label to its app-specific operator page.

Problem: `npm run build` failed because Next tried to download Inter from Google Fonts:

```text
Failed to fetch `Inter` from Google Fonts.
```

Cause: The app used `next/font/google`, which requires a build-time network fetch.

Fix: Remove the `next/font/google` import and remove the external `fonts.googleapis.com` CSS imports. This makes builds more reliable on new machines, restricted networks, and future lab environments.

Problem: A later `npm run build` failed with a Turbopack/PostCSS sandbox error:

```text
creating new process
binding to a port
Operation not permitted
```

Cause: The local sandbox blocked Turbopack/PostCSS from spawning a helper process and binding a local port.

Fix: Re-ran the same `npm run build` with approved elevated execution. The production build passed.

### Verification

TypeScript passed:

```text
tsc --noEmit
```

Production build passed after removing the external font dependency and running outside the sandbox restriction.

The Docker image rebuilt successfully and `devops-monitor-ui` restarted healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

The app health API reported:

- total apps: `4`
- healthy apps: `4`
- degraded apps: `0`
- down apps: `0`
- unknown apps: `0`

The `/dashboard` route still correctly requires sign-in:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fdashboard
```

### Why This Matters

This keeps the learning flow clean.

The main dashboard is now the front door, not the whole encyclopedia. The learner sees app labels first, then clicks into OpenSIS, SwiftPay, FoodPulse, or MemFlip when they want probe latency, uptime, alerts, recent logs, and operator guidance.

It also removes a hidden build dependency on Google Fonts, which is better for a DevOps training repo that should work on fresh laptops and restricted lab networks.

## Phase 6 UI Polish: Monitoring And Logging Service Labels

### Date

2026-04-20

### Goal

Add a `Monitoring and Logging` section under `Managed Apps` on the Services page.

The requested labels are:

- Prometheus
- Grafana
- Alertmanager
- Loki
- Promtail
- Node Exporter
- Blackbox Exporter
- cAdvisor

Each label needed to show:

- whether the service is up or down
- current version
- latest available version
- whether an update is available
- an `Open` button to the service URL
- a `Check Update` action

### Commands Run

Read the current Services page:

```bash
sed -n '1,280p' Obervability-Stack/ui-next/app/services/page.tsx
```

Searched for previous version/update monitoring code and service references:

```bash
rg -n "Version|version|update|Update|Prometheus|Grafana|Alertmanager|Loki|promtail|Node exporter|blackbox|cAdvisor|cadvisor" Obervability-Stack/ui-next/app Obervability-Stack/ui-next/components Obervability-Stack/ui-next/lib -g '*.tsx' -g '*.ts'
```

Listed existing API routes:

```bash
find Obervability-Stack/ui-next/app/api -maxdepth 4 -type f | sort
```

Read the Observability Stack Compose file:

```bash
sed -n '1,220p' Obervability-Stack/docker-compose.yml
```

```bash
sed -n '220,520p' Obervability-Stack/docker-compose.yml
```

Read the existing health and version helpers:

```bash
sed -n '1,340p' Obervability-Stack/ui-next/lib/health-api.ts
```

```bash
sed -n '1,380p' Obervability-Stack/ui-next/lib/version-monitor.ts
```

Read the existing service health API route:

```bash
sed -n '1,130p' Obervability-Stack/ui-next/app/api/services/health/route.ts
```

Read the centralized service config:

```bash
sed -n '1,160p' Obervability-Stack/ui-next/lib/service-config.ts
```

Checked whether cAdvisor, Promtail, Blackbox Exporter, and Node Exporter already existed in Compose and Prometheus config:

```bash
rg -n "cadvisor|cAdvisor|blackbox|promtail|node-exporter|9100|9115|8080|8082" Obervability-Stack/prometheus Obervability-Stack -g '*.yml' -g '*.yaml' -g '*.env*'
```

Listed Compose files in the repo:

```bash
find . -maxdepth 3 -iname '*compose*.yml' -o -iname '*compose*.yaml'
```

Read Prometheus scrape configuration:

```bash
sed -n '1,260p' Obervability-Stack/prometheus/prometheus.yml
```

Read the monitored-app hook pattern before adding the platform-services hook:

```bash
sed -n '1,140p' Obervability-Stack/ui-next/lib/hooks/use-monitored-apps.ts
```

Ran TypeScript after adding the platform service API, hook, and UI:

```bash
npm run type-check
```

Reviewed the diff and changed files:

```bash
git diff --stat
```

```bash
git diff -- Obervability-Stack/ui-next/app/services/page.tsx Obervability-Stack/docker-compose.yml
```

Ran the production build:

```bash
npm run build
```

Rebuilt the UI and recreated Promtail so the Promtail `Open` button can reach `http://localhost:9080`:

```bash
docker compose up -d --build devops-monitor-ui promtail
```

Verified UI and Promtail containers:

```bash
docker compose ps devops-monitor-ui promtail
```

Checked the new platform service API:

```bash
curl -fsS http://localhost:4000/api/services/platform
```

Confirmed Promtail is reachable from the host:

```bash
curl -fsS -I http://localhost:9080/ready
```

Confirmed `/services` is still protected by auth:

```bash
curl -fsS -I http://localhost:4000/services
```

Checked working tree state:

```bash
git status --short
```

Started cAdvisor using its existing profile to verify it can run on this machine:

```bash
docker compose --profile container-metrics up -d cadvisor
```

Verified cAdvisor container and health endpoint:

```bash
docker compose ps cadvisor
```

```bash
curl -fsS -I http://localhost:8082/healthz
```

Checked the platform service API again after cAdvisor started:

```bash
curl -fsS http://localhost:4000/api/services/platform
```

Promoted cAdvisor into the default Compose service list and enabled the Prometheus cAdvisor scrape job, then reran checks:

```bash
npm run type-check
```

```bash
docker compose config --services
```

```bash
git diff --stat
```

Rebuilt and restarted the affected containers:

```bash
docker compose up -d --build devops-monitor-ui prometheus cadvisor promtail
```

Prometheus did not recreate because its container definition did not change, so the mounted config was reloaded explicitly:

```bash
curl -fsS -X POST http://localhost:9090/-/reload
```

Verified final runtime state:

```bash
docker compose ps devops-monitor-ui prometheus promtail cadvisor
```

```bash
curl -fsS http://localhost:4000/api/services/platform
```

Verified Prometheus is scraping cAdvisor:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22cadvisor%22%7D'
```

Confirmed `/services` remains auth-protected:

```bash
curl -fsS -I http://localhost:4000/services
```

Checked final working tree state:

```bash
git status --short
```

### Changes Made

Added a new server-side platform service inventory and checker:

```text
Obervability-Stack/ui-next/lib/platform-services.ts
```

This checker collects:

- service status
- response time
- current version
- latest GitHub release version
- update availability
- public URL
- release URL

Added a new API route:

```text
Obervability-Stack/ui-next/app/api/services/platform/route.ts
```

Added a client hook:

```text
Obervability-Stack/ui-next/lib/hooks/use-platform-services.ts
```

Updated the Services page:

```text
Obervability-Stack/ui-next/app/services/page.tsx
```

The page now keeps `Managed Apps` first, then adds `Monitoring and Logging` directly below it.

Updated Docker Compose:

```text
Obervability-Stack/docker-compose.yml
```

Changes:

- exposed Promtail on `9080:9080`
- changed cAdvisor host port from `8080` to `8082` to avoid collision with MemFlip
- promoted cAdvisor out of the optional profile so it is part of the default stack
- passed Promtail, Blackbox Exporter, and cAdvisor URLs into the UI container

Updated Prometheus scrape config:

```text
Obervability-Stack/prometheus/prometheus.yml
```

Change:

- enabled the `cadvisor` scrape job

### Problems And Fixes

Problem: cAdvisor already existed, but it was behind the `container-metrics` profile and was not part of the normal stack.

Fix: Start cAdvisor with the profile first to prove it works on this Mac. After it started healthy, remove the profile so it becomes a default service.

Problem: cAdvisor used host port `8080`, but MemFlip already uses `8080`.

Fix: map cAdvisor as `8082:8080`, so the cAdvisor Open button uses `http://localhost:8082`.

Problem: Promtail had no host port, so an `Open` button would not work from the browser.

Fix: expose Promtail on `9080:9080`.

Problem: Prometheus did not automatically restart after the mounted `prometheus.yml` changed.

Fix: call the lifecycle reload endpoint:

```bash
curl -fsS -X POST http://localhost:9090/-/reload
```

### Verification

TypeScript passed:

```text
tsc --noEmit
```

Production build passed and included:

```text
/api/services/platform
```

Runtime platform-service API returned:

- total services: `8`
- up: `8`
- down: `0`
- updates available: `8`

cAdvisor is healthy:

```text
cadvisor   Up ... (healthy)   0.0.0.0:8082->8080/tcp
```

Promtail is reachable from the browser host path:

```text
HTTP/1.1 200 OK
```

Prometheus is scraping cAdvisor:

```json
{"metric":{"__name__":"up","instance":"cadvisor","job":"cadvisor"},"value":[...,"1"]}
```

The `/services` route still requires sign-in:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fservices
```

### Why This Matters

This gives learners a single Services page with two clean layers:

- `Managed Apps`: OpenSIS, SwiftPay, FoodPulse, and MemFlip
- `Monitoring and Logging`: the observability tools that support those apps

That is the right mental model for the future Kubernetes version too. The apps are workloads, while Prometheus, Grafana, Alertmanager, Loki, Promtail, Node Exporter, Blackbox Exporter, and cAdvisor are platform services.

## Phase 6 UI Polish: Monitoring And Logging Health Sweep, Loki 404, And Promtail Fix

### Date

2026-04-20

### Goal

The user reported that cAdvisor was being explored and Loki returned:

```text
404 page not found
```

The goal was to check every monitoring and logging tool, explain the Loki behavior, and fix anything genuinely broken.

### Commands Run

Checked all Observability Stack containers:

```bash
docker compose ps
```

Checked the platform service API:

```bash
curl -fsS http://localhost:4000/api/services/platform
```

Checked all Prometheus `up` series:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=up'
```

Checked active Prometheus targets:

```bash
curl -fsS 'http://localhost:9090/api/v1/targets?state=active'
```

Checked browser-facing root and health URLs:

```bash
curl -sS -o /tmp/prometheus-root.out -w 'prometheus_root %{http_code}\n' http://localhost:9090/
```

```bash
curl -sS -o /tmp/grafana-root.out -w 'grafana_root %{http_code}\n' http://localhost:3000/
```

```bash
curl -sS -o /tmp/alertmanager-root.out -w 'alertmanager_root %{http_code}\n' http://localhost:9093/
```

```bash
curl -sS -o /tmp/loki-root.out -w 'loki_root %{http_code}\n' http://localhost:3100/
```

```bash
curl -sS -o /tmp/loki-ready.out -w 'loki_ready %{http_code}\n' http://localhost:3100/ready
```

```bash
curl -sS -o /tmp/promtail-ready.out -w 'promtail_ready %{http_code}\n' http://localhost:9080/ready
```

```bash
curl -sS -o /tmp/node-metrics.out -w 'node_exporter_metrics %{http_code}\n' http://localhost:9100/metrics
```

```bash
curl -sS -o /tmp/cadvisor-root.out -w 'cadvisor_root %{http_code}\n' http://localhost:8082/
```

Checked Blackbox Exporter and cAdvisor browser behavior:

```bash
curl -sS -o /tmp/blackbox-root.out -w 'blackbox_root %{http_code}\n' http://localhost:9115/
```

```bash
curl -sS -o /tmp/blackbox-healthy.out -w 'blackbox_healthy %{http_code}\n' http://localhost:9115/-/healthy
```

```bash
curl -sS -L -o /tmp/cadvisor-containers.out -w 'cadvisor_follow %{http_code}\n' http://localhost:8082/
```

```bash
curl -sS -o /tmp/cadvisor-health.out -w 'cadvisor_healthz %{http_code}\n' http://localhost:8082/healthz
```

Checked Loki labels and log query behavior:

```bash
curl -fsS 'http://localhost:3100/loki/api/v1/labels'
```

```bash
curl -fsS 'http://localhost:3100/loki/api/v1/query?query=%7Bcompose_project%3D~%22.%2B%22%7D'
```

Checked Promtail targets:

```bash
curl -fsS http://localhost:9080/targets
```

Checked Promtail and Loki logs:

```bash
docker compose logs --tail=80 promtail
```

```bash
docker compose logs --tail=80 loki
```

Read Promtail configuration:

```bash
sed -n '1,260p' Obervability-Stack/loki/promtail-config.yml
```

Tried a Docker API version override first:

```bash
docker compose up -d --build devops-monitor-ui promtail
```

Checked the rebuilt services:

```bash
docker compose logs --tail=30 promtail
```

Checked valid Promtail image tags:

```bash
docker manifest inspect grafana/promtail:3.5.8
```

```bash
docker manifest inspect grafana/promtail:3.4.4
```

```bash
docker manifest inspect grafana/promtail:3.3.2
```

```bash
docker manifest inspect grafana/promtail:3.2.1
```

Rebuilt with Promtail `3.5.8`:

```bash
docker compose up -d --build devops-monitor-ui promtail
```

Waited briefly for Docker target discovery:

```bash
sleep 8
```

Verified Promtail and UI containers:

```bash
docker compose ps promtail devops-monitor-ui
```

Checked Promtail logs again:

```bash
docker compose logs --tail=40 promtail
```

Checked Loki labels and actual log lines:

```bash
curl -fsS 'http://localhost:3100/loki/api/v1/labels'
```

```bash
curl -fsS 'http://localhost:3100/loki/api/v1/query?query=%7Bcompose_service%3D%22promtail%22%7D'
```

Checked the platform service API after the fix:

```bash
curl -fsS http://localhost:4000/api/services/platform
```

Confirmed the corrected Loki and Promtail Open URLs return `200`:

```bash
curl -sS -o /tmp/loki-ready-after.out -w 'loki_open_url %{http_code}\n' http://localhost:3100/ready
```

```bash
curl -sS -o /tmp/promtail-targets-after.out -w 'promtail_open_url %{http_code}\n' http://localhost:9080/targets
```

### Findings

All containers were running:

- Prometheus: healthy
- Grafana: healthy
- Alertmanager: healthy
- Loki: healthy
- Promtail: running
- Node Exporter: healthy
- Blackbox Exporter: healthy
- cAdvisor: healthy

Prometheus targets were all up, including:

- `job="prometheus"`
- `job="grafana"`
- `job="alertmanager"`
- `job="loki"`
- `job="promtail"`
- `job="node-exporter"`
- `job="cadvisor"`
- `job="blackbox-http"`

Loki root returned:

```text
loki_root 404
```

But Loki health returned:

```text
loki_ready 200
```

This means Loki was healthy. The problem was the UI `Open` button pointing to the wrong human-facing URL.

Promtail was running, but initially not discovering containers. Promtail logs showed:

```text
client version 1.41 is too old. Minimum supported API version is 1.44
```

That meant Loki itself was working, but log ingestion from Docker was broken.

### Fixes

Changed Loki’s Open URL from the root path to:

```text
http://localhost:3100/ready
```

Changed Promtail’s Open URL to:

```text
http://localhost:9080/targets
```

Tried setting:

```text
DOCKER_API_VERSION=1.44
```

That did not fix Promtail `2.8.0`, because its bundled Docker client still negotiated as too old.

Checked valid Promtail images and upgraded Promtail from:

```text
grafana/promtail:2.8.0
```

to:

```text
grafana/promtail:3.5.8
```

This fixed Docker discovery. Promtail logs then showed many `added Docker target` entries.

### Verification

Loki labels now return real label names:

```json
["compose_project","compose_service","container"]
```

Loki query now returns actual log lines:

```text
{compose_service="promtail"}
```

Platform service API now reports:

- total services: `8`
- up: `8`
- down: `0`

The corrected Open URLs return:

```text
loki_open_url 200
promtail_open_url 200
```

### Why This Matters

This is a useful DevOps lesson:

- `404` does not always mean a service is down.
- Loki is API-first and does not serve a dashboard at `/`.
- Grafana is the UI normally used to explore Loki logs.
- Promtail can be up while still failing its real job if Docker discovery is broken.

The final state is better for learners because the UI now opens meaningful endpoints, and the logging pipeline actually ingests Docker logs into Loki.

## 2026-04-20 - cAdvisor Docker Containers Page Failed Because Docker Client API Was Too Old

### Symptom

When opening cAdvisor and clicking into the Docker containers view, cAdvisor showed:

```text
failed to get docker info: Error response from daemon: client version 1.41 is too old. Minimum supported API version is 1.44, please upgrade your client to a newer version
```

The confusing part was that cAdvisor still appeared healthy in Docker Compose and in the platform UI.

### Commands Run

Checked the cAdvisor container state:

```bash
docker compose ps cadvisor
```

Result:

```text
cadvisor gcr.io/cadvisor/cadvisor:v0.49.1 Up ... healthy 0.0.0.0:8082->8080
```

Checked cAdvisor logs:

```bash
docker compose logs --tail=80 cadvisor
```

Important log entry:

```text
Registration of the docker container factory failed: failed to validate Docker info: failed to detect Docker info: Error response from daemon: client version 1.41 is too old. Minimum supported API version is 1.44
```

Checked the Docker containers route:

```bash
curl -sS -o /tmp/cadvisor-docker.out -w 'cadvisor_docker %{http_code}\n' http://localhost:8082/docker
```

Result:

```text
cadvisor_docker 301
```

Searched the repo for cAdvisor references:

```bash
rg -n "cadvisor|cAdvisor" Obervability-Stack/docker-compose.yml Obervability-Stack/ui-next/lib/platform-services.ts JOURNEY-RUNBOOK.md
```

Checked newer image availability:

```bash
docker manifest inspect gcr.io/cadvisor/cadvisor:v0.56.2
docker manifest inspect gcr.io/cadvisor/cadvisor:v0.53.0
docker manifest inspect gcr.io/cadvisor/cadvisor:v0.52.1
docker manifest inspect ghcr.io/google/cadvisor:v0.56.2
docker manifest inspect ghcr.io/google/cadvisor:v0.52.1
```

Results:

```text
gcr.io/cadvisor/cadvisor:v0.56.2 did not have a pullable manifest.
gcr.io/cadvisor/cadvisor:v0.53.0 did not have a pullable manifest.
gcr.io/cadvisor/cadvisor:v0.52.1 had a valid manifest and included arm64 support.
ghcr.io/google/cadvisor:v0.56.2 was not available.
ghcr.io/google/cadvisor:v0.52.1 was not available.
```

### Root Cause

The project was running:

```text
gcr.io/cadvisor/cadvisor:v0.49.1
```

That cAdvisor release bundled an older Docker client that attempted to talk to the Docker daemon using API version `1.41`.

Docker Desktop on this machine requires Docker API version `1.44` or newer.

That is why cAdvisor health still looked good while the Docker Containers page failed. The `/healthz` endpoint only proves the cAdvisor process is alive. The Docker Containers view needs cAdvisor to successfully talk to the Docker daemon, and that specific Docker API call was failing.

### Fix

Upgraded cAdvisor from:

```text
gcr.io/cadvisor/cadvisor:v0.49.1
```

to:

```text
gcr.io/cadvisor/cadvisor:v0.52.1
```

Files changed:

```text
Obervability-Stack/docker-compose.yml
Obervability-Stack/ui-next/lib/platform-services.ts
```

Rebuilt and restarted the affected services:

```bash
docker compose up -d --build devops-monitor-ui cadvisor
```

### Verification

Checked the services after the upgrade:

```bash
docker compose ps cadvisor devops-monitor-ui
```

Result:

```text
cadvisor gcr.io/cadvisor/cadvisor:v0.52.1 Up ... healthy 0.0.0.0:8082->8080
devops-monitor-ui Up ... healthy 0.0.0.0:4000->3000
```

Checked cAdvisor logs again:

```bash
docker compose logs --tail=80 cadvisor
```

Result:

```text
The Docker API version error was gone.
```

Checked the Docker containers page directly:

```bash
curl -sS -L -o /tmp/cadvisor-docker-after.out -w 'cadvisor_docker_after %{http_code}\n' http://localhost:8082/docker/
```

Result:

```text
cadvisor_docker_after 200
```

Checked the platform services API:

```bash
curl -fsS http://localhost:4000/api/services/platform
```

Result:

```text
8 of 8 platform services reported up.
cAdvisor reported currentVersion 0.52.1.
```

### Remaining Notes

After the upgrade, cAdvisor still logged some Docker Desktop filesystem mapping warnings about missing `overlayfs` `mount-id` files under `/rootfs/var/lib/docker/...`.

Those warnings are different from the Docker API compatibility error. They appear to be Docker Desktop filesystem mapping noise and do not block the cAdvisor Docker Containers page, which now returns `200`.

### Why This Matters

This is another useful learning moment for the project:

- A container can be `healthy` while a deeper feature inside the app is broken.
- Health checks should prove the most important behavior when possible, not only process liveness.
- Observability tools also need version maintenance.
- Docker Desktop upgrades can break older container tooling if the tool bundles an outdated Docker client.

## 2026-04-20 - Sidebar Service Status Was Demo Data Instead of Real Health

### Symptom

The UI sidebar had a `Service Status` section listing monitoring and logging tools, but it always showed a fixed set of services as healthy.

That meant the sidebar could say a service was healthy even if the actual container or endpoint was down.

### Commands Run

Searched for the sidebar status source:

```bash
rg -n "Service Status|service status|platformServices|usePlatformServices|Monitoring|Logging|status" Obervability-Stack/ui-next/app Obervability-Stack/ui-next/components Obervability-Stack/ui-next/lib
```

Listed the relevant UI files:

```bash
find Obervability-Stack/ui-next -maxdepth 3 -type f \( -name '*.tsx' -o -name '*.ts' \) | sort
```

Opened the sidebar component:

```bash
sed -n '1,260p' Obervability-Stack/ui-next/components/sidebar.tsx
sed -n '260,620p' Obervability-Stack/ui-next/components/sidebar.tsx
```

Opened the real platform service checker:

```bash
sed -n '1,360p' Obervability-Stack/ui-next/lib/platform-services.ts
sed -n '1,120p' Obervability-Stack/ui-next/app/api/services/platform/route.ts
```

Ran a type-check after the first edit:

```bash
npm run type-check
```

Problem found:

```text
components/sidebar.tsx(182,22): error TS7053: Element implicitly has an 'any' type because expression of type 'string' can't be used to index type ...
```

Ran the type-check again after fixing the icon-map typing:

```bash
npm run type-check
```

Result:

```text
tsc --noEmit completed successfully.
```

Rebuilt and restarted the UI container:

```bash
docker compose up -d --build devops-monitor-ui
```

The build completed successfully. Docker printed warnings about `NEXTAUTH_SECRET` and `AUTH_MODE` being used in Dockerfile `ARG`/`ENV` instructions. Those warnings are worth revisiting later for secret hygiene, but they did not block this change.

Checked the live platform API that now feeds the sidebar:

```bash
curl -fsS http://localhost:4000/api/services/platform
```

Result:

```text
8 of 8 platform services reported up.
Promtail reported currentVersion 3.5.8.
Loki reported currentVersion 2.8.0.
```

While checking this response, noticed an existing fallback URL formatting bug. When GitHub release checks returned `Unknown`, release URLs were built as `https:/github.com/...` instead of `https://github.com/...`.

Fixed the replacement logic in:

```text
Obervability-Stack/ui-next/lib/platform-services.ts
```

Verified the API response again and confirmed fallback release URLs now use the correct `https://github.com/...` format.

Checked the running containers:

```bash
docker compose ps devops-monitor-ui prometheus grafana alertmanager loki promtail node-exporter blackbox-exporter cadvisor
```

Result:

```text
devops-monitor-ui healthy
prometheus healthy
grafana healthy
alertmanager healthy
loki healthy
promtail running
node-exporter healthy
blackbox-exporter healthy
cadvisor healthy
```

### Root Cause

The sidebar had a hardcoded array:

```text
Prometheus healthy
Grafana healthy
Loki healthy
Node Exporter healthy
```

This was demo data. It did not call the live `/api/services/platform` endpoint, and it did not include several important observability services.

### Fix

Removed the hardcoded demo status list from the sidebar and wired the sidebar to:

```text
/api/services/platform
```

The sidebar now uses the same real health source as the Services page.

Added the important monitoring and logging services to the sidebar:

```text
Prometheus
Grafana
Alertmanager
Loki
Promtail
Node Exporter
Blackbox Exporter
cAdvisor
```

The sidebar now shows:

```text
live up/down status
response time in milliseconds
summary count such as 8/8 up
loading state while checks are running
error state if the live status API is unavailable
```

The shared platform-services hook now refreshes every 30 seconds while the UI is open, so the sidebar and Services page do not stay stale after the first page load.

Also corrected Promtail's fallback version from:

```text
2.8.0
```

to:

```text
3.5.8
```

This keeps the platform-service metadata aligned with the Promtail image version currently used in Docker Compose.

### Why This Matters

This removes a dangerous observability anti-pattern: a dashboard that looks healthy because the UI says so, not because the system was checked.

For learners, this makes the lesson more honest:

- UI status should come from real health checks.
- Demo data should not be mixed into operational screens.
- A sidebar status badge is only useful if it reflects the same live source used elsewhere.
- Shared status sources reduce disagreement between pages.

## 2026-04-20 - Add Disk Usage Label And Align Dashboard Helper Copy

### Request

The dashboard needed a visible disk usage label, and this helper sentence needed better alignment:

```text
The dashboard stays light; the deep operator workflow lives inside each app page.
```

### Commands Run

Opened the dashboard page:

```bash
sed -n '1,260p' Obervability-Stack/ui-next/app/dashboard/page.tsx
sed -n '260,620p' Obervability-Stack/ui-next/app/dashboard/page.tsx
```

Searched for existing disk usage and dashboard copy:

```bash
rg -n "dashboard stays light|Disk|disk|usage|node_filesystem|filesystem|managed app|Managed" Obervability-Stack/ui-next/app Obervability-Stack/ui-next/lib Obervability-Stack/prometheus.yml Obervability-Stack -g '!ui-next/node_modules/**'
```

Problem encountered:

```text
rg: Obervability-Stack/prometheus.yml: No such file or directory
```

This was harmless. The repo stores Prometheus configuration under `Obervability-Stack/prometheus/`, not a root-level `prometheus.yml`.

Ran the UI type-check:

```bash
npm run type-check
```

Result:

```text
tsc --noEmit completed successfully.
```

### Fix

Added a `Disk Usage` dashboard stat card using the existing live metric:

```text
metrics.data?.disk
```

The card uses the existing `formatPercent()` helper and changes tone by threshold:

```text
green below 80%
yellow at 80% and above
red at 90% and above
```

Changed the top dashboard stat grid from four columns to five columns on large screens so the new disk label fits alongside:

```text
Healthy Apps
Firing Alerts
CPU
Disk Usage
Network
```

Moved the helper sentence into a clean bordered control strip beside the Refresh button. The sentence now appears as a blue operator-guidance pill with a shield icon, which keeps it visually aligned with the dashboard's lightweight control-room purpose.

### Why This Matters

Disk pressure is one of the most important early-warning signals in a DevOps dashboard. Adding it to the lightweight dashboard keeps the page simple while still showing the core host health signals operators care about first:

- application health
- active alerts
- CPU pressure
- disk pressure
- network traffic

## 2026-04-20 - Redesign FoodPulse With Observability Stack Visual Language

### Request

FoodPulse needed to use the same styling direction, design language, and font feel as the Observability Stack while still feeling unique.

The design goal was not to make FoodPulse look like a generic clone. The goal was to make it feel like a first-party app in the same platform family:

- rounded glass panels
- strong gradient hero sections
- clean operational labels
- polished status pills
- clear live-data storytelling
- responsive layout

### Commands Run

Discovered the FoodPulse UI files:

```bash
find FoodPulse -maxdepth 4 -type f | sort | sed -n '1,240p'
find FoodPulse -maxdepth 3 -type f \( -name 'package.json' -o -name 'Dockerfile' -o -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.tsx' -o -name '*.jsx' \) | sort
sed -n '1,280p' FoodPulse/docker-compose.yml
```

Opened the FoodPulse React and CSS source:

```bash
sed -n '1,260p' FoodPulse/ui/src/App.jsx
sed -n '260,620p' FoodPulse/ui/src/App.jsx
sed -n '1,320p' FoodPulse/ui/src/styles.css
sed -n '320,760p' FoodPulse/ui/src/styles.css
cat FoodPulse/ui/package.json
sed -n '1,120p' FoodPulse/ui/src/main.jsx
sed -n '1,160p' FoodPulse/ui/Dockerfile
```

Checked API fields available to the UI:

```bash
sed -n '1,280p' FoodPulse/api/src/index.js
sed -n '280,620p' FoodPulse/api/src/index.js
find FoodPulse/postgres -maxdepth 3 -type f -print -exec sed -n '1,220p' {} \;
```

Compared the existing Observability Stack visual language:

```bash
find Obervability-Stack/ui-next/app -maxdepth 2 -name 'page.tsx' -print | sort | xargs rg -n "bg-gradient|rounded-2xl|shadow-xl|backdrop|VersionBadge|Live Data"
```

Built the FoodPulse UI locally:

```bash
npm run build
```

Result:

```text
vite build completed successfully.
```

Rebuilt and restarted the FoodPulse UI container:

```bash
docker compose up -d --build foodpulse-ui
```

Checked the live app and API:

```bash
curl -fsS -o /tmp/foodpulse-ui.html -w 'foodpulse_ui %{http_code}\n' http://localhost:8090
curl -fsS http://localhost:8090/api/health
curl -fsS http://localhost:8090/api/venues | head -c 500
docker compose ps foodpulse-ui foodpulse-api
```

Result:

```text
FoodPulse UI returned HTTP 200.
FoodPulse API health returned healthy.
Database check returned true.
Cache check returned true.
foodpulse-ui and foodpulse-api were running.
```

Used the Playwright skill for a browser render check:

```bash
command -v npx >/dev/null 2>&1 && echo npx-ok
mkdir -p output/playwright
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"
"$PWCLI" open http://localhost:8090
"$PWCLI" snapshot
"$PWCLI" screenshot --filename output/playwright/foodpulse-redesign.png --full-page
```

Problem encountered:

```text
The first screenshot attempt used the wrong wrapper syntax and failed with a selector parsing error.
```

Fix:

```bash
"$PWCLI" screenshot --filename output/playwright/foodpulse-redesign.png --full-page
```

The browser snapshot confirmed the page rendered with live data, restaurant cards, health state, and vote results.

### Design Changes

Reworked FoodPulse into a unique live dining operations board:

- added a dark gradient hero inspired by the Observability Stack dashboard hero treatment
- kept Manrope and JetBrains Mono for the same clean product/ops feel
- added a branded top bar with `FoodPulse`, `Resilient dining signal`, `Live board`, and health state
- added a right-side `Ops Snapshot` panel fed by real health data
- added `Failover posture` messaging to connect the UI to the HA lab story
- surfaced live Postgres and Redis health checks as operational rows
- redesigned restaurant cards as clean colored labels with each restaurant's accent color
- added vote totals directly into each restaurant label card
- redesigned the vote chart section as `Live pulse`
- kept the voting API behavior unchanged
- kept the page responsive for mobile and desktop

### Visual QA Note

The first browser screenshot showed the `Ops Snapshot` panel had too much empty vertical space on desktop.

Fixed by adding a `Failover posture` feature block inside the panel. This made the right side feel intentional and tied the UI back to FoodPulse's resilience-lab purpose.

Temporary Playwright artifacts were removed after review:

```bash
rm -rf .playwright-cli output
```

### Why This Matters

FoodPulse now feels like it belongs to the same platform family as the Observability Stack, but it has its own identity.

The page is no longer just a voting demo. It now tells the real FoodPulse story:

- restaurant voting on the surface
- live data underneath
- Postgres and Redis health in view
- HAProxy/failover context visible to learners
- a design language that fits the broader DevOps Easy Learning project

## 2026-04-20 - Replace FoodPulse Demo Restaurants With Real Restaurants

### Request

Replace the default FoodPulse restaurant names with:

```text
https://naijajollof.com/
https://www.tumerico.com/
https://street.restaurant/
https://www.roohrestaurants.com/
https://www.zandyrestaurant.com/
https://www.paitoronto.com/
```

Also:

- search the internet to learn about them
- write stronger headlines
- make each label cooler
- add a website button
- keep a vote button

### Research Notes

Used the restaurant websites and search results to shape the copy.

Summary of what informed the labels:

- `Naija Jollof`: Nigerian food, Toronto presence, jollof-focused comfort-food/catering story.
- `Tumerico`: Tucson vegetarian/vegan Latin restaurant, local ingredient story, Chef Wendy Garcia reputation.
- `STREET Taco and Beer Co.`: Tucson street-style Mexican tacos, tortas, local beer, and STREET Dog.
- `ROOH`: progressive Indian restaurant group with San Francisco, Palo Alto, and New Delhi locations.
- `Z & Y Restaurant`: San Francisco Chinatown Szechuan restaurant led by Chef Lijun Han.
- `PAI Northern Thai Kitchen`: Toronto Northern Thai restaurant with Michelin Guide recognition.

### Commands Run

Opened and inspected the FoodPulse data and UI paths:

```bash
sed -n '1,220p' FoodPulse/postgres/initdb/01-init-foodpulse.sh
sed -n '1,280p' FoodPulse/api/src/index.js
sed -n '1,260p' FoodPulse/ui/src/App.jsx
sed -n '1,420p' FoodPulse/ui/src/styles.css
```

Updated the database seed:

```text
FoodPulse/postgres/initdb/01-init-foodpulse.sh
```

Added two new venue fields:

```text
headline
website_url
```

Updated the API query so `/api/venues` returns:

```text
headline
website_url
```

Updated the React card to show:

```text
headline
signature item
spotlight
Visit website button
Vote button
```

Applied the schema and data change to the running local database because Docker init scripts only run when the database volume is first created:

```bash
docker exec -i foodpulse-db psql -U postgres -d foodpulse <<'SQL'
ALTER TABLE venues ADD COLUMN IF NOT EXISTS headline text NOT NULL DEFAULT '';
ALTER TABLE venues ADD COLUMN IF NOT EXISTS website_url text NOT NULL DEFAULT '';
DELETE FROM vote_events;
DELETE FROM venues;
INSERT INTO venues (slug, name, neighborhood, category, headline, signature_item, energy_score, price_band, accent_color, website_url, spotlight)
VALUES
  ('naija-jollof', 'Naija Jollof', 'Toronto, Canada', 'Nigerian comfort food', 'Lagos-style jollof energy served like a homecoming.', 'Jollof rice with chicken, plantain, and coleslaw', 94, '$$', '#16a34a', 'https://naijajollof.com/', 'Nigerian classics, catering, pickup, and delivery with a warm Toronto community feel.'),
  ('tumerico', 'Tumerico', 'Tucson, Arizona', 'Vegan Latin kitchen', 'Inventive Latin plant-based plates with local heritage ingredients.', 'Fresh vegan tacos and rotating Latin specials', 97, '$$', '#f59e0b', 'https://www.tumerico.com/', 'A celebrated Tucson kitchen led by Chef Wendy Garcia with bold vegetarian and vegan flavor.'),
  ('street-taco-beer', 'STREET Taco and Beer Co.', 'Tucson, Arizona', 'Street-style Mexican', 'Tacos, beer, and Tucson street-food swagger in every bite.', 'Street tacos with onion, cilantro, and cold beer', 90, '$', '#ef4444', 'https://street.restaurant/', 'Authentic street-style tacos, tortas, local beers, and the bacon-wrapped STREET Dog.'),
  ('rooh', 'ROOH', 'San Francisco, Palo Alto, New Delhi', 'Progressive Indian', 'Modern Indian dining with color, technique, and a little theatre.', 'Dahi puri with yogurt mousse and tamarind', 93, '$$$', '#7c3aed', 'https://www.roohrestaurants.com/', 'Progressive Indian menus across San Francisco, Palo Alto, and New Delhi with signature small plates.'),
  ('z-and-y-restaurant', 'Z & Y Restaurant', 'San Francisco Chinatown', 'Szechuan institution', 'Chinatown heat from a chef trusted by presidents.', 'Szechuan fish filet with flaming chili oil', 96, '$$', '#dc2626', 'https://www.zandyrestaurant.com/', 'Award-winning authentic Szechuan cuisine from Chef Lijun Han in historic San Francisco Chinatown.'),
  ('pai-northern-thai', 'PAI Northern Thai Kitchen', 'Toronto, Canada', 'Northern Thai', 'Toronto''s Northern Thai favorite with Michelin Guide shine.', 'Khao soi and Northern Thai street-market plates', 95, '$$', '#0ea5e9', 'https://www.paitoronto.com/', 'A Michelin Guide Toronto restaurant known for lively Northern Thai cooking and big downtown energy.');
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO foodpulse;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO foodpulse;
SQL
```

Result:

```text
ALTER TABLE
ALTER TABLE
DELETE 195
DELETE 4
INSERT 0 6
GRANT
GRANT
```

Important note:

```text
Replacing the demo restaurants deleted the previous demo vote history.
```

Rebuilt the FoodPulse API and UI:

```bash
docker compose up -d --build foodpulse-api foodpulse-ui
```

Built the UI locally:

```bash
npm run build
```

Verified the live API data:

```bash
curl -fsS http://localhost:8090/api/venues | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{const j=JSON.parse(s); console.log(j.venues.map(v=>`${v.name} | ${v.headline} | ${v.website_url}`).join("\n"));})'
```

Result:

```text
Naija Jollof | Lagos-style jollof energy served like a homecoming. | https://naijajollof.com/
PAI Northern Thai Kitchen | Toronto's Northern Thai favorite with Michelin Guide shine. | https://www.paitoronto.com/
ROOH | Modern Indian dining with color, technique, and a little theatre. | https://www.roohrestaurants.com/
STREET Taco and Beer Co. | Tacos, beer, and Tucson street-food swagger in every bite. | https://street.restaurant/
Tumerico | Inventive Latin plant-based plates with local heritage ingredients. | https://www.tumerico.com/
Z & Y Restaurant | Chinatown heat from a chef trusted by presidents. | https://www.zandyrestaurant.com/
```

Checked the live page and health:

```bash
curl -fsS -o /tmp/foodpulse-ui.html -w 'foodpulse_ui %{http_code}\n' http://localhost:8090
curl -fsS http://localhost:8090/api/health
```

Result:

```text
foodpulse_ui 200
{"status":"healthy","checks":{"database":true,"cache":true},...}
```

Used Playwright to confirm the browser-rendered cards:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"
"$PWCLI" open http://localhost:8090
"$PWCLI" snapshot
```

The browser snapshot confirmed:

- six restaurant cards render
- each card has `Visit website`
- each card has `Vote`
- the FoodPulse health panel still renders
- the live pulse section updates from the new venue data

Cleaned the temporary Playwright artifact:

```bash
rm -rf .playwright-cli
```

### Why This Matters

FoodPulse now feels more real and more useful as a demo application. Instead of fake restaurants, the app now uses recognizable restaurant brands with richer food stories, external website links, and a clean vote action.

This also taught an important platform lesson:

```text
Changing seed data is not enough when a database volume already exists.
```

We had to update both:

- the source seed script for future clean installs
- the running database for the current local environment

## 2026-04-20 - Add Little India And Perfect Chinese, Tighten FoodPulse Labels

### Request

Add two more restaurants:

```text
https://littleindia.ca/
https://perfectchineserestaurant.com/
```

Also:

- the labels were too big
- use the Observability Stack background color

### Research Notes

Used official/current restaurant information to write the FoodPulse card copy:

- `Little India`: Toronto Indian restaurant with dine-in, pickup, delivery, catering, and a large Indian menu.
- `Perfect Chinese Restaurant`: Scarborough Chinese restaurant with online ordering, seafood, dim sum, and late-night Chinese dining energy.

### Commands Run

Opened the relevant seed and style files:

```bash
sed -n '1,220p' FoodPulse/postgres/initdb/01-init-foodpulse.sh
sed -n '1,260p' FoodPulse/ui/src/styles.css
sed -n '260,620p' FoodPulse/ui/src/styles.css
sed -n '150,260p' FoodPulse/ui/src/App.jsx
```

Updated the seed script:

```text
FoodPulse/postgres/initdb/01-init-foodpulse.sh
```

Added:

```text
Little India
Perfect Chinese Restaurant
```

Updated the running database with an upsert so existing votes were preserved:

```bash
docker exec -i foodpulse-db psql -U postgres -d foodpulse <<'SQL'
INSERT INTO venues (slug, name, neighborhood, category, headline, signature_item, energy_score, price_band, accent_color, website_url, spotlight)
VALUES
  ('little-india-toronto', 'Little India', 'Toronto, Canada', 'Indian dining and catering', 'Downtown Toronto Indian comfort with a hundred-plus-item menu.', 'Butter chicken, tandoori plates, curries, and catering trays', 92, '$$', '#2563eb', 'https://littleindia.ca/', 'A long-running Toronto Indian restaurant offering dine-in, delivery, pickup, catering, and vegetarian-friendly options.'),
  ('perfect-chinese-restaurant', 'Perfect Chinese Restaurant', 'Scarborough, Canada', 'Chinese seafood and dim sum', 'Scarborough late-night dim sum and seafood built for every hour.', 'Dim sum, seafood, beef chow fun, and classic Chinese plates', 91, '$$', '#0f766e', 'https://perfectchineserestaurant.com/', 'A trusted Scarborough Chinese restaurant with online ordering, generous seating, seafood dishes, and dim sum energy.')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  neighborhood = EXCLUDED.neighborhood,
  category = EXCLUDED.category,
  headline = EXCLUDED.headline,
  signature_item = EXCLUDED.signature_item,
  energy_score = EXCLUDED.energy_score,
  price_band = EXCLUDED.price_band,
  accent_color = EXCLUDED.accent_color,
  website_url = EXCLUDED.website_url,
  spotlight = EXCLUDED.spotlight;
SQL
```

Result:

```text
INSERT 0 2
```

Updated the FoodPulse background to match the Observability Stack dashboard background more closely:

```text
radial-gradient(circle at top left, #dbeafe, transparent 34%)
linear-gradient(135deg, #f8fafc, #ffffff 45%, #eef2ff)
```

Tightened the restaurant cards:

- smaller card radius
- smaller card padding
- smaller category badges
- smaller score badges
- smaller metadata labels
- smaller title size
- tighter headline spacing
- tighter signature and spotlight text
- tighter Visit/Vote buttons

Built the UI:

```bash
npm run build
```

Result:

```text
vite build completed successfully.
```

Rebuilt FoodPulse:

```bash
docker compose up -d --build foodpulse-ui
```

Verified the API:

```bash
curl -fsS http://localhost:8090/api/venues | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{const j=JSON.parse(s); console.log(`count=${j.venues.length}`); console.log(j.venues.map(v=>`${v.name} | ${v.website_url}`).join("\n"));})'
```

Result:

```text
count=8
Naija Jollof | https://naijajollof.com/
PAI Northern Thai Kitchen | https://www.paitoronto.com/
ROOH | https://www.roohrestaurants.com/
STREET Taco and Beer Co. | https://street.restaurant/
Z & Y Restaurant | https://www.zandyrestaurant.com/
Little India | https://littleindia.ca/
Perfect Chinese Restaurant | https://perfectchineserestaurant.com/
Tumerico | https://www.tumerico.com/
```

Verified page and health:

```bash
curl -fsS -o /tmp/foodpulse-ui.html -w 'foodpulse_ui %{http_code}\n' http://localhost:8090
curl -fsS http://localhost:8090/api/health
docker compose ps foodpulse-ui foodpulse-api
```

Result:

```text
foodpulse_ui 200
FoodPulse health returned healthy with database=true and cache=true.
foodpulse-ui and foodpulse-api were running.
```

Used Playwright for browser-level verification:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"
"$PWCLI" open http://localhost:8090
"$PWCLI" snapshot
```

The snapshot confirmed:

- eight restaurant cards render
- Little India renders
- Perfect Chinese Restaurant renders
- each card has a Visit website link
- each card has a Vote button
- the labels are smaller
- the health/ops panel still renders

Cleaned the Playwright artifact:

```bash
rm -rf .playwright-cli
```

### Why This Matters

FoodPulse now has a fuller restaurant lineup while staying visually manageable. The background now matches the Observability Stack atmosphere more closely, and the tighter card labels make the eight-restaurant board easier to scan.

## 2026-04-20 - Reduce Oversized FoodPulse Hero And Section Labels

### Request

The following FoodPulse labels/headline were too big:

```text
Live pulse
Live Dining Board
Ops Snapshot
A food vote with production-grade resilience.
```

### Commands Run

Found the relevant React text and CSS selectors:

```bash
rg -n "welcome-title|section-label|panel-label|ops-kicker|panel-heading h2|Live pulse|Live Dining Board|Ops Snapshot|A food vote" FoodPulse/ui/src/App.jsx FoodPulse/ui/src/styles.css
sed -n '204,236p' FoodPulse/ui/src/styles.css
sed -n '584,598p' FoodPulse/ui/src/styles.css
```

Built the UI:

```bash
npm run build
```

Result:

```text
vite build completed successfully.
```

Rebuilt FoodPulse:

```bash
docker compose up -d --build foodpulse-ui
```

Verified the page and health:

```bash
curl -fsS -o /tmp/foodpulse-ui.html -w 'foodpulse_ui %{http_code}\n' http://localhost:8090
curl -fsS http://localhost:8090/api/health
```

Result:

```text
foodpulse_ui 200
FoodPulse health returned healthy with database=true and cache=true.
```

### Fix

Reduced the shared operational label size used by:

```text
Live Dining Board
Ops Snapshot
Vote Split
stats labels
```

Changed:

```text
font-size: 0.74rem
letter-spacing: 0.15em
```

to:

```text
font-size: 0.66rem
letter-spacing: 0.13em
```

Reduced the hero headline:

```text
font-size: clamp(2.6rem, 7vw, 5.9rem)
line-height: 0.92
```

to:

```text
font-size: clamp(2rem, 4.8vw, 4.15rem)
line-height: 0.98
```

Reduced the `Live pulse` heading:

```text
font-size: clamp(1.45rem, 2.4vw, 2.1rem)
```

to:

```text
font-size: clamp(1.15rem, 1.8vw, 1.55rem)
```

### Why This Matters

The FoodPulse page now has a calmer hierarchy. The hero still feels premium, but the typography no longer overwhelms the restaurant labels and live voting content.

## 2026-04-20 - Stop FoodPulse Vote Clicks From Reordering Restaurant Labels

### Question

Clicking one restaurant label appeared to affect other labels, even though the vote count only changed for the clicked restaurant.

### Root Cause

The vote was being recorded correctly for only the clicked restaurant.

The confusing behavior came from the UI update after a vote. After the API returned, the React state update did this:

```text
map the clicked restaurant to the new vote count
then sort the whole restaurant list by votes descending
```

That meant a single vote could move cards around. The other restaurants were not receiving votes, but their visual positions changed, which made it look like they were affected.

### Commands Run

Inspected the UI and API vote flow:

```bash
sed -n '1,360p' FoodPulse/ui/src/App.jsx
sed -n '1,260p' FoodPulse/api/src/index.js
git status --short
```

Built the UI:

```bash
npm run build
```

Result:

```text
vite build completed successfully.
```

Rebuilt FoodPulse:

```bash
docker compose up -d --build foodpulse-ui
```

Verified page and health:

```bash
curl -fsS -o /tmp/foodpulse-ui.html -w 'foodpulse_ui %{http_code}\n' http://localhost:8090
curl -fsS http://localhost:8090/api/health
```

Result:

```text
foodpulse_ui 200
FoodPulse health returned healthy with database=true and cache=true.
```

### Fix

Removed sorting from the restaurant label grid after a vote.

Before:

```text
Update clicked restaurant votes.
Sort all cards by vote count.
```

After:

```text
Update clicked restaurant votes in place.
Keep the restaurant label grid stable.
```

Added a separate ranked list for the `Live pulse` chart:

```text
rankedVenues = sortByVotes(data.venues)
```

The restaurant cards now keep their current order, while the chart and leader display can still rank by vote count.

### Why This Matters

This improves trust. Voting should feel local and predictable:

- the clicked card updates in place
- unrelated cards do not jump around
- the ranking still lives where users expect ranking to live: in the live pulse chart

## 2026-04-20 - OpenSIS ARM Startup, AppRole Automation, and Resolved Alert UX

### Situation

The user reported three issues:

```text
why is the resloved label not active on the active alert page?

why am i getting this:
[✘ Image docker.io/eseosaiyangbe/opensis-ui:dev Error no matching manifest for linux/arm64/v8 ...]
when i ran ./scripts/compose-start.sh?

why do i need to manually create app-approle and db-approle?
i want the script to automate this. because the pre-check failed because of this.
```

The user also noted that OpenSIS was originally created in a Linux environment. That mattered because this workstation is an Apple Silicon Mac, so Docker defaults to `linux/arm64/v8`.

### Commands Run

Inspected alert UI and Alertmanager client code:

```bash
rg -n "resolved|active alert|alerts|Alert" Obervability-Stack/ui-next -g '*.{ts,tsx,js,jsx,css}'
sed -n '1,340p' Obervability-Stack/ui-next/app/alerts/page.tsx
sed -n '340,760p' Obervability-Stack/ui-next/app/alerts/page.tsx
sed -n '760,930p' Obervability-Stack/ui-next/app/alerts/page.tsx
sed -n '1,340p' Obervability-Stack/ui-next/lib/alertmanager-api.ts
sed -n '1,170p' Obervability-Stack/ui-next/lib/hooks/use-alertmanager-alerts.ts
sed -n '1,80p' Obervability-Stack/ui-next/app/api/alerts/route.ts
```

Inspected OpenSIS Compose, startup, precheck, and Vault AppRole bootstrap code:

```bash
rg -n "approle|app-approle|db-approle|vault|VAULT|compose-start|platform|opensis-ui|eseosaiyangbe/opensis-ui" OpenSIS -g '*.{sh,yml,yaml,env,md,Dockerfile,json}'
ls -la OpenSIS/scripts OpenSIS
sed -n '1,240p' OpenSIS/scripts/compose-start.sh
sed -n '1,180p' OpenSIS/scripts/precheck.sh
sed -n '1,230p' OpenSIS/scripts/bootstrap.sh
cat OpenSIS/docker-compose.buildlocal.yaml
sed -n '250,300p' OpenSIS/docker-compose.yaml
```

Checked repository state:

```bash
git status --short
```

Checked OpenSIS docs for old image/startup wording:

```bash
rg -n "--build-local|opensis-ui:dev|ARM|Apple|linux/arm64|pulls docker.io" OpenSIS/README.md OpenSIS/docs OpenSIS/TROUBLESHOOTING.md OpenSIS/SECURITY_NOTES.md
```

That command failed because the pattern started with `--build-local`, and `rg` treated it as an option. The safe form would be:

```bash
rg -n -- "--build-local|opensis-ui:dev|ARM|Apple|linux/arm64|pulls docker.io" OpenSIS/README.md OpenSIS/docs OpenSIS/TROUBLESHOOTING.md OpenSIS/SECURITY_NOTES.md
```

Read the local startup docs directly:

```bash
sed -n '100,150p' OpenSIS/README.md
sed -n '50,90p' OpenSIS/docs/02-local-compose-guide.md
sed -n '10,30p' OpenSIS/TROUBLESHOOTING.md
```

Ran OpenSIS precheck after the fix:

```bash
./scripts/precheck.sh
```

Validated the merged Compose config with the local-build override:

```bash
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml config --quiet
```

Checked the Observability UI package scripts:

```bash
cat Obervability-Stack/ui-next/package.json
```

Reviewed the patch:

```bash
git diff -- OpenSIS/scripts/compose-start.sh OpenSIS/scripts/precheck.sh Obervability-Stack/ui-next/app/alerts/page.tsx
```

Ran UI type checking:

```bash
npm run type-check
```

Checked the OpenSIS startup help:

```bash
./scripts/compose-start.sh --skip-precheck --help
```

Started OpenSIS using the updated startup script:

```bash
./scripts/compose-start.sh
```

Verified OpenSIS container state:

```bash
sleep 20; docker compose ps vault vault-bootstrap vault-seed vault-agent-app vault-agent-db opensis-db opensis-ui
```

Verified OpenSIS UI endpoint:

```bash
sleep 20; curl -fsS -o /tmp/opensis-ui.html -w 'opensis_ui %{http_code}\n' http://localhost:8088
```

Verified managed app health from the Observability UI API:

```bash
sleep 20; curl -fsS http://localhost:4000/api/apps/health | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(JSON.stringify(j.summary,null,2)); console.log(j.apps.map(a=>`${a.name}: ${a.status}`).join("\n"));})'
```

Tried to check notification summary without quoting the URL:

```bash
curl -fsS http://localhost:4000/api/notifications/webhook?limit=100 | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(JSON.stringify(j.summary,null,2));})'
```

That failed because zsh treated the unquoted `?limit=100` as a filename glob.

Retried with the URL quoted:

```bash
curl -fsS 'http://localhost:4000/api/notifications/webhook?limit=100' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(JSON.stringify(j.summary,null,2));})'
```

Inspected notification webhook and inbox code:

```bash
sed -n '1,220p' Obervability-Stack/ui-next/app/api/notifications/webhook/route.ts
sed -n '1,260p' Obervability-Stack/ui-next/lib/notification-inbox.ts
sed -n '1,130p' Obervability-Stack/ui-next/lib/notification-service.ts
sed -n '210,270p' Obervability-Stack/ui-next/lib/notification-service.ts
```

Checked monitor UI logs:

```bash
docker compose logs --tail=120 devops-monitor-ui
```

Checked monitor UI environment and notification store:

```bash
docker exec devops-monitor-ui sh -lc 'printenv | sort | grep -E "CONFIG_PATH|NOTIFICATION|SLACK|SMTP|EMAIL" || true'
docker exec devops-monitor-ui sh -lc 'pwd; ls -la; ls -l config.json 2>/dev/null; wc -c config.json 2>/dev/null; sed -n "1,20p" config.json 2>/dev/null'
docker exec devops-monitor-ui sh -lc 'ls -l /app/data/notification-events.json 2>/dev/null; wc -c /app/data/notification-events.json 2>/dev/null; sed -n "1,20p" /app/data/notification-events.json 2>/dev/null'
```

Checked OpenSIS/Vault logs:

```bash
docker compose logs --tail=80 vault-bootstrap vault-seed vault-agent-app vault-agent-db opensis-ui
```

Rebuilt and restarted the monitoring UI:

```bash
docker compose up -d --build devops-monitor-ui
```

Final live checks:

```bash
curl -fsS -o /tmp/alerts-page.html -w 'alerts_page %{http_code}\n' http://localhost:4000/alerts
curl -fsS 'http://localhost:4000/api/notifications/webhook?limit=100' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(JSON.stringify(j.summary,null,2));})'
curl -fsS -o /tmp/opensis-ui.html -w 'opensis_ui %{http_code}\n' http://localhost:8088
curl -fsS http://localhost:4000/api/apps/health | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(JSON.stringify(j.summary,null,2)); console.log(j.apps.map(a=>`${a.name}: ${a.status}`).join("\n"));})'
docker compose ps devops-monitor-ui prometheus alertmanager loki
```

### Problems Found

The OpenSIS default Compose file used:

```text
docker.io/eseosaiyangbe/opensis-ui:dev
```

That image tag did not have a `linux/arm64/v8` manifest, so Apple Silicon Docker could not pull it:

```text
no matching manifest for linux/arm64/v8 in the manifest list entries
```

The repository already had a local-build override:

```text
docker-compose.buildlocal.yaml
```

But learners had to know to pass `--build-local`. On this Mac, the default path should be smart enough to avoid the incompatible image pull.

The OpenSIS precheck still required old bind-mounted AppRole directories:

```text
vault-agent/db-approle
vault-agent/app-approle
```

The current Compose design does not need those directories. AppRole credentials are written by `vault-bootstrap` into Docker volumes:

```text
app_runtime_approle
db_runtime_approle
```

So the precheck was enforcing stale filesystem requirements.

The Active Alerts page showed a `Resolved` card, but Alertmanager's `/api/v2/alerts` endpoint returns current alerts only. Resolved alerts disappear from that active feed. Resolved events are available through Alertmanager webhooks and our local notification inbox.

The notification inbox endpoint also failed because the store file existed but was empty:

```text
/app/data/notification-events.json
size: 0 bytes
```

The code tried to parse the empty file as JSON:

```text
JSON.parse("")
Unexpected end of JSON input
```

### Fix Applied

Updated `OpenSIS/scripts/compose-start.sh`:

```text
Detect ARM64 with uname -m.
Automatically use docker-compose.buildlocal.yaml on ARM64.
Keep --build-local for explicit local builds.
Add --pull-image for users who intentionally want the published image path.
```

Updated `OpenSIS/scripts/precheck.sh`:

```text
Stop requiring legacy app-approle and db-approle bind-mount directories.
Keep required Vault policy/config/template checks.
Print that AppRole runtime credentials are generated by vault-bootstrap into Docker volumes.
```

Updated OpenSIS learner docs:

```text
README.md now explains the ARM auto-build fallback.
docs/02-local-compose-guide.md now recommends ./scripts/compose-start.sh as the portable path.
TROUBLESHOOTING.md no longer tells Apple Silicon users to pull the incompatible image directly.
```

Updated the Active Alerts UI:

```text
Resolved card now reads Resolved History.
Resolved card links to /notifications.
Status filter explains that Alertmanager only returns current alerts on this page.
```

Updated notification inbox storage handling:

```text
An empty notification-events.json now returns [] instead of crashing.
Malformed local inbox JSON also fails safe to [].
```

### Verification

OpenSIS startup detected ARM and built locally:

```text
Detected Apple Silicon/ARM64 host.
The published docker.io/eseosaiyangbe/opensis-ui:dev image is not available for linux/arm64/v8, so this run will build opensis-ui locally.
```

OpenSIS containers:

```text
vault: healthy
vault-agent-app: up
vault-agent-db: up
opensis-db: healthy
opensis-ui: healthy
```

OpenSIS endpoint:

```text
opensis_ui 302
```

The `302` is acceptable because OpenSIS redirects into its application/install flow.

Vault bootstrap logs confirmed AppRole automation:

```text
Creating AppRoles...
Success! Data written to: auth/approle/role/opensis-db
Success! Data written to: auth/approle/role/opensis-app
Generating AppRole credentials...
Vault bootstrap completed successfully.
```

Vault agent logs confirmed the credentials were usable:

```text
authentication successful
rendered "/vault/templates/db.env.tpl" => "/vault/secrets/db.env"
rendered "/vault/templates/app.env.tpl" => "/vault/secrets/app.env"
```

Managed app health:

```text
totalApps: 4
healthyApps: 4
downApps: 0
OpenSIS: healthy
SwiftPay: healthy
MemFlip: healthy
FoodPulse: healthy
```

Notification inbox after the fix:

```text
total: 6
firing: 0
resolved: 6
```

Monitoring UI rebuild:

```text
Next.js compiled successfully.
devops-monitor-ui started healthy.
```

### Why We Did This

The OpenSIS image problem was not an application bug. It was an image publishing/platform compatibility issue. Linux AMD64 machines can pull images that Apple Silicon cannot. For a learning repo, the script should hide that platform wrinkle and choose the correct path automatically.

The AppRole problem was a stale precheck problem. The actual security model was already better: AppRole credentials belong in Docker runtime volumes, not learner-created bind-mounted folders. The precheck needed to match that design.

The resolved-alert problem was a UX model problem. Active alerts and resolved history are different streams:

```text
Active Alerts page: current Alertmanager alerts.
Notifications page: webhook history, including resolved events.
```

### Remaining Notes

For a future CI/CD improvement, publish `docker.io/eseosaiyangbe/opensis-ui:dev` as a multi-arch image with both `linux/amd64` and `linux/arm64` manifests. Then Mac and Linux users can both pull the same tag.

For Kubernetes, keep the same principle: bootstrap should create required auth roles and runtime credentials automatically. Learners should not manually create security plumbing before the stack can start.

## Phase 6 UI Polish: App Detail Runbook Handoff

### Date

2026-04-21

### Goal

Continue Phase 6 by tightening the demo/operator handoff on each managed app page.

The app detail pages already showed useful operational signals:

- probe latency
- uptime
- alerts
- recent logs
- first-response commands
- local run contract

The missing piece was the handoff from the UI into the Markdown runbooks. The page displayed the runbook path as text, but a presenter or learner still had to manually find the file.

### Commands Run

Checked roadmap status and recent project history:

```bash
rg -n "Phase|Roadmap|roadmap|Next|TODO|Kubernetes|k8s|handoff|operator|FoodPulse|OpenSIS|SwiftPay|Memflip" README.md JOURNEY-RUNBOOK.md INCIDENT-RESPONSE.md docs scripts -S
find . -maxdepth 3 -iname '*roadmap*' -o -iname '*runbook*' -o -iname '*handoff*' | sort
git status --short && git log --oneline -8
```

The first command printed an expected warning because this repo does not currently have a root `docs/` directory:

```text
rg: docs: No such file or directory (os error 2)
```

Read the roadmap and current Phase 6 runbook sections:

```bash
sed -n '1,260p' PROJECT-ROADMAP.md
sed -n '6860,7310p' JOURNEY-RUNBOOK.md
sed -n '7590,7990p' JOURNEY-RUNBOOK.md
```

Listed the app detail page files:

```bash
find Obervability-Stack/ui-next/app/services -maxdepth 3 -type f | sort
```

Tried to read the bracketed Next.js route without shell quoting:

```bash
sed -n '1,280p' Obervability-Stack/ui-next/app/services/[appId]/page.tsx
```

That failed because zsh interpreted `[appId]` as a glob pattern:

```text
zsh:1: no matches found: Obervability-Stack/ui-next/app/services/[appId]/page.tsx
```

Fixed the command by quoting the route path:

```bash
sed -n '1,360p' 'Obervability-Stack/ui-next/app/services/[appId]/page.tsx'
sed -n '360,760p' 'Obervability-Stack/ui-next/app/services/[appId]/page.tsx'
```

Read app inventory and available operator docs:

```bash
sed -n '1,260p' Obervability-Stack/ui-next/lib/monitored-apps.ts
sed -n '220,520p' Obervability-Stack/ui-next/lib/monitored-apps.ts
find Obervability-Stack/docs -maxdepth 1 -type f | sort
```

Checked relevant UI files and package scripts:

```bash
find Obervability-Stack/ui-next -maxdepth 3 -type f \( -name '*.css' -o -name '*.tsx' \) | sort | sed -n '1,160p'
cat Obervability-Stack/ui-next/package.json
```

Reviewed the changed files:

```bash
git diff --stat
git diff -- 'Obervability-Stack/ui-next/app/services/[appId]/page.tsx' DEMO-WALKTHROUGH.md JOURNEY-RUNBOOK.md | sed -n '1,260p'
```

Ran the control-plane UI checks:

```bash
npm run type-check
npm run build
```

Rebuilt and restarted the running control-plane UI container:

```bash
docker compose up -d --build devops-monitor-ui
```

Verified the rebuilt UI container:

```bash
docker compose ps devops-monitor-ui
```

Checked the protected app detail route:

```bash
curl -fsSI http://localhost:4000/services/foodpulse
```

Checked the app overview API still returned healthy FoodPulse data:

```bash
curl -fsS http://localhost:4000/api/apps/foodpulse/overview | jq '{app: .app.name, status: .health.status, alerts: (.alerts | length), logs: (.recentLogs | length)}'
```

Ran the full operator check:

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
```

### Changes Made

Updated the app detail page:

```text
Obervability-Stack/ui-next/app/services/[appId]/page.tsx
```

Changes:

- added a repository URL constant for stable GitHub documentation links
- added `runbookUrl` to each app's operator guide
- added an `Open operator runbook` button
- added a `View incident drills` button
- kept the local Markdown path visible for operators working from the repo

Updated the demo walkthrough:

```text
DEMO-WALKTHROUGH.md
```

Changes:

- added the runbook and incident-drill buttons to the control-plane demo checklist
- updated the recommended Phase 6 flow so presenters click from app page to Markdown runbook and drill catalog

### Problems And Fixes

Problem: The bracketed Next.js route path failed in zsh when read without quotes.

Fix: Quote bracketed route paths:

```bash
sed -n '1,360p' 'Obervability-Stack/ui-next/app/services/[appId]/page.tsx'
```

Problem: App pages showed runbook paths but did not provide a clickable documentation handoff.

Fix: Add explicit action buttons:

```text
Open operator runbook
View incident drills
```

Problem: The local `npm run build` still prints expected production-environment warnings when run outside the Compose runtime:

```text
NEXTAUTH_SECRET is not set
NEXTAUTH_URL is not set
DATABASE_URL is missing, using JWT-only mode
```

Fix: No code change in this slice. The build completed successfully, and these warnings are already known for the local build path.

Problem: The Docker build repeated an existing Dockerfile warning about secrets in `ARG`/`ENV`:

```text
SecretsUsedInArgOrEnv
```

Fix: No code change in this slice. This is a production-hardening follow-up and should not block the Phase 6 runbook handoff polish.

### Verification

TypeScript passed:

```text
tsc --noEmit
```

Production build passed and still includes the managed app detail route:

```text
/services/[appId]
```

The rebuilt UI container is healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

The protected FoodPulse detail page redirects to sign-in as expected:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fservices%2Ffoodpulse
```

The FoodPulse app overview API returned healthy data:

```json
{
  "app": "FoodPulse",
  "status": "healthy",
  "alerts": 0,
  "logs": 10
}
```

The full operator check passed:

```text
Checks passed: 28/28
Inventory validation passed.
All monitored apps are currently healthy.
```

### Why This Matters

Phase 6 is about making the platform teachable and demo-ready.

This change makes the operator journey more natural:

```text
Dashboard -> Managed app label -> App detail page -> Operator runbook -> Incident drill catalog
```

That is the workflow we want reviewers, students, and future operators to understand without needing verbal patch notes.

## Phase 6 Logs Page Timestamp And Retention Fix

### Date

2026-04-21

### Goal

Fix the Logs page showing `Invalid Date` and decide whether log cleanup should be manual deletion or automatic retention.

The user noticed:

```text
on the log page fron side menu bar, the logs are showing invalid date
```

The user also asked whether logs should be clearable/deletable or whether we should set a retention date.

### Decision

Use automatic retention rather than a broad "clear logs" button.

Reasoning:

- logs are evidence during incident response
- a one-click clear button can hide the timeline we need during troubleshooting
- retention protects disk usage without destroying recent operational history
- retention maps better to the future Kubernetes version, where log lifecycle policies are normally platform-managed

For this local learning platform, we set Loki retention to 7 days:

```text
168h
```

### Commands Run

Inspected the Logs page:

```bash
sed -n '1,320p' Obervability-Stack/ui-next/app/logs/page.tsx
sed -n '320,560p' Obervability-Stack/ui-next/app/logs/page.tsx
```

Inspected the Loki API client and hook:

```bash
sed -n '1,260p' Obervability-Stack/ui-next/lib/loki-api.ts
sed -n '1,180p' Obervability-Stack/ui-next/lib/hooks/use-loki-logs.ts
sed -n '1,80p' Obervability-Stack/ui-next/app/api/logs/query/route.ts
```

Located Loki and Promtail config:

```bash
find Obervability-Stack -maxdepth 3 -iname '*loki*' -o -iname '*promtail*' | sort
sed -n '1,140p' Obervability-Stack/loki/config.yml
sed -n '1,120p' Obervability-Stack/loki/promtail-config.yml
```

Searched for timestamp, delete, retention, and Loki references:

```bash
rg -n "retention|delete|compactor|limits_config|schema_config|storage_config|loki|Invalid Date|toLocale|timestamp|Date\(" Obervability-Stack -S -g '!**/node_modules/**'
```

Checked live log timestamps returned by the Logs API:

```bash
curl -fsS 'http://localhost:4000/api/logs/query?timeRange=15m&limit=3' | jq '.logs[] | {timestamp, line: (.line | .[0:80])}'
```

Validated timestamp conversion locally:

```bash
node - <<'NODE'
const timestamp = '1776761544961882730';
const numericTimestamp = Number(timestamp);
const milliseconds = numericTimestamp > 1_000_000_000_000_000 ? numericTimestamp / 1_000_000 : numericTimestamp;
const date = new Date(milliseconds);
console.log(date.toLocaleString());
console.log(Number.isNaN(date.getTime()) ? 'invalid' : 'valid');
NODE
```

Validated the Loki config inside the running container:

```bash
docker compose exec -T loki sh -lc 'command -v loki || find / -name loki -type f 2>/dev/null | head -5'
docker compose exec -T loki sh -lc 'loki -config.file=/etc/loki/local-config.yaml -verify-config=true'
```

Ran UI checks:

```bash
npm run type-check
npm run build
```

Rebuilt/restarted the affected services:

```bash
docker compose up -d --build loki devops-monitor-ui
docker compose restart loki
```

Verified runtime health and the 1-day log filter:

```bash
docker compose ps loki devops-monitor-ui
curl -fsS http://localhost:3100/ready
curl -fsS 'http://localhost:4000/api/logs/query?timeRange=1d&limit=1' | jq '{count: (.logs | length), first: .logs[0].timestamp, query: .query, timeRange: .filters.timeRange}'
```

Checked Loki startup logs for retention/compactor state:

```bash
docker compose logs --tail=80 loki | rg -n "retention|compactor|ready|error|invalid|failed|retention_period" -i || true
```

Reviewed and updated Loki docs:

```bash
sed -n '50,140p' Obervability-Stack/docs/LOKI_INTEGRATION.md
```

### Root Cause

Loki returns log timestamps as nanoseconds since epoch:

```text
1776761544961882730
```

The Logs page was doing:

```ts
new Date(timestamp).toLocaleString()
```

That passes a nanosecond string directly into `Date`. JavaScript dates expect milliseconds or an ISO timestamp, so the browser rendered `Invalid Date`.

### Fix

Updated the Logs page timestamp formatter:

```text
Obervability-Stack/ui-next/app/logs/page.tsx
```

The formatter now:

- detects numeric Loki timestamps
- converts nanoseconds to milliseconds
- falls back safely for ISO timestamps
- returns `Unknown time` instead of `Invalid Date` if parsing fails

Also fixed a related filter mismatch:

```text
Obervability-Stack/ui-next/lib/loki-api.ts
```

The UI offered `1d`, but the API only handled `24h`. Selecting `1d` previously fell back to the default 1-hour range. The API now treats `1d` and `24h` as the same 24-hour range.

Configured Loki retention:

```text
Obervability-Stack/loki/config.yml
```

Added:

```yaml
retention_period: 168h
```

The compactor was already enabled with:

```yaml
retention_enabled: true
retention_delete_delay: 2h
```

Updated documentation:

```text
Obervability-Stack/docs/LOKI_INTEGRATION.md
```

### Problems And Fixes

Problem: The Logs page displayed `Invalid Date`.

Fix: Convert Loki nanosecond timestamps to milliseconds before formatting.

Problem: The UI exposed a `1d` time range, but the backend only handled `24h`.

Fix: Add `1d` support in `getTimeRange`.

Problem: Loki docs still described infinite retention.

Fix: Update the Loki integration docs to describe 7-day retention.

Problem: `docker compose up -d --build loki devops-monitor-ui` rebuilt the UI and kept Loki running, but Loki needed a restart to load the mounted config change.

Fix:

```bash
docker compose restart loki
```

### Verification

Loki config validation passed:

```text
config is valid
```

TypeScript passed:

```text
tsc --noEmit
```

Next production build passed.

Loki became healthy after restart:

```text
loki   Up ... (healthy)
```

The UI container became healthy after rebuild:

```text
devops-monitor-ui   Up ... (healthy)
```

The 1-day filter was accepted and returned log data:

```json
{
  "count": 1,
  "first": "1776761544961882730",
  "query": "{container=~\".+\"}",
  "timeRange": "1d"
}
```

Local timestamp conversion returned a valid date:

```text
4/21/2026, 4:52:24 AM
valid
```

Loki logs showed the compactor starting:

```text
compactor is ACTIVE in the ring
this instance has been chosen to run the compactor, starting compactor
```

## Phase 6 Logs Page Severity Filter Fix

### Date

2026-04-21

### Goal

Fix the Logs page severity dropdown.

The user reported that only `All Levels` worked, while `info`, `error`, `warn`, and `debug` did not filter correctly.

### Commands Run

Checked the live metadata returned by the logs API:

```bash
curl -fsS http://localhost:4000/api/logs/metadata | jq .
```

Tested each severity filter against the live API:

```bash
for level in all info error warn debug; do
  echo "--- $level"
  curl -fsS "http://localhost:4000/api/logs/query?timeRange=1h&severity=$level&limit=3" |
    jq '{count:(.logs|length), query, samples:[.logs[]? | {labels, line:(.line|.[0:120])}]}'
done
```

Read the Loki API query builder:

```bash
sed -n '130,230p' Obervability-Stack/ui-next/lib/loki-api.ts
```

Read the Logs page UI severity handling:

```bash
sed -n '1,150p' Obervability-Stack/ui-next/app/logs/page.tsx
```

Verified generated queries locally:

```bash
npx tsx -e "import { lokiAPI } from './lib/loki-api'; for (const severity of ['all','info','error','warn','debug']) console.log(severity, lokiAPI.buildQuery({severity, timeRange:'1h'}));"
```

Ran UI checks:

```bash
npm run type-check
npm run build
```

Rebuilt the running UI:

```bash
docker compose up -d --build devops-monitor-ui
```

Retested each severity filter after rebuild:

```bash
for level in all info error warn debug; do
  echo "--- $level"
  curl -fsS "http://localhost:4000/api/logs/query?timeRange=7d&severity=$level&limit=5" |
    jq '{count:(.logs|length), query, samples:[.logs[]? | {severity:(if (.labels.level // .labels.severity) then (.labels.level // .labels.severity) else "inferred" end), line:(.line|.[0:120])}]}'
done
```

Checked full error samples:

```bash
curl -fsS "http://localhost:4000/api/logs/query?timeRange=7d&severity=error&limit=10" | jq -r '.logs[].line' | sed -n '1,10p'
```

### Root Cause

The old query builder assumed logs had a Loki label named `level`:

```logql
{level="error"}
```

But our Docker/Promtail logs mostly have labels such as:

```text
compose_project
compose_service
container
```

They do not consistently have a `level` label. That meant `info`, `error`, `warn`, and `debug` were filtering on a label that usually did not exist.

### Fix

Changed severity filtering to happen in the Logs API after Loki returns the recent log batch.

Updated:

```text
Obervability-Stack/ui-next/lib/loki-api.ts
Obervability-Stack/ui-next/app/api/logs/query/route.ts
Obervability-Stack/ui-next/app/logs/page.tsx
```

The API now:

- queries the relevant Loki stream normally
- infers severity from `level`/`severity` labels if present
- otherwise infers severity from log-line text
- filters the returned logs before sending them to the UI
- fetches a larger batch when a severity filter is selected so filtering has enough rows to work with

The UI now also uses the same severity inference idea for the badge color/icon, so plain Docker access logs show as `INFO` instead of defaulting incorrectly.

### Verification

Before the fix, live API queries looked like this:

```text
info  -> {level="info"}  -> 0 logs
error -> {level="error"} -> 0 logs
warn  -> {level="warn"}  -> 0 logs
debug -> {level="debug"} -> 0 logs
```

After the fix, the query stays on the real Docker log stream:

```text
{container=~".+"}
```

Then the API applies severity filtering.

Live results after rebuild:

```text
all   -> 5 logs
info  -> 5 logs
error -> 5 logs
warn  -> 0 logs
debug -> 0 logs
```

The `warn` and `debug` results were empty because there were no matching warning/debug lines in the selected range, not because the filter was broken.

Error samples now contain real error-like lines:

```text
level=error caller="error encoding and sending metric family..."
```

### Why This Matters

This makes the Logs page useful for operators.

The page no longer depends on every app using the same structured logging format. That is important for this workspace because it manages mixed applications: Node services, PHP/OpenSIS, HAProxy, Loki, Prometheus, Docker access logs, and older demo apps.

## Phase 6 Platform Versions Page Polish

### Goal

Continue Phase 6 by removing the old demo-style Version page and replacing it with a real operator-facing Platform Versions page.

The old page talked about downloads, starring the project, and a generic UI overhaul. That was not useful for this project because operators need to know which monitoring and logging services are running, what version each service is on, whether anything is down, and whether an update is available.

### Commands Run

Checked the current branch, recent commits, and roadmap/runbook context:

```bash
git status --short && git log --oneline -6
```

Searched for Phase 6 polish candidates, stale placeholders, and rough UI areas:

```bash
rg -n "Next Step|Phase 6|polish|TODO|demo|rough|stale|not working|placeholder|coming soon|Invalid|FIXME" PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md README.md DEMO-WALKTHROUGH.md Obervability-Stack/ui-next/app Obervability-Stack/ui-next/components Obervability-Stack/ui-next/lib -S -g '!**/node_modules/**'
```

Listed UI app routes:

```bash
find Obervability-Stack/ui-next/app -maxdepth 2 -type f | sort
```

Reviewed the Phase 6 roadmap section:

```bash
sed -n '488,570p' PROJECT-ROADMAP.md
```

Reviewed the old Version page and the existing service/version helpers:

```bash
sed -n '1,240p' Obervability-Stack/ui-next/app/version/page.tsx
sed -n '1,380p' Obervability-Stack/ui-next/lib/version-monitor.ts
sed -n '1,180p' Obervability-Stack/ui-next/app/admin/page.tsx
sed -n '1,260p' Obervability-Stack/ui-next/components/version-badge.tsx
sed -n '1,220p' Obervability-Stack/ui-next/lib/hooks/use-platform-services.ts
sed -n '1,380p' Obervability-Stack/ui-next/lib/platform-services.ts
```

Checked the live platform service API:

```bash
curl -fsS http://localhost:4000/api/services/platform | jq '{total:.total, up:.up, down:.down, updatesAvailable:.updatesAvailable, services:[.services[] | {id,name,status,currentVersion,latestVersion,updateAvailable,publicUrl}]}'
```

The first `jq` summary fields returned `null` because the API uses `summary.total`, `summary.up`, `summary.down`, and `summary.updatesAvailable`. The service entries returned correctly, so the page was wired to the existing `usePlatformServices` hook instead of hand-rolling another API shape.

Edited:

```text
Obervability-Stack/ui-next/app/version/page.tsx
```

Ran TypeScript validation:

```bash
npm run type-check
```

Ran the production build:

```bash
npm run build
```

Rebuilt and restarted the running monitor UI:

```bash
docker compose up -d --build devops-monitor-ui
```

Verified the running container:

```bash
docker compose ps devops-monitor-ui
```

Verified the protected Version route:

```bash
curl -fsSI http://localhost:4000/version
```

Verified the live platform inventory API:

```bash
curl -fsS http://localhost:4000/api/services/platform | jq '{summary, services:[.services[] | {id,name,status,currentVersion,latestVersion,updateAvailable,publicUrl}]}'
```

Ran the full operator check:

```bash
./scripts/devops-monitor.sh operator
```

### Problem Encountered

The first type-check failed because the page imported a Lucide icon named `TriangleAlert`.

The installed `lucide-react` package in this app exposes the icon as `AlertTriangle`, not `TriangleAlert`.

### Fix

Changed the import and usage from:

```tsx
TriangleAlert
```

to:

```tsx
AlertTriangle
```

Then reran:

```bash
npm run type-check
```

The check passed after the icon name was corrected.

### What Changed

Replaced the old static Version page with a live Platform Versions page.

The new page shows:

- live service count
- healthy service count
- down service count
- update count
- monitoring services
- logging services
- current version
- latest known version
- service status
- probe latency
- links to each service URL
- links to each release page
- last checked timestamp
- manual refresh button

This keeps the page aligned with the rest of the Phase 6 direction: fewer demo screens, more operator truth.

### Verification

`npm run type-check` passed.

`npm run build` passed.

The Docker rebuild completed and recreated `devops-monitor-ui`.

The running container was healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

The `/version` route returned a `307` redirect to sign-in:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fversion
```

That is expected because `/version` is a protected operator page.

The platform API reported:

```text
8 total services
8 up
0 down
0 updates available
```

The full operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

### Known Notes

The local production build still prints known environment warnings about `NEXTAUTH_SECRET`, `NEXTAUTH_URL`, and `DATABASE_URL` when running outside the full runtime environment. The build still succeeds, and the Docker runtime has the correct environment from Compose.

The Docker build also prints a warning about secrets being passed as build args or environment variables. That is existing Dockerfile hygiene work and should be handled as a separate hardening task so we do not mix security refactoring into this UI polish slice.

## Phase 6 Platform Version Latest-Check Cache

### Goal

Fix the first cause of `Latest` showing `Unknown` on the Version page.

The page gets current versions from local containers, but it gets latest versions from GitHub release API URLs. GitHub rate-limited the current public IP, so every latest-version request returned `403 API rate limit exceeded`.

We decided to implement caching first instead of immediately requiring a GitHub token. That keeps the project easier for learners to run while reducing repeated GitHub API calls.

### Commands Run

Inspected the version-service data path and the live API response:

```bash
sed -n '1,420p' Obervability-Stack/ui-next/lib/platform-services.ts
sed -n '1,220p' Obervability-Stack/ui-next/app/api/services/platform/route.ts
curl -fsS http://localhost:4000/api/services/platform | jq '.services[] | {id,name,currentVersion,latestVersion,updateAvailable,releaseUrl,lastChecked,status}'
```

Confirmed GitHub was rate-limiting the host:

```bash
curl -fsSI https://api.github.com/repos/prometheus/prometheus/releases/latest | sed -n '1,30p'
```

Confirmed the same behavior from inside the running UI container:

```bash
docker exec devops-monitor-ui node -e "fetch('https://api.github.com/repos/prometheus/prometheus/releases/latest',{headers:{Accept:'application/vnd.github+json','User-Agent':'devops-easy-learning'}}).then(async r=>{console.log(r.status, r.statusText); console.log('rate', r.headers.get('x-ratelimit-remaining')); console.log((await r.text()).slice(0,300));}).catch(e=>{console.error(e.name, e.message); process.exit(1);})"
docker exec devops-monitor-ui node -e "fetch('https://api.github.com/repos/prometheus/prometheus/releases/latest').then(async r=>{console.log(r.status, r.statusText); console.log((await r.text()).slice(0,300));}).catch(e=>{console.error(e.name, e.message); process.exit(1);})"
```

Converted the GitHub reset epoch into local time:

```bash
date -r 1776764427 '+%Y-%m-%d %H:%M:%S %Z'
```

Reviewed the file being changed:

```bash
sed -n '1,340p' Obervability-Stack/ui-next/lib/platform-services.ts
cat Obervability-Stack/ui-next/package.json
find Obervability-Stack/ui-next -maxdepth 3 -type d \( -name node_modules -o -name .next \) -prune -o -type f | sed -n '1,160p'
```

Edited:

```text
Obervability-Stack/ui-next/lib/platform-services.ts
```

Validated TypeScript:

```bash
npm run type-check
```

Reviewed the code diff:

```bash
git diff -- Obervability-Stack/ui-next/lib/platform-services.ts
```

Ran the production build:

```bash
npm run build
```

Rebuilt and restarted the running UI:

```bash
docker compose up -d --build devops-monitor-ui
```

Verified the running UI container:

```bash
docker compose ps devops-monitor-ui
```

Called the platform API twice through the same endpoint the Version page uses:

```bash
curl -fsS http://localhost:4000/api/services/platform | jq '{summary, versions:[.services[] | {id,latestVersion,currentVersion}]}'
curl -fsS http://localhost:4000/api/services/platform | jq '{summary, versions:[.services[] | {id,latestVersion,currentVersion}]}'
```

Checked recent UI container logs:

```bash
docker logs --tail 80 devops-monitor-ui
```

### Problem Encountered

The `Latest` value was not failing because the local services were down. Current versions were still available from local service endpoints.

The failure was specifically on the external GitHub latest-release lookup:

```text
HTTP 403
API rate limit exceeded
x-ratelimit-remaining: 0
```

GitHub reset time decoded locally to:

```text
2026-04-21 05:40:27 EDT
```

### Fix

Added an in-memory latest-version cache in:

```text
Obervability-Stack/ui-next/lib/platform-services.ts
```

The cache now:

- stores successful latest-version checks for 6 hours
- stores failed latest-version checks for 15 minutes
- de-duplicates concurrent checks for the same release URL
- prevents Loki and Promtail from asking the same Grafana Loki release URL twice at the same time
- keeps the Version page functional even when GitHub is temporarily unavailable or rate-limited

### Verification

`npm run type-check` passed.

`npm run build` passed.

The Docker rebuild completed and restarted `devops-monitor-ui`.

The running container was healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

The platform API still returned the correct local service summary:

```text
8 total services
8 up
0 down
0 updates available
```

`latestVersion` still showed `Unknown` during verification because GitHub had not lifted the active rate limit yet. That is expected. This cache prevents repeated refreshes from continuing to hammer GitHub, but it does not bypass an already-active GitHub API rate limit.

### Why This Matters

This is the right first step because it improves reliability without requiring every learner to create a GitHub token immediately.

The next improvement should be optional `GITHUB_TOKEN` support plus a clearer UI label such as `Rate limited` or `Check unavailable` instead of the vague `Unknown`.

## Phase 6 Platform Version Status Labels

### Goal

Continue Phase 6 by making the Version and Services pages more honest for operators.

After adding latest-version caching, the UI still displayed `Unknown` when GitHub rate-limited latest-release checks. That was technically true, but it was not helpful. Operators should see whether the latest version was actually checked, rate-limited, or unavailable.

### Commands Run

Checked the clean starting point and latest commits:

```bash
git status --short && git log --oneline -5
```

Reviewed the Phase 6 roadmap:

```bash
sed -n '488,620p' PROJECT-ROADMAP.md
```

Searched for Phase 6 polish candidates and remaining vague/latest-version labels:

```bash
rg -n "Phase 6|Next Step|TODO|placeholder|Unknown|Rate limited|Check unavailable|GITHUB_TOKEN|demo|coming soon|Download|Support the Project|Version" PROJECT-ROADMAP.md JOURNEY-RUNBOOK.md Obervability-Stack/ui-next/app Obervability-Stack/ui-next/components Obervability-Stack/ui-next/lib -S -g '!**/node_modules/**'
```

Reviewed the affected pages and shared platform service code:

```bash
sed -n '1,260p' Obervability-Stack/ui-next/app/services/page.tsx
sed -n '1,240p' Obervability-Stack/ui-next/app/version/page.tsx
sed -n '1,420p' Obervability-Stack/ui-next/lib/platform-services.ts
```

Edited:

```text
Obervability-Stack/ui-next/lib/platform-services.ts
Obervability-Stack/ui-next/app/version/page.tsx
Obervability-Stack/ui-next/app/services/page.tsx
```

Validated TypeScript and reviewed the diff:

```bash
npm run type-check
git diff -- Obervability-Stack/ui-next/lib/platform-services.ts Obervability-Stack/ui-next/app/version/page.tsx Obervability-Stack/ui-next/app/services/page.tsx
```

Ran the production build:

```bash
npm run build
```

Rebuilt and restarted the running monitor UI:

```bash
docker compose up -d --build devops-monitor-ui
```

Verified the running UI container:

```bash
docker compose ps devops-monitor-ui
```

Verified the live platform API response:

```bash
curl -fsS http://localhost:4000/api/services/platform | jq '{summary, services:[.services[] | {id,currentVersion,latestVersion,latestVersionStatus,latestVersionError,updateAvailable}]}'
```

Verified the protected Version route:

```bash
curl -fsSI http://localhost:4000/version
```

Ran the operator check:

```bash
./scripts/devops-monitor.sh operator
```

### Problem Encountered

The API only returned:

```text
latestVersion: "Unknown"
```

That meant the UI could not distinguish between:

- GitHub rate limit
- GitHub unavailable
- service release metadata unavailable
- a version that had not been checked yet

This created a weak demo and operator experience because `Unknown` sounded like the platform did not know what it was doing.

### Fix

Added a structured latest-version check status to the platform service API.

New API fields:

```text
latestVersionStatus
latestVersionError
```

Possible status values:

```text
checked
rate_limited
unavailable
```

The GitHub latest-release checker now classifies HTTP `403` responses as:

```text
rate_limited
```

The Version page now displays:

```text
Rate limited
Check unavailable
Not checked
```

instead of always showing:

```text
Unknown
```

The Services page now uses the same language in the monitoring/logging service labels.

### Verification

`npm run type-check` passed.

`npm run build` passed.

The Docker rebuild completed and restarted the monitor UI.

The running container was healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

The platform API now reports the actual reason for missing latest versions:

```text
latestVersion: "Unknown"
latestVersionStatus: "rate_limited"
latestVersionError: "GitHub API rate limit reached"
```

The `/version` route still correctly redirects unauthenticated users:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fversion
```

The full operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

### Why This Matters

This makes the control plane feel more trustworthy.

The platform is not pretending everything is fine, and it is not hiding behind vague wording. It now tells the operator what happened: the current versions are known locally, but the external latest-release check is currently rate-limited by GitHub.

## Phase 6 Admin Panel And User Management

### Goal

Turn the Admin Panel from a mock-data screen into a real user-management surface backed by Prisma and protected by server-side admin checks.

The admin page already looked polished, but it was not operationally honest yet. It rendered hardcoded users, fake dashboard/config counts, and buttons that did not call any backend. Because this project is becoming an operator control plane, user management needs real data and guardrails.

### Commands Run

Inspected admin/auth/user-management files:

```bash
find Obervability-Stack/ui-next/app Obervability-Stack/ui-next/components Obervability-Stack/ui-next/lib Obervability-Stack/ui-next/prisma -maxdepth 4 -type f | sort | rg 'admin|auth|user|prisma|register|signin|signup|profile|settings|seed|schema'
rg -n "admin|role|user|User|AUTH_MODE|demo|register|signup|signin|session|next-auth|PrismaAdapter|bcrypt|password" Obervability-Stack/ui-next/app Obervability-Stack/ui-next/components Obervability-Stack/ui-next/lib Obervability-Stack/ui-next/prisma -S -g '!**/node_modules/**'
git status --short && git log --oneline -5
```

Reviewed the existing admin page, auth runtime, registration route, and Prisma schema:

```bash
sed -n '1,460p' Obervability-Stack/ui-next/app/admin/page.tsx
sed -n '1,300p' Obervability-Stack/ui-next/lib/auth.ts
sed -n '1,120p' 'Obervability-Stack/ui-next/app/api/auth/[...nextauth]/route.ts'
sed -n '1,140p' Obervability-Stack/ui-next/lib/auth-runtime.ts
sed -n '1,220p' Obervability-Stack/ui-next/app/api/auth/register/route.ts
sed -n '1,220p' Obervability-Stack/ui-next/prisma/schema.prisma
sed -n '1,120p' Obervability-Stack/ui-next/prisma/seed.ts
```

Reviewed route protection and current navigation:

```bash
sed -n '1,220p' 'Obervability-Stack/ui-next/app/api/auth/[...nextauth]/route.ts'
sed -n '1,260p' Obervability-Stack/ui-next/proxy.ts
sed -n '1,260p' Obervability-Stack/ui-next/app/layout.tsx
sed -n '1,260p' Obervability-Stack/ui-next/components/sidebar.tsx
sed -n '1,240p' Obervability-Stack/ui-next/components/user-menu.tsx
sed -n '1,260p' Obervability-Stack/ui-next/app/profile/page.tsx
```

Searched for audit/status/user-management support:

```bash
rg -n "model Audit|audit|lastLogin|status|disabled|active|invite|passwordReset|reset|admin" Obervability-Stack/ui-next/prisma Obervability-Stack/ui-next/app/api Obervability-Stack/ui-next/lib -S -g '!**/node_modules/**'
```

Checked runtime environment and current database users:

```bash
rg -n "devops-monitor-ui|DATABASE_URL|AUTH_MODE|DEMO_LOGIN|NEXTAUTH|prisma|seed|db" Obervability-Stack/docker-compose.yml Obervability-Stack/scripts Obervability-Stack/ui-next/Dockerfile Obervability-Stack/ui-next/env.example -S
curl -fsSI http://localhost:4000/admin
curl -sSI http://localhost:4000/admin/users | sed -n '1,20p'
curl -sS -X POST http://localhost:4000/api/auth/register -H 'Content-Type: application/json' -d '{"name":"Probe User","email":"probe-user@example.com","password":"short"}' | jq .
docker exec devops-monitor-ui sh -lc 'env | sort | grep -E "AUTH_MODE|DEMO_LOGIN|DATABASE_URL|NEXTAUTH"; echo ---data---; ls -la /app/data; echo ---prisma---; ls -la /app/prisma 2>/dev/null || true'
docker exec devops-monitor-ui node -e 'const {PrismaClient}=require("@prisma/client"); const prisma=new PrismaClient(); (async()=>{const users=await prisma.user.findMany({select:{id:true,email:true,name:true,role:true,createdAt:true,updatedAt:true}}); const dashboards=await prisma.dashboard.count(); const configurations=await prisma.configuration.count(); console.log(JSON.stringify({users,dashboards,configurations},null,2));})().catch(e=>{console.error(e); process.exit(1)}).finally(async()=>prisma.$disconnect())'
```

Reviewed Docker and migration behavior:

```bash
sed -n '1,220p' Obervability-Stack/ui-next/.dockerignore
sed -n '1,220p' Obervability-Stack/ui-next/prisma/migrations/20250902053132_init/migration.sql
find Obervability-Stack/ui-next/components/ui -maxdepth 1 -type f -print | sort
sed -n '1,220p' Obervability-Stack/ui-next/components/ui/select.tsx
sed -n '1,220p' Obervability-Stack/ui-next/lib/prisma-server.ts
sed -n '1,220p' Obervability-Stack/ui-next/lib/prisma.ts
sed -n '1,160p' Obervability-Stack/ui-next/tsconfig.json
```

Updated Prisma schema:

```text
Obervability-Stack/ui-next/prisma/schema.prisma
```

First migration attempt failed:

```bash
npx prisma migrate dev --name add_user_status_fields
```

Fixed by explicitly setting the local SQLite database URL:

```bash
DATABASE_URL=file:./dev.db npx prisma migrate dev --name add_user_status_fields
```

Created the dynamic API route directory:

```bash
mkdir -p Obervability-Stack/ui-next/app/api/admin/users/[userId]
mkdir -p 'Obervability-Stack/ui-next/app/api/admin/users/[userId]'
```

Edited:

```text
Obervability-Stack/ui-next/app/api/admin/users/route.ts
Obervability-Stack/ui-next/app/api/admin/users/[userId]/route.ts
Obervability-Stack/ui-next/lib/auth.ts
Obervability-Stack/ui-next/app/admin/page.tsx
Obervability-Stack/ui-next/components/user-menu.tsx
```

Validated TypeScript:

```bash
npm run type-check
```

Ran the production build:

```bash
npm run build
```

The first build caught a Next.js 16 dynamic route type issue. After fixing the handler signature, reran:

```bash
npm run build
```

Rebuilt and restarted the running UI:

```bash
docker compose up -d --build devops-monitor-ui
```

Verified runtime behavior:

```bash
docker compose ps devops-monitor-ui
curl -sS -i http://localhost:4000/api/admin/users | sed -n '1,20p'
curl -sSI http://localhost:4000/admin | sed -n '1,12p'
docker exec devops-monitor-ui node -e 'const {PrismaClient}=require("@prisma/client"); const prisma=new PrismaClient(); (async()=>{const users=await prisma.user.findMany({select:{email:true,role:true,status:true,lastLoginAt:true,disabledAt:true},orderBy:{createdAt:"asc"}}); console.log(JSON.stringify(users,null,2));})().catch(e=>{console.error(e); process.exit(1)}).finally(async()=>prisma.$disconnect())'
```

Signed in through NextAuth with a cookie jar and called the admin API as the seeded admin:

```bash
tmp_cookie=$(mktemp); csrf=$(curl -fsS -c "$tmp_cookie" http://localhost:4000/api/auth/csrf | jq -r '.csrfToken'); curl -fsS -b "$tmp_cookie" -c "$tmp_cookie" -X POST http://localhost:4000/api/auth/callback/credentials -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode "csrfToken=$csrf" --data-urlencode 'email=demo@example.com' --data-urlencode 'password=demo123' --data-urlencode 'json=true' >/tmp/devops-admin-login.json; echo '--- login ---'; cat /tmp/devops-admin-login.json; echo; echo '--- admin users ---'; curl -fsS -b "$tmp_cookie" http://localhost:4000/api/admin/users | jq '{summary, users:[.users[] | {email,role,status,lastLoginAt,dashboards:._count.dashboards,configs:._count.configurations}]}'; rm -f "$tmp_cookie" /tmp/devops-admin-login.json
```

Verified the self-role-change guardrail:

```bash
tmp_cookie=$(mktemp); csrf=$(curl -fsS -c "$tmp_cookie" http://localhost:4000/api/auth/csrf | jq -r '.csrfToken'); curl -fsS -b "$tmp_cookie" -c "$tmp_cookie" -X POST http://localhost:4000/api/auth/callback/credentials -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode "csrfToken=$csrf" --data-urlencode 'email=demo@example.com' --data-urlencode 'password=demo123' --data-urlencode 'json=true' >/dev/null; user_id=$(curl -fsS -b "$tmp_cookie" http://localhost:4000/api/admin/users | jq -r '.users[] | select(.email=="demo@example.com") | .id'); curl -sS -i -b "$tmp_cookie" -X PATCH "http://localhost:4000/api/admin/users/$user_id" -H 'Content-Type: application/json' -d '{"role":"VIEWER"}' | sed -n '1,20p'; rm -f "$tmp_cookie"
```

Ran the operator check:

```bash
./scripts/devops-monitor.sh operator
```

Reviewed final status:

```bash
git status --short
git diff --stat
```

### Problems Encountered

#### Missing DATABASE_URL During Migration

The first Prisma migration command failed because `DATABASE_URL` was not set in the local shell:

```text
Environment variable not found: DATABASE_URL
```

Fix:

```bash
DATABASE_URL=file:./dev.db npx prisma migrate dev --name add_user_status_fields
```

This matches the local SQLite database used by the UI app.

#### zsh Dynamic Route Path Expansion

Creating a directory named `[userId]` failed because zsh treated the brackets as a glob:

```text
zsh: no matches found: Obervability-Stack/ui-next/app/api/admin/users/[userId]
```

Fix:

```bash
mkdir -p 'Obervability-Stack/ui-next/app/api/admin/users/[userId]'
```

#### Next.js 16 Dynamic Route Handler Type

`npm run type-check` passed, but `npm run build` failed because Next.js 16 expects dynamic route params as a promise in generated route types:

```text
context: { params: Promise<{ userId: string; }> }
```

Fix:

```ts
{ params }: { params: Promise<{ userId: string }> }
const { userId } = await params
```

### What Changed

Added durable user-management fields:

```text
status
lastLoginAt
disabledAt
```

Added a `UserStatus` enum:

```text
ACTIVE
DISABLED
```

Added admin-only APIs:

```text
GET    /api/admin/users
POST   /api/admin/users
PATCH  /api/admin/users/[userId]
DELETE /api/admin/users/[userId]
```

The `DELETE` action is intentionally a soft disable, not a hard delete.

Added server-side guardrails:

- unauthenticated requests return `401`
- non-admin requests return `403`
- admins cannot change their own role or status
- the platform cannot disable or demote the last active admin
- disabled users cannot sign in
- successful database/OAuth logins update `lastLoginAt`
- password hashes are never returned to the browser

Rebuilt the Admin UI:

- removed hardcoded users
- removed fake system stats
- loaded live users from Prisma
- added live summary cards
- added create-user form
- added edit role/status/name/email/password flow
- added disable/reactivate workflow
- fixed the broken user menu link from `/admin/users` to `/admin`

### Verification

`npm run type-check` passed.

`npm run build` passed after the Next.js dynamic route type fix.

The Docker rebuild completed and the UI container was healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

Unauthenticated API access was rejected:

```text
HTTP/1.1 401 Unauthorized
{"message":"Authentication required"}
```

Unauthenticated `/admin` access redirected to sign-in:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fadmin
```

Authenticated admin API access returned the real seeded users:

```text
totalUsers: 3
activeUsers: 3
disabledUsers: 0
admins: 1
editors: 1
viewers: 1
```

Successful admin login updated `lastLoginAt`:

```text
demo@example.com lastLoginAt: 2026-04-21T09:40:37.219Z
```

The self-role-change guardrail worked:

```text
HTTP/1.1 400 Bad Request
{"message":"You cannot change your own role or account status"}
```

The operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

### Why This Matters

This turns the Admin Panel into a real control-plane capability.

Before this change, the page looked finished but could mislead an operator because it showed fake users and fake stats. Now it is backed by the actual database, protected by server-side authorization, and has safety checks that prevent common admin mistakes.

### Recommended Next Step

Add an audit log for user-management actions:

- user created
- role changed
- status changed
- password reset
- failed admin action

That will make the admin panel stronger for incident review and portfolio storytelling.

## Phase 6 Admin Navigation Split

### Goal

Fix the confusing admin navigation where both `Admin Panel` and `User Management` opened the same `/admin` page.

This happened because `/admin/users` was previously a broken route, so the user-menu item was temporarily pointed back to `/admin` while the first real admin-management implementation was built.

### Commands Run

Inspected admin route references:

```bash
rg -n "Admin Panel|User Management|/admin/users|/admin" Obervability-Stack/ui-next/components Obervability-Stack/ui-next/app -S -g '!**/node_modules/**'
find Obervability-Stack/ui-next/app/admin -maxdepth 4 -type f -print -exec sed -n '1,40p' {} \;
sed -n '82,110p' Obervability-Stack/ui-next/components/user-menu.tsx
```

Reviewed the current admin page and git state:

```bash
sed -n '1,760p' Obervability-Stack/ui-next/app/admin/page.tsx
git status --short && git log --oneline -3
```

Created the new route/component directories:

```bash
mkdir -p Obervability-Stack/ui-next/app/admin/users Obervability-Stack/ui-next/components/admin
```

Moved the existing user-management page into a reusable component:

```text
Obervability-Stack/ui-next/components/admin/user-management-panel.tsx
```

Created:

```text
Obervability-Stack/ui-next/app/admin/page.tsx
Obervability-Stack/ui-next/app/admin/users/page.tsx
```

Updated:

```text
Obervability-Stack/ui-next/components/user-menu.tsx
```

Validated TypeScript and route structure:

```bash
npm run type-check
find Obervability-Stack/ui-next/app/admin Obervability-Stack/ui-next/components/admin -maxdepth 4 -type f -print && git diff --stat
```

Ran the production build:

```bash
npm run build
```

Rebuilt the running UI:

```bash
docker compose up -d --build devops-monitor-ui
```

Verified runtime behavior:

```bash
docker compose ps devops-monitor-ui
curl -fsSI http://localhost:4000/admin | sed -n '1,8p'
curl -fsSI http://localhost:4000/admin/users | sed -n '1,8p'
```

Signed in as admin through NextAuth and verified the admin API still returns live users:

```bash
tmp_cookie=$(mktemp); csrf=$(curl -fsS -c "$tmp_cookie" http://localhost:4000/api/auth/csrf | jq -r '.csrfToken'); curl -fsS -b "$tmp_cookie" -c "$tmp_cookie" -X POST http://localhost:4000/api/auth/callback/credentials -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode "csrfToken=$csrf" --data-urlencode 'email=demo@example.com' --data-urlencode 'password=demo123' --data-urlencode 'json=true' >/dev/null; curl -fsS -b "$tmp_cookie" http://localhost:4000/api/admin/users | jq '{summary, firstUser:.users[0] | {email,role,status}}'; rm -f "$tmp_cookie"
```

Ran the operator check:

```bash
./scripts/devops-monitor.sh operator
```

### Problem Encountered

The navigation was semantically wrong:

```text
Admin Panel      -> /admin
User Management  -> /admin
```

This made the UI feel duplicated even though the user-management feature itself was working.

### Fix

Split the admin experience into two routes:

```text
/admin        -> lightweight admin overview
/admin/users  -> dedicated user-management workspace
```

Moved the existing user-management implementation into:

```text
components/admin/user-management-panel.tsx
```

Then mounted it at:

```text
app/admin/users/page.tsx
```

Replaced `/admin` with an overview page that shows:

- total users
- active users
- admin count
- config/dashboard counts
- cards for user management, roles/access, audit logs, and system settings

Updated the user menu:

```text
Admin Panel      -> /admin
User Management  -> /admin/users
```

### Verification

`npm run type-check` passed.

`npm run build` passed and showed both routes:

```text
/admin
/admin/users
```

The rebuilt UI container was healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

Both admin routes are protected:

```text
/admin       -> 307 /auth/signin?from=%2Fadmin
/admin/users -> 307 /auth/signin?from=%2Fadmin%2Fusers
```

Authenticated admin API check still returned live users:

```text
totalUsers: 3
activeUsers: 3
admins: 1
firstUser: demo@example.com ADMIN ACTIVE
```

The operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

### Why This Matters

This makes the UI navigation match the mental model:

- `Admin Panel` is the control center.
- `User Management` is the focused workspace for operators and roles.

That separation will also make the next admin improvements cleaner, especially audit logs and system settings.

## 2026-04-21 - Admin Audit Logging

### Objective

After splitting `Admin Panel` and `User Management`, the next enterprise control was auditability. User-management actions should not be invisible because role changes, account disables, password resets, and blocked guardrail attempts are security-relevant events.

### Commands Run

Confirmed the current git state and recent commits:

```bash
git status --short && git log --oneline -5
```

Reviewed the current Prisma schema and admin routes before changing behavior:

```bash
sed -n '1,260p' Obervability-Stack/ui-next/prisma/schema.prisma
sed -n '1,280p' Obervability-Stack/ui-next/app/api/admin/users/route.ts
sed -n '1,380p' 'Obervability-Stack/ui-next/app/api/admin/users/[userId]/route.ts'
sed -n '1,320p' Obervability-Stack/ui-next/app/admin/page.tsx
sed -n '1,260p' Obervability-Stack/ui-next/components/admin/user-management-panel.tsx
find Obervability-Stack/ui-next/app/admin -maxdepth 3 -type f -print | sort
find Obervability-Stack/ui-next/app/api/admin -maxdepth 4 -type f -print | sort
find Obervability-Stack/ui-next/prisma/migrations -maxdepth 2 -type f -name migration.sql -print | sort | tail -10
sed -n '1,220p' Obervability-Stack/ui-next/lib/prisma-server.ts
sed -n '1,220p' Obervability-Stack/ui-next/package.json
sed -n '1,220p' Obervability-Stack/ui-next/app/admin/users/page.tsx
```

Created and applied the Prisma migration:

```bash
DATABASE_URL=file:./dev.db npx prisma migrate dev --name add_admin_audit_logs
```

Reviewed the generated migration:

```bash
sed -n '1,220p' prisma/migrations/20260421191244_add_admin_audit_logs/migration.sql
```

Checked working tree changes:

```bash
git status --short
```

Ran TypeScript validation:

```bash
npm run type-check
```

Reviewed failing TypeScript locations:

```bash
nl -ba 'app/api/admin/users/[userId]/route.ts' | sed -n '56,82p'
nl -ba app/api/admin/users/route.ts | sed -n '145,165p'
```

Ran TypeScript validation again after the fix:

```bash
npm run type-check
```

Ran the production build:

```bash
npm run build
```

Attempted to rebuild the UI container from the repository root:

```bash
docker compose up -d --build devops-monitor-ui
```

Located the correct Compose files:

```bash
find . -maxdepth 3 \( -name 'docker-compose*.yml' -o -name 'compose*.yml' -o -name 'compose*.yaml' \) -print | sort
find scripts -maxdepth 2 -type f -print | sort
find Obervability-Stack -maxdepth 2 -type f -name 'docker-compose*.yml' -print | sort
```

Rebuilt the UI container from the observability stack directory:

```bash
docker compose up -d --build devops-monitor-ui
```

Confirmed the UI container was healthy:

```bash
docker compose ps devops-monitor-ui
```

Reviewed the `devops-monitor-ui` Compose service configuration:

```bash
sed -n '/devops-monitor-ui:/,/^[^[:space:]]/p' docker-compose.yml
```

Verified unauthenticated audit protections:

```bash
curl -sS -i http://localhost:4000/api/admin/audit | sed -n '1,12p' && printf '\n--- page redirect ---\n' && curl -sS -I http://localhost:4000/admin/audit | sed -n '1,8p'
```

Signed in as the existing admin user and triggered a safe blocked-action probe:

```bash
tmp_cookie=$(mktemp)
csrf=$(curl -fsS -c "$tmp_cookie" http://localhost:4000/api/auth/csrf | jq -r '.csrfToken')
curl -fsS -b "$tmp_cookie" -c "$tmp_cookie" -X POST http://localhost:4000/api/auth/callback/credentials \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "csrfToken=$csrf" \
  --data-urlencode 'email=demo@example.com' \
  --data-urlencode 'password=demo123' \
  --data-urlencode 'callbackUrl=http://localhost:4000/dashboard' >/dev/null
user_id=$(curl -fsS -b "$tmp_cookie" http://localhost:4000/api/admin/users | jq -r '.users[] | select(.email=="demo@example.com") | .id')
if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
  echo "demo admin user id not found"
  rm -f "$tmp_cookie"
  exit 1
fi
printf 'Self role-change guardrail response:\n'
curl -sS -i -b "$tmp_cookie" -X PATCH "http://localhost:4000/api/admin/users/$user_id" \
  -H 'Content-Type: application/json' \
  -d '{"role":"VIEWER"}' | sed -n '1,12p'
printf '\nLatest audit summary and event:\n'
curl -fsS -b "$tmp_cookie" http://localhost:4000/api/admin/audit | jq '{summary, latest: .events[0] | {action, actorEmail, targetUserEmail, message}}'
rm -f "$tmp_cookie"
```

Ran the operator check:

```bash
./scripts/devops-monitor.sh operator
```

### Changes Made

Added a new Prisma model:

```text
AdminAuditLog
```

Added a new Prisma enum:

```text
AdminAuditAction
```

The audit model records:

- action type
- actor id and email
- target user id and email
- human-readable message
- metadata JSON
- creation timestamp

Created a server helper:

```text
Obervability-Stack/ui-next/lib/admin-audit.ts
```

This helper writes audit records and logs audit-write failures without breaking the primary admin action. That design choice prevents the admin workflow from failing because of a secondary logging issue, while still surfacing audit-write problems in server logs.

Updated admin user APIs:

```text
Obervability-Stack/ui-next/app/api/admin/users/route.ts
Obervability-Stack/ui-next/app/api/admin/users/[userId]/route.ts
```

The API now records:

- `USER_CREATED`
- `USER_UPDATED`
- `USER_DISABLED`
- `USER_REACTIVATED`
- `ROLE_CHANGED`
- `STATUS_CHANGED`
- `PASSWORD_CHANGED`
- `ACTION_BLOCKED`

Added a new admin audit API:

```text
Obervability-Stack/ui-next/app/api/admin/audit/route.ts
```

The endpoint is admin-only and returns:

- latest 100 audit events
- total event count
- blocked action count
- user change count
- password change count

Added a new admin audit page:

```text
Obervability-Stack/ui-next/app/admin/audit/page.tsx
```

Updated the Admin Panel card so `Audit Logs` now opens:

```text
/admin/audit
```

### Problems Encountered

#### TypeScript Session Typing

The first type-check failed:

```text
app/api/admin/users/[userId]/route.ts(67,18): error TS2339: Property 'user' does not exist on type '{}'.
app/api/admin/users/[userId]/route.ts(68,20): error TS2339: Property 'user' does not exist on type '{}'.
app/api/admin/users/route.ts(157,16): error TS2532: Object is possibly 'undefined'.
```

Reason:

NextAuth runtime guard guarantees an admin session before those lines execute, but TypeScript did not infer that from the local `requireAdmin()` response pattern.

Fix:

Used guarded optional access for the actor object and simplified the local `auditActor()` helper parameter so runtime-safe session access does not fail compilation.

#### Docker Compose Path

The first rebuild command failed from the main repository root:

```text
no configuration file provided: not found
```

Reason:

The main `DevOps-Easy-Learning` repository is the umbrella repository. The actual observability stack Compose file lives in:

```text
Obervability-Stack/docker-compose.yml
```

Fix:

Ran the rebuild from the correct directory:

```bash
cd /Users/raymond/Documents/DevOps-Easy-Learning/Obervability-Stack
docker compose up -d --build devops-monitor-ui
```

#### Docker Build Secret Warnings

The Docker build still reported existing warnings:

```text
SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data (ARG "NEXTAUTH_SECRET")
SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data (ENV "NEXTAUTH_SECRET")
```

Reason:

The current Dockerfile passes auth values through build arguments/environment. This is not ideal for production-grade secret handling.

Status:

Not fixed in this step because the objective was audit logging. This remains a hardening follow-up before production deployment.

#### Local Build Auth And Database Warnings

The local `npm run build` still showed expected warnings:

```text
NEXTAUTH_SECRET is not set or is using the default value.
NEXTAUTH_URL is not set.
Environment variable not found: DATABASE_URL.
```

Reason:

The bare local shell does not export the same runtime environment provided by Docker Compose.

Status:

The build completed successfully. Docker Compose supplies the runtime values for the container.

### Verification

TypeScript passed:

```text
tsc --noEmit
```

Production build passed and listed the new routes:

```text
/admin/audit
/api/admin/audit
```

Unauthenticated audit API access is blocked:

```text
HTTP/1.1 401 Unauthorized
{"message":"Authentication required"}
```

Unauthenticated audit page access redirects to sign-in:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fadmin%2Faudit
```

The safe authenticated guardrail probe behaved correctly:

```text
HTTP/1.1 400 Bad Request
{"message":"You cannot change your own role or account status"}
```

The audit log captured the blocked attempt:

```json
{
  "summary": {
    "totalEvents": 1,
    "blockedActions": 1,
    "userChanges": 0,
    "passwordChanges": 0
  },
  "latest": {
    "action": "ACTION_BLOCKED",
    "actorEmail": "demo@example.com",
    "targetUserEmail": "demo@example.com",
    "message": "Blocked self role or status change for demo@example.com"
  }
}
```

The rebuilt container was healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

The operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

### Why This Matters

Admin user management now has accountability. Operators can review who attempted or completed privileged changes, which user was targeted, and whether the system blocked risky actions.

This is important before moving further into production-like operations because auditability is a foundational control for:

- access reviews
- incident response
- compliance evidence
- administrator accountability
- troubleshooting unexpected access changes

## 2026-04-21 - Phase 6 App Comparison View

### Objective

Continue Phase 6 UX and demo polish by adding a control-plane comparison view for the four managed workloads. The services page already acted as a launch board, but the demo still needed one place that clearly explained why each workload exists and how each one maps to the future Kubernetes direction.

### Commands Run

Checked the current git state and recent commits:

```bash
git status --short && git log --oneline -6
```

Located roadmap and runbook files:

```bash
find . -maxdepth 3 -iname '*roadmap*' -o -iname '*plan*' -o -iname '*runbook*' | sort
```

Searched for the active roadmap phase and current Phase 6 guidance:

```bash
rg -n "Phase 6|phase 6|Admin|audit|next|roadmap|Roadmap|handoff|Phase" -S . --glob '!**/node_modules/**' --glob '!**/.next/**' --glob '!**/dist/**' --glob '!**/build/**'
```

Read the Phase 6 roadmap and demo script:

```bash
sed -n '488,620p' PROJECT-ROADMAP.md
sed -n '122,150p' README.md
sed -n '1,240p' DEMO-WALKTHROUGH.md
find Obervability-Stack/ui-next/app -maxdepth 3 -type f | sort | sed -n '1,180p'
```

Inspected the services UI and app inventory source:

```bash
sed -n '1,320p' Obervability-Stack/ui-next/lib/monitored-apps.ts
sed -n '1,360p' Obervability-Stack/ui-next/app/services/page.tsx
sed -n '1,360p' Obervability-Stack/ui-next/app/services/[appId]/page.tsx
find Obervability-Stack/ui-next/components -maxdepth 3 -type f | sort | sed -n '1,180p'
```

Corrected the bracketed route path quoting and read the app detail page:

```bash
sed -n '320,760p' Obervability-Stack/ui-next/app/services/page.tsx
sed -n '1,420p' 'Obervability-Stack/ui-next/app/services/[appId]/page.tsx'
sed -n '1,260p' Obervability-Stack/ui-next/lib/hooks/use-monitored-apps.ts
sed -n '1,260p' Obervability-Stack/ui-next/app/api/apps/route.ts
```

Inspected sidebar navigation behavior:

```bash
sed -n '1,260p' Obervability-Stack/ui-next/components/sidebar.tsx
sed -n '420,760p' 'Obervability-Stack/ui-next/app/services/[appId]/page.tsx'
sed -n '620,740p' PROJECT-ROADMAP.md
sed -n '260,560p' Obervability-Stack/ui-next/components/sidebar.tsx
```

Ran TypeScript validation:

```bash
npm run type-check
```

Ran the production build:

```bash
npm run build
```

Rebuilt the UI container:

```bash
docker compose up -d --build devops-monitor-ui
```

Verified the rebuilt container:

```bash
docker compose ps devops-monitor-ui
```

Verified the new route is protected:

```bash
curl -sS -I http://localhost:4000/services/compare | sed -n '1,10p'
```

Verified app inventory data used by the comparison page:

```bash
curl -fsS http://localhost:4000/api/apps | jq '{total:.summary.totalApps, owned:.summary.ownedApps, endpoints:.summary.endpoints, apps:[.apps[] | {id,name,category,namespace:.kubernetes.namespace}]}'
```

Verified live app health data used by the comparison page:

```bash
curl -fsS http://localhost:4000/api/apps/health | jq '{total:.summary.totalApps, healthy:.summary.healthyApps, statuses:[.apps[] | {appId,status,endpoints:(.endpoints|length)}]}'
```

Ran the full operator check:

```bash
./scripts/devops-monitor.sh operator
```

### Changes Made

Added a new comparison page:

```text
Obervability-Stack/ui-next/app/services/compare/page.tsx
```

The page shows:

- each app's architecture category
- current live health state
- endpoint count and primary latency
- ownership model
- Kubernetes namespace
- operator value
- Kubernetes migration focus
- live audit command
- operator risk
- links to the app-specific operator page and live app

Updated the services launch board:

```text
Obervability-Stack/ui-next/app/services/page.tsx
```

Added a `Compare Apps` button so presenters and operators can move from launch board to side-by-side workload explanation.

Updated sidebar active-state behavior:

```text
Obervability-Stack/ui-next/components/sidebar.tsx
```

The `Services` navigation item now remains active for nested routes such as:

```text
/services/compare
/services/swiftpay
/services/opensis
```

Updated Phase 6 documentation:

```text
PROJECT-ROADMAP.md
DEMO-WALKTHROUGH.md
```

### Problems Encountered

#### Broad Search Returned Too Much Noise

The first roadmap search produced a very large result set because `OpenSIS/app/assets` contains many vendored JavaScript files that include common words such as `next`.

Reason:

The query was intentionally broad and did not exclude every vendored asset path.

Fix:

Narrowed the follow-up reads to `PROJECT-ROADMAP.md`, `README.md`, `DEMO-WALKTHROUGH.md`, and the control-plane UI files.

#### Bracketed Dynamic Route Path Needed Quoting Again

The unquoted command failed:

```text
zsh:1: no matches found: Obervability-Stack/ui-next/app/services/[appId]/page.tsx
```

Reason:

`zsh` treats square brackets as glob syntax.

Fix:

Quoted the route path:

```bash
sed -n '1,420p' 'Obervability-Stack/ui-next/app/services/[appId]/page.tsx'
```

#### Existing Docker Secret Warnings Remain

The Docker build still reported warnings about `NEXTAUTH_SECRET` and `AUTH_MODE` being passed through `ARG` or `ENV`.

Status:

Not fixed in this step. This remains a production hardening item and should be handled separately so the UX/demo change does not mix with secret-management refactoring.

### Verification

TypeScript passed:

```text
tsc --noEmit
```

Production build passed and listed:

```text
/services/compare
```

The rebuilt UI container was healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

The new route is protected:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fservices%2Fcompare
```

The comparison page data sources returned the expected inventory:

```json
{
  "total": 4,
  "owned": 1,
  "endpoints": 10
}
```

Live app health showed all workloads healthy:

```json
{
  "total": 4,
  "healthy": 4
}
```

The operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

### Why This Matters

The workspace now has a clearer mixed-architecture story:

- `SwiftPay` demonstrates microservices and business telemetry.
- `OpenSIS` demonstrates legacy platform modernization.
- `FoodPulse` demonstrates resilience and failover operations.
- `MemFlip` demonstrates the smallest repeatable onboarding pattern.

This makes Phase 6 stronger because a new viewer can understand the purpose of the four apps from one control-plane view before drilling into individual operator pages.

## 2026-04-21 - Phase 6 Demo Center

### Objective

Turn the Markdown demo walkthrough into a first-class control-plane UI route so a presenter can start from one guided page, confirm live readiness, copy the right commands, open the correct app pages, and connect the UI story back to incident evidence and Kubernetes direction.

### Commands Run

Checked the current git state and recent commits:

```bash
git status --short && git log --oneline -5
```

Read the current demo script and sidebar layout:

```bash
sed -n '1,260p' DEMO-WALKTHROUGH.md
sed -n '1,380p' Obervability-Stack/ui-next/components/sidebar.tsx
sed -n '1,240p' Obervability-Stack/ui-next/app/layout.tsx
```

Ran TypeScript validation:

```bash
npm run type-check
```

Reviewed the root README demo path before updating it:

```bash
sed -n '1,180p' README.md
```

Ran the production build:

```bash
npm run build
```

Rebuilt the UI container:

```bash
docker compose up -d --build devops-monitor-ui
```

Verified the rebuilt container:

```bash
docker compose ps devops-monitor-ui
```

Verified the new route is protected:

```bash
curl -sS -I http://localhost:4000/demo | sed -n '1,10p'
```

Verified the live app health API used by the Demo Center:

```bash
curl -fsS http://localhost:4000/api/apps/health | jq '{total:.summary.totalApps, healthy:.summary.healthyApps, statuses:[.apps[] | {appId,status,endpoints:(.endpoints|length)}]}'
```

Verified the app inventory summary used by the Demo Center:

```bash
curl -fsS http://localhost:4000/api/apps | jq '{total:.summary.totalApps, owned:.summary.ownedApps, endpoints:.summary.endpoints}'
```

Signed in with the local admin account and verified the rendered Demo Center content:

```bash
tmp_cookie=$(mktemp)
csrf=$(curl -fsS -c "$tmp_cookie" http://localhost:4000/api/auth/csrf | jq -r '.csrfToken')
curl -fsS -b "$tmp_cookie" -c "$tmp_cookie" -X POST http://localhost:4000/api/auth/callback/credentials \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "csrfToken=$csrf" \
  --data-urlencode 'email=demo@example.com' \
  --data-urlencode 'password=demo123' \
  --data-urlencode 'callbackUrl=http://localhost:4000/demo' >/dev/null
curl -fsS -b "$tmp_cookie" http://localhost:4000/demo | grep -Eo 'Demo Center|Phase 6 demo path|Pre-Demo Checklist' | sort -u
rm -f "$tmp_cookie"
```

Ran the full operator check:

```bash
./scripts/devops-monitor.sh operator
```

### Changes Made

Added a new Demo Center route:

```text
Obervability-Stack/ui-next/app/demo/page.tsx
```

The page includes:

- live demo readiness state
- live managed-app health snapshot
- pre-demo checklist
- copyable command blocks
- guided presenter cards
- workload role summaries
- links to app pages, incident drills, journey runbook, architecture docs, and demo walkthrough

Updated sidebar navigation:

```text
Obervability-Stack/ui-next/components/sidebar.tsx
```

Added:

```text
Demo Center -> /demo
```

Updated project documentation:

```text
README.md
DEMO-WALKTHROUGH.md
PROJECT-ROADMAP.md
JOURNEY-RUNBOOK.md
```

### Problems Encountered

No implementation blocker occurred during this slice.

One existing risk remains:

```text
Docker build secret warnings for NEXTAUTH_SECRET and AUTH_MODE are still present.
```

This is not related to the Demo Center route and should be fixed separately as a production hardening task.

### Verification

TypeScript validation passed:

```text
tsc --noEmit
```

Production build passed and listed:

```text
/demo
```

The rebuilt UI container was healthy:

```text
devops-monitor-ui   Up ... (healthy)   0.0.0.0:4000->3000/tcp
```

The Demo Center route is protected:

```text
HTTP/1.1 307 Temporary Redirect
location: /auth/signin?from=%2Fdemo
```

The app health API returned all apps healthy:

```json
{
  "total": 4,
  "healthy": 4
}
```

The app inventory API returned:

```json
{
  "total": 4,
  "owned": 1,
  "endpoints": 10
}
```

The authenticated Demo Center smoke check found:

```text
Demo Center
Phase 6 demo path
Pre-Demo Checklist
```

The operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

### Why This Matters

The Demo Center makes Phase 6 more usable for real presentations. Instead of asking someone to keep several Markdown files, URLs, and commands in their head, the control plane now gives a single guided presenter path with live readiness and direct operational links.

---

## 2026-04-22 05:09 EDT - Metrics Strategy And Central App Scrape Coverage

### Goal

Turn the metrics recommendations into a clean first implementation slice without overloading the roadmap.

The intent was to:

- document the production-grade metrics strategy for the control plane and managed apps
- scrape existing MemFlip and FoodPulse application metric endpoints from central Prometheus
- keep the changes Kubernetes-minded by using stable Docker service aliases that map cleanly to future service names
- remove unsafe high-cardinality labels from MemFlip metrics
- validate the changes through Prometheus and existing operator audit paths

### Commands Run

Initial inspection:

```bash
git status --short
sed -n '1,240p' Obervability-Stack/prometheus/prometheus.yml
sed -n '1,320p' Obervability-Stack/prometheus/recording_rules.yml
sed -n '1,220p' FoodPulse/docker-compose.yml
sed -n '1,220p' MemFlip/backend/middleware/metrics.js
sed -n '220,520p' MemFlip/backend/middleware/metrics.js
sed -n '220,520p' FoodPulse/docker-compose.yml
ls -1
tail -n 80 JOURNEY-RUNBOOK.md
sed -n '1,180p' README.md
sed -n '1,240p' PROJECT-ROADMAP.md
rg -n "Phase 6|metrics|Metric|observability" PROJECT-ROADMAP.md README.md WORKSPACE-ARCHITECTURE.md
```

Static validation:

```bash
docker compose config --quiet
docker compose config --quiet
git diff --check
git diff --stat
docker compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
docker compose exec -T prometheus promtool check rules /etc/prometheus/alert_rules.yml /etc/prometheus/recording_rules.yml
git status --short
```

Runtime update:

```bash
docker compose up -d --force-recreate foodpulse-api
docker compose up -d --build backend
curl -fsS -X POST http://localhost:9090/-/reload
```

Live scrape and metric verification:

```bash
sleep 20; curl -fsS http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="memflip-backend" or .labels.job=="foodpulse-api") | [.labels.job,.health,.scrapeUrl,(.lastError // "")] | @tsv'
curl -fsS http://localhost:3101/metrics | rg -n '^game_scores_total' | head -n 10
curl -fsS http://localhost:3102/metrics | rg -n '^(foodpulse_votes_total|foodpulse_pageviews|foodpulse_api_process_resident_memory_bytes)' | head -n 20
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=up{job=~"memflip-backend|foodpulse-api"}' | jq -r '.data.result[] | [.metric.job,.value[1]] | @tsv'
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=memflip:app_health' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=foodpulse:api_up' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
./scripts/devops-monitor.sh operator
```

Troubleshooting and follow-up validation:

```bash
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=app_health_status{job="memflip-backend"}' | jq -r '.data.result[] | [.metric.service,.metric.component,.value[1]] | @tsv'
curl -fsS http://localhost:3101/metrics | rg -n '^app_health_status'
docker compose exec -T prometheus promtool check rules /etc/prometheus/recording_rules.yml && curl -fsS -X POST http://localhost:9090/-/reload
sleep 20; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=memflip:app_health' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
sleep 20; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=foodpulse:api_up' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
./scripts/devops-monitor.sh memflip-live
./scripts/devops-monitor.sh foodpulse-live
docker compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
rg -n "game_scores_total|score|username" Obervability-Stack/scripts/memflip-live-audit.sh
sed -n '1,260p' Obervability-Stack/scripts/memflip-live-audit.sh
sed -n '250,292p' Obervability-Stack/scripts/memflip-live-audit.sh
./scripts/devops-monitor.sh memflip-live
git diff --check
git diff --stat -- . ':!JOURNEY-RUNBOOK.md'
git status --short
date '+%Y-%m-%d %H:%M:%S %Z'
```

### Changes Made

Added:

- `METRICS-STRATEGY.md`

Updated:

- `FoodPulse/docker-compose.yml`
- `MemFlip/backend/middleware/metrics.js`
- `Obervability-Stack/prometheus/prometheus.yml`
- `Obervability-Stack/prometheus/recording_rules.yml`
- `Obervability-Stack/scripts/memflip-live-audit.sh`
- `README.md`
- `PROJECT-ROADMAP.md`

### Why These Changes Were Made

`METRICS-STRATEGY.md` was added so the project has one canonical standard for metrics instead of scattered recommendations. It defines golden signals, platform metrics, app metrics, label rules, recommended service objectives, and the next telemetry backlog.

FoodPulse API was added to `observability-net` with alias `foodpulse-api` because the API already exposes `/metrics`, but central Prometheus could not scrape it over Docker DNS while it was only attached to `foodpulse-net`.

Central Prometheus now scrapes:

```text
memflip-backend:3001/metrics
foodpulse-api:4567/metrics
```

Recording rules were added under stable namespaces:

```text
memflip:*
foodpulse:*
app:probe_*
```

The MemFlip `game_scores_total` metric stopped using `username` as a label. This was required because user-specific labels create high cardinality, increase Prometheus memory pressure, and can leak identity-shaped data into telemetry.

The README and roadmap were updated so the metrics standard is discoverable and Phase 6 has a clear observability-quality completion signal.

### Problems Encountered

Problem:

```text
MemFlip build reported 4 npm audit findings and warned that npm ci --only=production should be replaced by npm ci --omit=dev.
```

Resolution:

This was documented as a follow-up risk and not mixed into the metrics slice. The build completed and the backend started successfully. Dependency remediation should be handled as a separate hardening task because it can alter package resolution and runtime behavior.

Problem:

```text
memflip:app_health returned 0 even though Prometheus was scraping MemFlip successfully.
```

Root cause:

The first recording rule used:

```promql
min(app_health_status{job="memflip-backend"} or vector(0))
```

The fallback `vector(0)` participated in the `min`, so the result became `0` even when all MemFlip health series were `1`.

Resolution:

The rule was corrected to:

```promql
min(app_health_status{job="memflip-backend"}) or vector(0)
```

This preserves the fallback only when the metric is absent.

Problem:

```text
./scripts/devops-monitor.sh memflip-live failed 33/34 after username was removed from game_scores_total.
```

Root cause:

The audit script still expected the old label shape:

```text
game_scores_total{difficulty="easy",username="..."}
```

Resolution:

The audit now checks the bounded production-safe label shape:

```text
game_scores_total{difficulty="easy",score_range="beginner"}
```

### Verification

Compose validation passed for FoodPulse and the observability stack:

```text
docker compose config --quiet
```

Prometheus configuration and rules passed:

```text
SUCCESS: /etc/prometheus/prometheus.yml is valid prometheus config file syntax
SUCCESS: 40 rules found
SUCCESS: 48 rules found
```

New scrape targets are up:

```text
foodpulse-api    up    http://foodpulse-api:4567/metrics
memflip-backend  up    http://memflip-backend:3001/metrics
```

Prometheus query verification passed:

```text
foodpulse-api     1
memflip-backend   1
memflip:app_health 1
foodpulse:api_up   1
```

MemFlip metric label verification confirmed that `username` is no longer used:

```text
game_scores_total{difficulty="easy",score_range="beginner"} 9
```

FoodPulse metric verification confirmed API metrics are exposed:

```text
foodpulse_api_process_resident_memory_bytes 65327104
foodpulse_pageviews 9316
```

Operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

FoodPulse live integration audit passed:

```text
Checks passed: 16/16
FoodPulse live integration audit passed
```

MemFlip live integration audit passed after updating the metric expectation:

```text
Checks passed: 34/34
MemFlip live integration audit passed
```

Whitespace validation passed:

```text
git diff --check
```

### Follow-Up Work

- Replace MemFlip Docker build command usage of `npm ci --only=production` with `npm ci --omit=dev`.
- Review and remediate MemFlip dependency audit findings in a dedicated dependency-hardening task.
- Add FoodPulse HTTP request duration, request total, and error counters.
- Add central OpenSIS database/runtime exporter coverage.
- Build Grafana dashboards from the new `memflip:*`, `foodpulse:*`, and `app:probe_*` recording rules.

---

## 2026-04-22 05:17 EDT - FoodPulse API HTTP Metrics

### Goal

Complete the next metrics roadmap step by adding production-grade HTTP metrics to the FoodPulse API.

The intent was to track:

- request count
- error count
- p95 latency
- central Prometheus recording rules
- operator audit coverage for the new metrics path

### Commands Run

Commit the previous metrics strategy checkpoint:

```bash
git status --short
git diff --stat
git branch --show-current
git add FoodPulse/docker-compose.yml JOURNEY-RUNBOOK.md MemFlip/backend/middleware/metrics.js Obervability-Stack/prometheus/prometheus.yml Obervability-Stack/prometheus/recording_rules.yml Obervability-Stack/scripts/memflip-live-audit.sh PROJECT-ROADMAP.md README.md METRICS-STRATEGY.md && git commit -m "Add managed app metrics strategy"
```

Inspect FoodPulse API and current git state:

```bash
sed -n '1,260p' FoodPulse/api/src/index.js
sed -n '260,620p' FoodPulse/api/src/index.js
cat FoodPulse/api/package.json
git status --short
```

Validate syntax and Prometheus rules:

```bash
node --check src/index.js
docker compose exec -T prometheus promtool check rules /etc/prometheus/recording_rules.yml
git diff --check
```

Rebuild/restart FoodPulse API and reload Prometheus:

```bash
docker compose up -d --build foodpulse-api
curl -fsS -X POST http://localhost:9090/-/reload
```

Generate traffic and verify direct API metrics:

```bash
curl -fsS http://localhost:3102/health >/dev/null && curl -fsS http://localhost:3102/api/getstats >/dev/null && curl -fsS http://localhost:3102/api/venues >/dev/null && curl -fsS http://localhost:3102/api/vote >/dev/null || true; curl -fsS http://localhost:3102/metrics | rg -n '^(foodpulse_http_requests_total|foodpulse_http_errors_total|foodpulse_http_request_duration_seconds_bucket)' | head -n 40
sleep 20; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=foodpulse_http_requests_total{job="foodpulse-api"}' | jq -r '.data.result[] | [.metric.route,.metric.status_code,.value[1]] | @tsv' | head -n 20
sleep 20; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=foodpulse:http_p95_latency_seconds' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
curl -fsS http://localhost:3102/api/venues | jq -r '.venues[0].slug'
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=foodpulse:http_request_rate_5m' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=foodpulse:http_error_rate_5m' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
```

Extend and verify the FoodPulse operator audit:

```bash
sed -n '1,260p' Obervability-Stack/scripts/foodpulse-live-audit.sh
./scripts/devops-monitor.sh foodpulse-live
./scripts/devops-monitor.sh operator
git diff --check
date '+%Y-%m-%d %H:%M:%S %Z'
git status --short
git diff --stat
```

### Changes Made

Updated:

- `FoodPulse/api/src/index.js`
- `Obervability-Stack/prometheus/recording_rules.yml`
- `Obervability-Stack/scripts/foodpulse-live-audit.sh`
- `METRICS-STRATEGY.md`

### Why These Changes Were Made

FoodPulse previously exported useful business metrics, but it did not expose HTTP service metrics. That meant operators could see votes and pageviews, but not request throughput, error throughput, or latency from the API itself.

The API now exports:

```text
foodpulse_http_requests_total
foodpulse_http_errors_total
foodpulse_http_request_duration_seconds
```

The metric labels are intentionally bounded:

```text
method
route
status_code
error_class
```

No user input, session ID, request ID, or free-form value is used as a label.

Central recording rules were added:

```text
foodpulse:http_request_rate_5m
foodpulse:http_error_rate_5m
foodpulse:http_error_ratio_5m
foodpulse:http_p95_latency_seconds
```

The FoodPulse live audit now checks central Prometheus for:

- FoodPulse API scrape health
- FoodPulse HTTP request metrics
- FoodPulse p95 latency recording rule data

### Problems Encountered

Problem:

```text
curl: (22) The requested URL returned error: 400
```

Root cause:

The command intentionally called:

```text
http://localhost:3102/api/vote
```

without the required `venueSlug` or `restaurant` query parameter.

Resolution:

This was left as an intentional negative-path check. It verified that `foodpulse_http_errors_total` records client errors correctly.

Problem:

```text
The previous metrics strategy slice was still uncommitted at the start of this step.
```

Resolution:

Committed it first as:

```text
23b3323 Add managed app metrics strategy
```

This created a clean checkpoint before modifying FoodPulse API instrumentation.

### Verification

FoodPulse API syntax validation passed:

```text
node --check src/index.js
```

Prometheus recording rules passed:

```text
SUCCESS: 52 rules found
```

FoodPulse API image rebuilt and restarted successfully:

```text
Image foodpulse-api:local Built
Container foodpulse-api Started
```

FoodPulse API image dependency install reported:

```text
found 0 vulnerabilities
```

Direct `/metrics` output included HTTP histogram data:

```text
foodpulse_http_request_duration_seconds_bucket{le="0.05",method="GET",route="/health",status_code="200"} 1
foodpulse_http_request_duration_seconds_bucket{le="0.005",method="GET",route="/api/vote",status_code="400"} 1
```

Prometheus saw FoodPulse HTTP request metrics:

```text
/api/getstats  200  3
/api/health    200  1
/api/venues    200  1
/api/vote      400  1
/metrics       200  2
```

Prometheus recording rules returned data:

```text
foodpulse:http_p95_latency_seconds  0.22764321213706512
foodpulse:http_request_rate_5m      0.010129777777777777
foodpulse:http_error_rate_5m        0
```

FoodPulse live audit passed after adding metric checks:

```text
Checks passed: 23/23
FoodPulse live integration audit passed
```

Operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

Whitespace validation passed:

```text
git diff --check
```

### Follow-Up Work

- Decide whether to expose these FoodPulse HTTP metrics directly on the app detail page in the control-plane UI.
- Add OpenSIS MariaDB exporter coverage as the next metrics maturity step.
- Add Grafana dashboards using the new FoodPulse recording rules.

---

## 2026-04-22 05:25 EDT - OpenSIS MariaDB Exporter Coverage

### Goal

Add deeper OpenSIS observability by promoting MariaDB metrics into the shared control plane.

The intent was to move OpenSIS beyond UI blackbox checks and give operators database-level visibility for:

- MariaDB exporter/database health
- active connections
- connection utilization
- slow query rate
- operator audit validation

### Commands Run

Initial inspection:

```bash
git status --short
sed -n '1,280p' OpenSIS/docker-compose.yml
find OpenSIS -maxdepth 3 -type f \( -name '*prometheus*' -o -name '*exporter*' -o -name '*.env*' -o -name '*runbook*' \) | sort
sed -n '1,240p' OpenSIS/observability/prometheus/prometheus.yml
find OpenSIS -maxdepth 4 -type f \( -name 'docker-compose*.yml' -o -name 'compose*.yml' -o -name 'Dockerfile' \) | sort
rg -n "mysqld-exporter|opensis-db|observability-net|mysql|mariadb|3306|9104" OpenSIS
sed -n '1,260p' OpenSIS/observability/mysqld-exporter-my.cnf
sed -n '1,260p' WORKSPACE-SETUP-MATRIX.md
sed -n '220,390p' OpenSIS/docker-compose.yaml
sed -n '1,140p' OpenSIS/docker-compose.yaml
sed -n '140,230p' OpenSIS/docker-compose.yaml
sed -n '1,220p' OpenSIS/scripts/compose-start.sh
```

Exporter behavior and credential model checks:

```bash
sed -n '1,120p' OpenSIS/vault-agent/db-templates/db.env.tpl
sed -n '1,120p' OpenSIS/vault-agent/app-templates/app.env.tpl
docker compose ps
docker run --rm prom/mysqld-exporter:v0.17.2 --help | sed -n '1,120p'
docker run --rm --entrypoint which prom/mysqld-exporter:v0.17.2 mysqld_exporter
sed -n '1,120p' OpenSIS/scripts/mariadb-entrypoint.sh
docker compose exec -T opensis-db sh -lc '. /run/secrets/db.env && mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -Nse "SELECT user, host FROM mysql.user ORDER BY user, host"'
sed -n '1,160p' OpenSIS/scripts/seed.sh
sed -n '1,140p' OpenSIS/.env.example
sed -n '1,140p' OpenSIS/.env
git ls-files OpenSIS/.env OpenSIS/.env.example
```

Audit and recording-rule inspection:

```bash
sed -n '1,300p' Obervability-Stack/scripts/opensis-live-audit.sh
rg -n "opensis|mariadb|mysql|recording" Obervability-Stack/prometheus/recording_rules.yml Obervability-Stack/prometheus/prometheus.yml METRICS-STRATEGY.md WORKSPACE-SETUP-MATRIX.md
```

Static validation:

```bash
chmod +x OpenSIS/observability/mysqld-exporter-entrypoint.sh && git diff --check
docker compose config --quiet
docker compose config --quiet
docker compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml && docker compose exec -T prometheus promtool check rules /etc/prometheus/recording_rules.yml
```

Runtime apply:

```bash
docker compose up -d --force-recreate opensis-db mysqld-exporter
curl -fsS -X POST http://localhost:9090/-/reload
```

Direct exporter and OpenSIS UI validation:

```bash
docker compose ps opensis-db mysqld-exporter opensis-ui
docker compose logs --tail=80 opensis-db mysqld-exporter
docker compose exec -T mysqld-exporter wget -qO- http://127.0.0.1:9104/metrics | rg -n '^(mysql_up|mysql_global_status_threads_connected|mysql_global_variables_max_connections|mysql_global_status_slow_queries)' | head -n 20
curl -fsS http://localhost:8088/ >/tmp/opensis-root.html && printf 'opensis-ui-ok\n'
```

Exporter privilege fix and revalidation:

```bash
docker compose up -d --force-recreate mysqld-exporter
git diff --check
docker compose logs --tail=40 mysqld-exporter
docker compose exec -T mysqld-exporter wget -qO- http://127.0.0.1:9104/metrics | rg -n '^(mysql_up|mysql_global_status_threads_connected|mysql_global_variables_max_connections|mysql_global_status_slow_queries)' | head -n 20
sleep 20; curl -fsS http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="opensis-mariadb") | [.labels.job,.health,.scrapeUrl,(.lastError // "")] | @tsv'
```

Control-plane query and audit validation:

```bash
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:mariadb_up' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:mariadb_connection_usage_percent' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
./scripts/devops-monitor.sh opensis-live
./scripts/devops-monitor.sh operator
date '+%Y-%m-%d %H:%M:%S %Z'
git status --short
git diff --stat
git ls-files -s OpenSIS/observability/mysqld-exporter-entrypoint.sh
```

### Changes Made

Added:

- `OpenSIS/observability/mysqld-exporter-entrypoint.sh`

Updated:

- `OpenSIS/.env.example`
- `OpenSIS/docker-compose.yaml`
- `OpenSIS/scripts/mariadb-entrypoint.sh`
- `Obervability-Stack/prometheus/prometheus.yml`
- `Obervability-Stack/prometheus/recording_rules.yml`
- `Obervability-Stack/scripts/opensis-live-audit.sh`
- `METRICS-STRATEGY.md`
- `WORKSPACE-SETUP-MATRIX.md`

### Why These Changes Were Made

OpenSIS previously had central UI blackbox coverage, but the shared control plane could not see MariaDB health or saturation. That left a blind spot for a legacy monolith where database availability is one of the most important operator signals.

The OpenSIS Compose stack now includes:

```text
mysqld-exporter
```

with this shared control-plane alias:

```text
opensis-mysqld-exporter
```

Central Prometheus now scrapes:

```text
opensis-mysqld-exporter:9104/metrics
```

Recording rules were added under:

```text
opensis:*
```

The exporter uses a dedicated MariaDB user:

```text
opensis_exporter
```

instead of scraping with root credentials. The database entrypoint reconciles this user and grants only the exporter-oriented permissions required for the enabled collectors.

### Problems Encountered

Problem:

```text
sed: OpenSIS/docker-compose.yml: No such file or directory
```

Root cause:

The OpenSIS Compose file is named:

```text
OpenSIS/docker-compose.yaml
```

Resolution:

Located the active Compose file with:

```bash
find OpenSIS -maxdepth 4 -type f \( -name 'docker-compose*.yml' -o -name 'compose*.yml' -o -name 'Dockerfile' \) | sort
```

Problem:

```text
Error from scraper scraper=slave_status target=opensis-db:3306 err="Error 1227 (42000): Access denied; you need (at least one of) the SUPER, SLAVE MONITOR privilege(s) for this operation"
```

Root cause:

`mysqld_exporter` enables the `slave_status` collector by default, but this OpenSIS local lab is not running MariaDB replication and the exporter user should not receive unnecessary broad replication privileges.

Resolution:

Disabled the unused collector:

```text
--no-collect.slave_status
```

This removed the privilege error while preserving the database metrics needed for this lab.

Problem:

```text
The old DATA_SOURCE_NAME exporter pattern is no longer the correct path for current mysqld_exporter versions.
```

Root cause:

Current `mysqld_exporter` versions use a `my.cnf` style config file or explicit command-line arguments.

Resolution:

Generated `/tmp/mysqld-exporter.cnf` at container runtime from environment variables and executed:

```text
/bin/mysqld_exporter --config.my-cnf=/tmp/mysqld-exporter.cnf --mysqld.address=opensis-db:3306
```

### Verification

OpenSIS and observability Compose validation passed:

```text
docker compose config --quiet
```

Prometheus config and recording rules passed:

```text
SUCCESS: /etc/prometheus/prometheus.yml is valid prometheus config file syntax
SUCCESS: 56 rules found
```

OpenSIS containers were healthy/running:

```text
opensis-db                Up ... healthy
opensis-mysqld-exporter   Up
opensis-ui                Up ... healthy
```

Exporter direct metrics returned:

```text
mysql_global_status_slow_queries 0
mysql_global_status_threads_connected 1
mysql_global_variables_max_connections 151
mysql_up 1
```

Central Prometheus target was up:

```text
opensis-mariadb  up  http://opensis-mysqld-exporter:9104/metrics
```

Recording rules returned data:

```text
opensis:mariadb_up  1
opensis:mariadb_connection_usage_percent  0.6622516556291391
```

OpenSIS live audit passed:

```text
Checks passed: 24/24
OpenSIS live integration audit passed
```

Operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

Whitespace validation passed:

```text
git diff --check
```

### Follow-Up Work

- Add OpenSIS Vault health and secret-read synthetic checks to central Prometheus.
- Add OpenSIS Apache/PHP request instrumentation or exporter coverage.
- Add Grafana panels for `opensis:*` database health and saturation.

---

## 2026-04-22 05:32 EDT - OpenSIS Vault Synthetic Checks

### Goal

Add production-style Vault synthetic checks for OpenSIS.

The intent was to prove more than port reachability:

- Vault API is reachable
- Vault is initialized and unsealed
- the OpenSIS app secret path is readable through its AppRole
- the OpenSIS DB secret path is readable through its AppRole
- central Prometheus records these checks
- the OpenSIS operator audit validates the new signals

### Commands Run

Initial inspection:

```bash
git status --short
sed -n '1,260p' OpenSIS/docker-compose.yaml
sed -n '260,430p' OpenSIS/docker-compose.yaml
find OpenSIS -maxdepth 3 -type f | sort | rg 'vault|observability|scripts'
```

AppRole and Vault bootstrap inspection:

```bash
docker compose exec -T vault-agent-app sh -lc 'find /vault/approle -maxdepth 2 -type f -print -exec sh -c "printf \"--- %s\n\" \"$1\"; sed -n \"1,5p\" \"$1\"" sh {} \;'
docker compose exec -T vault-agent-db sh -lc 'find /vault/approle -maxdepth 2 -type f -print -exec sh -c "printf \"--- %s\n\" \"$1\"; sed -n \"1,5p\" \"$1\"" sh {} \;'
sed -n '1,220p' OpenSIS/scripts/bootstrap.sh
sed -n '1,120p' OpenSIS/vault-bootstrap/policies/opensis-app-policy.hcl && sed -n '1,120p' OpenSIS/vault-bootstrap/policies/opensis-db-policy.hcl
```

Static validation:

```bash
python3 -m py_compile OpenSIS/observability/vault-synthetic-exporter.py && chmod +x OpenSIS/observability/vault-synthetic-exporter.py && git diff --check
docker compose config --quiet
docker compose config --quiet
docker compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml && docker compose exec -T prometheus promtool check rules /etc/prometheus/recording_rules.yml
```

Runtime apply:

```bash
docker compose up -d vault-synthetic-exporter
curl -fsS -X POST http://localhost:9090/-/reload
```

Direct checker and Prometheus target validation:

```bash
docker compose ps vault-synthetic-exporter && docker compose logs --tail=60 vault-synthetic-exporter
docker compose exec -T vault-synthetic-exporter wget -qO- http://127.0.0.1:9105/metrics | rg -n '^(opensis_vault_health_status|opensis_vault_api_up|opensis_vault_secret_read_success|opensis_vault_secret_read_status_code)'
sleep 20; curl -fsS http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="opensis-vault") | [.labels.job,.health,.scrapeUrl,(.lastError // "")] | @tsv'
```

Recording-rule and audit validation:

```bash
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:vault_health' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:vault_secret_read_success' | jq -r '.data.result[] | [.metric.secret,.value[1]] | @tsv'
curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:vault_all_required_secrets_readable' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
./scripts/devops-monitor.sh opensis-live
./scripts/devops-monitor.sh operator
date '+%Y-%m-%d %H:%M:%S %Z'
git status --short
git diff --stat
```

### Changes Made

Added:

- `OpenSIS/observability/vault-synthetic-exporter.py`

Updated:

- `OpenSIS/docker-compose.yaml`
- `Obervability-Stack/prometheus/prometheus.yml`
- `Obervability-Stack/prometheus/recording_rules.yml`
- `Obervability-Stack/scripts/opensis-live-audit.sh`
- `METRICS-STRATEGY.md`
- `WORKSPACE-SETUP-MATRIX.md`

### Why These Changes Were Made

OpenSIS depends on Vault for rendered app and database secrets. A simple Vault port check is not enough because Vault can be reachable while a required policy, AppRole, or secret path is broken.

The new service:

```text
vault-synthetic-exporter
```

exposes Prometheus metrics through:

```text
opensis-vault-checker:9105/metrics
```

It checks:

```text
kv/data/dev/opensis-app
kv/data/dev/opensis-db
```

using the existing OpenSIS AppRole credentials mounted from:

```text
app_runtime_approle
db_runtime_approle
```

This was intentionally chosen over reading the Vault root token. The root token exists in the local lab for bootstrap, but using it for monitoring would be the wrong operational pattern. The AppRole path proves the same class of access the application and database depend on.

### Problems Encountered

Problem:

```text
sed: : No such file or directory
```

Root cause:

The initial command used a nested `sh -c` pattern incorrectly while trying to print AppRole file contents from inside the Vault agent containers.

Resolution:

The command still proved the AppRole files existed:

```text
/vault/approle/secret_id
/vault/approle/role_id
```

Then the implementation relied on the known AppRole volume paths in Compose rather than printing sensitive credential values.

Problem:

```text
Need to prove secret readability without exposing Vault root-token behavior.
```

Resolution:

Implemented a small Python exporter that authenticates separately through the app and DB AppRoles and reads only the matching required secret path.

### Verification

Python syntax validation passed:

```text
python3 -m py_compile OpenSIS/observability/vault-synthetic-exporter.py
```

OpenSIS and observability Compose validation passed:

```text
docker compose config --quiet
```

Prometheus config and recording rules passed:

```text
SUCCESS: /etc/prometheus/prometheus.yml is valid prometheus config file syntax
SUCCESS: 59 rules found
```

The checker started successfully:

```text
opensis-vault-synthetic-exporter listening on 9105
```

Direct checker metrics returned:

```text
opensis_vault_health_status 1
opensis_vault_api_up 1
opensis_vault_secret_read_success{secret="opensis-app",path="kv/data/dev/opensis-app"} 1
opensis_vault_secret_read_success{secret="opensis-db",path="kv/data/dev/opensis-db"} 1
```

Central Prometheus target was up:

```text
opensis-vault  up  http://opensis-vault-checker:9105/metrics
```

Recording rules returned healthy values:

```text
opensis:vault_health  1
opensis-app  1
opensis-db   1
opensis:vault_all_required_secrets_readable  1
```

OpenSIS live audit passed:

```text
Checks passed: 33/33
OpenSIS live integration audit passed
```

Operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

### Follow-Up Work

- Add OpenSIS Apache/PHP request instrumentation or exporter coverage.
- Add Grafana panels for `opensis:vault_health`, `opensis:vault_all_required_secrets_readable`, and per-secret read status.
- Add alerts for Vault sealed state and required secret read failures.

---

## 2026-04-22 05:42 EDT - OpenSIS Apache Runtime Metrics

### Goal

Add application runtime visibility for the OpenSIS Apache/PHP tier.

The intent was to complete the OpenSIS core metrics path:

- UI blackbox reachability
- MariaDB health and saturation
- Vault health and required secret reads
- Apache runtime health, request traffic, bytes sent, and worker state

### Commands Run

Initial inspection:

```bash
git status --short
sed -n '1,220p' OpenSIS/Dockerfile
find OpenSIS -maxdepth 3 -type f | sort | rg 'apache|php|entrypoint|metrics|conf|Dockerfile|buildlocal'
sed -n '1,220p' OpenSIS/docker-compose.buildlocal.yaml
```

Exporter image and Apache module checks:

```bash
docker manifest inspect lusotycoon/apache-exporter:v1.0.10 >/tmp/apache-exporter-manifest.json && jq -r '.manifests[]? | [.platform.os,.platform.architecture,.platform.variant // ""] | @tsv' /tmp/apache-exporter-manifest.json | sort -u
docker manifest inspect bitnami/apache-exporter:latest >/tmp/bitnami-apache-exporter-manifest.json && jq -r '.manifests[]? | [.platform.os,.platform.architecture,.platform.variant // ""] | @tsv' /tmp/bitnami-apache-exporter-manifest.json | sort -u
sed -n '1,220p' OpenSIS/docker/apache/000-default.conf && sed -n '1,220p' OpenSIS/docker/apache/security-hardening.conf
docker compose exec -T opensis-ui apache2ctl -M | sort
docker run --rm lusotycoon/apache-exporter:v1.0.10 --help | sed -n '1,160p'
docker run --rm bitnami/apache-exporter:latest --help | sed -n '1,160p'
```

Static validation:

```bash
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml config --quiet
docker compose config --quiet
docker compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml && docker compose exec -T prometheus promtool check rules /etc/prometheus/recording_rules.yml
git diff --check
```

Runtime apply:

```bash
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml up -d --build opensis-ui apache-exporter
curl -fsS -X POST http://localhost:9090/-/reload
```

Direct Apache status and exporter validation:

```bash
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml ps opensis-ui apache-exporter && docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml logs --tail=80 opensis-ui apache-exporter
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml exec -T opensis-ui sh -lc 'curl -fsS http://127.0.0.1/server-status?auto | sed -n "1,20p"'
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml exec -T apache-exporter wget -qO- http://127.0.0.1:9117/metrics | rg -n '^(apache_up|apache_accesses_total|apache_sent_kilobytes_total|apache_busy_workers|apache_idle_workers)'
sleep 20; curl -fsS http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="opensis-apache") | [.labels.job,.health,.scrapeUrl,(.lastError // "")] | @tsv'
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml exec -T apache-exporter wget -qO- http://127.0.0.1:9117/metrics | rg -n '^apache_' | sed -n '1,120p'
```

Recording-rule correction and server-status hardening:

```bash
docker compose exec -T prometheus promtool check rules /etc/prometheus/recording_rules.yml && curl -fsS -X POST http://localhost:9090/-/reload
curl -fsS -o /tmp/opensis-status-host.txt -w '%{http_code}\n' http://localhost:8088/server-status?auto
git diff --check
curl -fsS -o /tmp/opensis-status-host.txt -w '%{http_code}\n' 'http://localhost:8088/server-status?auto'
sleep 20; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:apache_up' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
sleep 20; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:apache_busy_workers' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
sleep 20; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:apache_request_rate_5m' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml config --quiet && docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml up -d --build opensis-ui apache-exporter
curl -fsS -o /tmp/opensis-status-no-header.txt -w '%{http_code}\n' 'http://localhost:8088/server-status?auto' || true
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml exec -T apache-exporter wget -qO- http://127.0.0.1:9117/metrics | rg -n '^(apache_up|apache_workers|apache_accesses_total|apache_sent_kilobytes_total)'
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml logs --tail=50 apache-exporter opensis-ui
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml up -d --build opensis-ui apache-exporter
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml logs --tail=30 opensis-ui apache-exporter
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml exec -T apache-exporter wget -qO- http://127.0.0.1:9117/metrics | rg -n '^(apache_up|apache_workers|apache_accesses_total|apache_sent_kilobytes_total)'
sleep 20; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:apache_up' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
sleep 20; curl -fsS --get http://localhost:9090/api/v1/query --data-urlencode 'query=opensis:apache_idle_workers' | jq -r '.data.result[] | [.metric.__name__,.value[1]] | @tsv'
```

Final audit validation:

```bash
./scripts/devops-monitor.sh opensis-live
./scripts/devops-monitor.sh operator
date '+%Y-%m-%d %H:%M:%S %Z'
git status --short
git diff --stat
docker compose -f docker-compose.yaml -f docker-compose.buildlocal.yaml ps opensis-ui apache-exporter
```

### Changes Made

Added:

- `OpenSIS/docker/apache/status.conf`

Updated:

- `OpenSIS/Dockerfile`
- `OpenSIS/docker-compose.yaml`
- `Obervability-Stack/prometheus/prometheus.yml`
- `Obervability-Stack/prometheus/recording_rules.yml`
- `Obervability-Stack/scripts/opensis-live-audit.sh`
- `METRICS-STRATEGY.md`
- `WORKSPACE-SETUP-MATRIX.md`

### Why These Changes Were Made

OpenSIS had blackbox UI checks, MariaDB metrics, and Vault synthetic checks, but the Apache/PHP runtime itself was still a blind spot.

Apache `mod_status` is a pragmatic production-style signal for this legacy PHP runtime. It gives operators request counters, bytes sent, uptime, worker counts, load, and scoreboard state without invasive PHP application changes.

The OpenSIS UI image now enables:

```text
mod_status
ExtendedStatus On
```

The new exporter service is:

```text
apache-exporter
```

with shared control-plane alias:

```text
opensis-apache-exporter
```

Central Prometheus now scrapes:

```text
opensis-apache-exporter:9117/metrics
```

Recording rules were added:

```text
opensis:apache_up
opensis:apache_request_rate_5m
opensis:apache_sent_kilobytes_rate_5m
opensis:apache_busy_workers
opensis:apache_idle_workers
```

### Security Decision

The Apache status endpoint is not left broadly readable.

The endpoint requires:

- source IP from loopback or private Docker/private network ranges
- header `X-OpenSIS-Metrics: apache-exporter`

The exporter sends that header with:

```text
--custom_headers=X-OpenSIS-Metrics:apache-exporter
```

This is not a replacement for real network policy in Kubernetes, but it is a good local-lab control and maps cleanly to future Service/NetworkPolicy boundaries.

### Problems Encountered

Problem:

```text
zsh:1: no matches found: http://localhost:8088/server-status?auto
```

Root cause:

The URL contained `?auto`, and zsh treated it as a glob pattern when the URL was not quoted.

Resolution:

Quoted the URL:

```bash
curl -fsS -o /tmp/opensis-status-host.txt -w '%{http_code}\n' 'http://localhost:8088/server-status?auto'
```

Problem:

```text
Initial recording rules expected apache_busy_workers and apache_idle_workers.
```

Root cause:

The Apache exporter actually exposes worker counts as:

```text
apache_workers{state="busy"}
apache_workers{state="idle"}
```

Resolution:

Updated recording rules to use the real metric shape.

Problem:

```text
Host access to /server-status?auto initially returned 200.
```

Root cause:

The initial Apache status config allowed private IP ranges so the exporter could scrape from Docker networking. Host access through the loopback-published app port still appeared from a Docker bridge address.

Resolution:

Added the required metrics header check. Host access without the header now returns:

```text
403
```

Problem:

```text
Apache emitted AH00558 server name warnings on startup.
```

Resolution:

Added:

```text
ServerName localhost
```

to the enabled Apache status/runtime configuration.

### Verification

Exporter image platform support included ARM64:

```text
linux  arm64  v8
```

OpenSIS and observability Compose validation passed:

```text
docker compose config --quiet
```

Prometheus config and rules passed:

```text
SUCCESS: /etc/prometheus/prometheus.yml is valid prometheus config file syntax
SUCCESS: 64 rules found
```

OpenSIS UI and Apache exporter were running:

```text
opensis-ui                Up ... healthy
opensis-apache-exporter   Up
```

Apache status returned internal runtime data from inside the container:

```text
ServerVersion: Apache/2.4.66 (Debian) PHP/8.2.30
ServerMPM: prefork
Total Accesses: 9
Total kBytes: 51
```

Apache exporter returned:

```text
apache_accesses_total 8
apache_sent_kilobytes_total 36
apache_up 1
apache_workers{state="busy"} 1
apache_workers{state="idle"} 5
```

Host access to the status endpoint without the metrics header was denied:

```text
403
```

Central Prometheus target was up:

```text
opensis-apache  up  http://opensis-apache-exporter:9117/metrics
```

Recording rules returned data:

```text
opensis:apache_up  1
opensis:apache_busy_workers  1
opensis:apache_idle_workers  5
opensis:apache_request_rate_5m  0.06873993800309985
```

OpenSIS live audit passed:

```text
Checks passed: 39/39
OpenSIS live integration audit passed
```

Operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

### Follow-Up Work

- Add Grafana panels for OpenSIS Apache, Vault, and MariaDB recording rules.
- Add actionable alerts for Apache exporter down, Apache runtime down, no idle workers, Vault sealed, Vault required-secret read failure, and MariaDB down.
- Map these Docker Compose exporter patterns to Kubernetes Services and ServiceMonitors during the k3s phase.

## 2026-04-22 05:47 EDT - Managed App Recording Rule Alerts

### Objective

Turn the new managed-app recording rules into actionable Prometheus alerts before moving further into dashboards and Kubernetes packaging.

This step follows the metrics roadmap by adding alert coverage for the signals we already made real:

- OpenSIS MariaDB, Vault, and Apache runtime signals.
- MemFlip backend health, error ratio, and latency.
- FoodPulse API scrape health, error ratio, and latency.

### Commands Run

Checked the working tree and inspected the existing alert and recording-rule structure:

```bash
git status --short
sed -n '1,380p' Obervability-Stack/prometheus/alert_rules.yml
sed -n '1,260p' Obervability-Stack/prometheus/recording_rules.yml
rg -n "runbook_url|opensis|foodpulse|memflip|swiftpay|High" Obervability-Stack/prometheus/alert_rules.yml METRICS-STRATEGY.md INCIDENT-RESPONSE.md
sed -n '360,760p' Obervability-Stack/prometheus/alert_rules.yml
rg -n "managed_app|OpenSISMariaDB|FoodPulse|MemFlip|application_alerts|recording" Obervability-Stack/prometheus/alert_rules.yml METRICS-STRATEGY.md JOURNEY-RUNBOOK.md INCIDENT-RESPONSE.md
sed -n '240,430p' Obervability-Stack/prometheus/alert_rules.yml
sed -n '120,155p' METRICS-STRATEGY.md
tail -n 80 JOURNEY-RUNBOOK.md
rg --files Obervability-Stack/docs | sort
rg -n "OPENSIS|FOODPULSE|MEMFLIP|Operator Runbook|runbook" Obervability-Stack/docs Obervability-Stack/ui-next/lib -g '!**/node_modules/**'
```

Confirmed Prometheus was running before validating rule changes:

```bash
date '+%Y-%m-%d %H:%M %Z'
docker compose -f Obervability-Stack/docker-compose.yml ps prometheus
git diff -- Obervability-Stack/prometheus/alert_rules.yml METRICS-STRATEGY.md JOURNEY-RUNBOOK.md | sed -n '1,260p'
```

### What Changed

Added a dedicated `managed_app_signal_alerts` group in:

```text
Obervability-Stack/prometheus/alert_rules.yml
```

New OpenSIS alerts:

- `OpenSISMariaDBExporterDown`
- `OpenSISMariaDBDown`
- `OpenSISMariaDBConnectionUsageHigh`
- `OpenSISMariaDBSlowQueriesDetected`
- `OpenSISVaultSyntheticExporterDown`
- `OpenSISVaultUnhealthy`
- `OpenSISVaultRequiredSecretReadFailed`
- `OpenSISApacheExporterDown`
- `OpenSISApacheRuntimeDown`
- `OpenSISApacheNoIdleWorkers`

New MemFlip alerts:

- `MemFlipBackendMetricsDown`
- `MemFlipAppHealthDown`
- `MemFlipHighAPIErrorRatio`
- `MemFlipHighAPILatency`

New FoodPulse alerts:

- `FoodPulseAPIMetricsDown`
- `FoodPulseHighAPIErrorRatio`
- `FoodPulseHighAPILatency`

Updated:

```text
METRICS-STRATEGY.md
```

The backlog now keeps Grafana dashboards next and clarifies that SLO burn-rate alerts should wait until enough stable historical data exists.

### Why We Did This

Recording rules made the raw metrics easier to query, but they did not yet create operator action. These alerts turn the metrics into production-style symptoms an operator can respond to.

The new alerts intentionally avoid traffic-volume-only conditions. High request rate by itself is not an outage. The alert set focuses instead on:

- telemetry foundations being down
- application health being down
- database availability and pressure
- Vault secret-read failures
- Apache worker exhaustion
- persistent API error ratio
- persistent API latency

### Problems Found And Fixes

No file-level conflict was present before editing.

The main design problem was avoiding duplicate alert noise. The existing `application_alerts` group already covered broad blackbox and SwiftPay-specific symptoms. Instead of mixing the new rules into that group, we created `managed_app_signal_alerts` so the new alerts are clearly tied to managed-app recording rules and can later map cleanly to Kubernetes `PrometheusRule` resources.

### Validation

Checked Prometheus rule syntax:

```bash
docker compose -f Obervability-Stack/docker-compose.yml exec -T prometheus promtool check rules /etc/prometheus/alert_rules.yml /etc/prometheus/recording_rules.yml
```

Result:

```text
Checking /etc/prometheus/alert_rules.yml
  SUCCESS: 57 rules found

Checking /etc/prometheus/recording_rules.yml
  SUCCESS: 64 rules found
```

Checked formatting:

```bash
git diff --check
```

Result: no output, which means no whitespace errors were detected.

Reloaded Prometheus:

```bash
curl -fsS -X POST http://localhost:9090/-/reload
```

Confirmed the reload status and live rule group:

```bash
curl -fsS http://localhost:9090/api/v1/status/config | jq -r '.data.yaml' | rg -n "rule_files|alert_rules|recording_rules" -C 3
curl -fsS http://localhost:9090/api/v1/status/runtimeinfo | jq -r '["reloadConfigSuccess=" + (.data.reloadConfigSuccess|tostring), "lastConfigTime=" + .data.lastConfigTime] | .[]'
curl -fsS http://localhost:9090/api/v1/rules | jq -r '.data.groups[].name' | sort
docker compose -f Obervability-Stack/docker-compose.yml exec -T prometheus sh -c "grep -n 'managed_app_signal_alerts' /etc/prometheus/alert_rules.yml"
```

Result:

```text
reloadConfigSuccess=true
lastConfigTime=2026-04-22T09:48:21Z
managed_app_signal_alerts
464:  - name: managed_app_signal_alerts
```

The first live alert query used the wrong JSON field shape and returned no rows:

```bash
curl -fsS http://localhost:9090/api/v1/rules | jq -r '.data.groups[] | select(.name=="managed_app_signal_alerts") | .rules[] | [.name,.state] | @tsv'
```

Fix:

Use the alert-rule fields explicitly:

```bash
curl -fsS http://localhost:9090/api/v1/rules | jq -r '.data.groups[] | select(.name=="managed_app_signal_alerts") | .rules[] | [.name, .type, .state] | @tsv'
curl -fsS 'http://localhost:9090/api/v1/alerts' | jq -r '.data.alerts[] | select(.labels.service=="opensis" or .labels.service=="foodpulse" or .labels.service=="memflip") | [.labels.alertname,.state,.labels.severity,.labels.component] | @tsv'
curl -fsS http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name=="managed_app_signal_alerts") | .rules[0]'
```

Result:

```text
OpenSISMariaDBExporterDown	alerting	inactive
OpenSISMariaDBDown	alerting	inactive
OpenSISMariaDBConnectionUsageHigh	alerting	inactive
OpenSISMariaDBSlowQueriesDetected	alerting	inactive
OpenSISVaultSyntheticExporterDown	alerting	inactive
OpenSISVaultUnhealthy	alerting	inactive
OpenSISVaultRequiredSecretReadFailed	alerting	inactive
OpenSISApacheExporterDown	alerting	inactive
OpenSISApacheRuntimeDown	alerting	inactive
OpenSISApacheNoIdleWorkers	alerting	inactive
MemFlipBackendMetricsDown	alerting	inactive
MemFlipAppHealthDown	alerting	inactive
MemFlipHighAPIErrorRatio	alerting	inactive
MemFlipHighAPILatency	alerting	inactive
FoodPulseAPIMetricsDown	alerting	inactive
FoodPulseHighAPIErrorRatio	alerting	inactive
FoodPulseHighAPILatency	alerting	inactive
```

No OpenSIS, MemFlip, or FoodPulse alerts were firing after the reload.

Tried the root-level operator command:

```bash
./scripts/devops-monitor.sh operator
```

Problem:

```text
zsh:1: no such file or directory: ./scripts/devops-monitor.sh
```

Fix:

Run the script from its real repo-root path:

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
```

Result:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
OpenSIS: healthy | primary=OpenSIS UI | latency=47ms | browser=http://localhost:8088
SwiftPay: healthy | primary=SwiftPay Frontend | latency=1ms | browser=http://localhost:8081
MemFlip: healthy | primary=MemFlip Frontend | latency=5ms | browser=http://localhost:8080
FoodPulse: healthy | primary=FoodPulse UI | latency=1ms | browser=http://localhost:8090
```

The operator script prints follow-up commands as `./scripts/devops-monitor.sh ...` because those paths are relative to `Obervability-Stack`. From the repository root, use `./Obervability-Stack/scripts/devops-monitor.sh ...`.

Checked the final worktree summary:

```bash
git diff --stat
git status --short
```

Result:

```text
JOURNEY-RUNBOOK.md                            | 239 +++++++++++++++++++++++++
METRICS-STRATEGY.md                           |   2 +-
Obervability-Stack/prometheus/alert_rules.yml | 240 ++++++++++++++++++++++++++
3 files changed, 480 insertions(+), 1 deletion(-)
```

## 2026-04-22 05:59 EDT - OpenSIS Grafana Operations Dashboard

### Objective

Start the app-specific Grafana dashboard work in the recommended order by building the OpenSIS dashboard first.

OpenSIS was selected first because it now has the richest managed-app signal set:

- blackbox UI availability and latency
- MariaDB availability, connection saturation, and slow-query rate
- Vault health and required secret-read checks
- Apache runtime availability, request rate, worker pressure, and egress rate
- firing alert count for the OpenSIS service

### Commands Run

Inspected the current Grafana provisioning layout and existing dashboard conventions:

```bash
find Obervability-Stack -maxdepth 5 -type f \( -iname '*dashboard*' -o -iname '*.json' -o -iname '*.yml' -o -iname '*.yaml' \) | sort
rg -n "dashboard|dashboards|grafana|provision" Obervability-Stack/docker-compose.yml Obervability-Stack/grafana Obervability-Stack/docs METRICS-STRATEGY.md PROJECT-ROADMAP.md -g '!**/node_modules/**'
git status --short --branch
sed -n '1,260p' Obervability-Stack/docker-compose.yml
sed -n '1,140p' Obervability-Stack/grafana/dashboards/dashboard.yml
jq '{title, uid, schemaVersion, refresh, panels: [.panels[] | {id,title,type,targets: [.targets[]? | {expr, legendFormat}]}]}' Obervability-Stack/grafana/dashboards/node-exporter.json | sed -n '1,240p'
find Obervability-Stack/grafana/dashboards -maxdepth 3 -type d -print | sort
sed -n '1,120p' Obervability-Stack/grafana/datasources/datasource.yml
```

Created the application dashboard provider directory:

```bash
mkdir -p Obervability-Stack/grafana/dashboards/application
```

Validated the new dashboard JSON:

```bash
jq empty Obervability-Stack/grafana/dashboards/application/opensis-operations.json
python3 -m json.tool Obervability-Stack/grafana/dashboards/application/opensis-operations.json >/tmp/opensis-dashboard.pretty.json
git diff --check
```

Checked live Grafana datasource UIDs:

```bash
curl -fsS -u admin:admin http://localhost:3000/api/datasources | jq -r '.[] | [.name,.uid,.type,.url] | @tsv'
```

Restarted Grafana after provisioning changes:

```bash
docker compose -f Obervability-Stack/docker-compose.yml restart grafana
for i in {1..30}; do if curl -fsS http://localhost:3000/api/health >/tmp/grafana-health.json; then cat /tmp/grafana-health.json; exit 0; fi; sleep 2; done; exit 1
```

Confirmed datasource UIDs and dashboard availability through Grafana APIs:

```bash
curl -fsS -u admin:admin http://localhost:3000/api/datasources | jq -r '.[] | [.name,.uid,.type,.url] | @tsv'
curl -fsS -u admin:admin http://localhost:3000/api/dashboards/uid/opensis-operations | jq '{title: .dashboard.title, uid: .dashboard.uid, folderTitle: .meta.folderTitle, panels: (.dashboard.panels|length), url: .meta.url}'
curl -fsS -u admin:admin 'http://localhost:3000/api/search?query=OpenSIS' | jq -r '.[] | [.title,.uid,.folderTitle,.url] | @tsv'
curl -fsS -u admin:admin http://localhost:3000/api/dashboards/uid/opensis-operations | jq -r '.dashboard.panels[] | [.id,.title,.type,([.targets[]?.expr] | join(" | "))] | @tsv'
```

Cleaned up the dashboard provider model so app and system dashboards have dedicated directories:

```bash
mkdir -p Obervability-Stack/grafana/dashboards/system Obervability-Stack/grafana/dashboards/infrastructure Obervability-Stack/grafana/dashboards/alerting
git mv Obervability-Stack/grafana/dashboards/node-exporter.json Obervability-Stack/grafana/dashboards/system/node-exporter.json
docker compose -f Obervability-Stack/docker-compose.yml restart grafana
for i in {1..30}; do if curl -fsS http://localhost:3000/api/health >/tmp/grafana-health.json; then cat /tmp/grafana-health.json; exit 0; fi; sleep 2; done; exit 1
```

After review, removed the empty `infrastructure` and `alerting` provider directories from the active provider model because empty directories cannot be reliably tracked in Git without placeholder files, and placeholder files can be misread by Grafana provisioning:

```bash
rmdir Obervability-Stack/grafana/dashboards/infrastructure Obervability-Stack/grafana/dashboards/alerting
```

Inspected the mounted provisioning files inside the Grafana container:

```bash
docker exec grafana sh -c 'echo ---dashboard.yml---; sed -n "1,90p" /etc/grafana/provisioning/dashboards/dashboard.yml; echo ---dirs---; find /etc/grafana/provisioning/dashboards -maxdepth 2 -type d -print; echo ---files---; find /etc/grafana/provisioning/dashboards -maxdepth 3 -type f -print'
docker exec grafana sh -c 'tail -n 220 /var/log/grafana/grafana.log 2>/dev/null || tail -n 220 /var/lib/grafana/grafana.log 2>/dev/null' | sed -n '120,220p'
find Obervability-Stack/grafana/dashboards -maxdepth 3 -type d -print && find Obervability-Stack/grafana/dashboards -maxdepth 3 -type f -print | sort
```

Reloaded Grafana provisioning:

```bash
curl -fsS -u admin:admin -X POST http://localhost:3000/api/admin/provisioning/datasources/reload
curl -fsS -u admin:admin -X POST http://localhost:3000/api/admin/provisioning/dashboards/reload
```

Validated each dashboard PromQL expression against Prometheus:

```bash
jq -r '.. | objects | select(has("expr")) | .expr' Obervability-Stack/grafana/dashboards/application/opensis-operations.json | sort -u | while IFS= read -r expr; do encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$expr"); status=$(curl -fsS "http://localhost:9090/api/v1/query?query=$encoded" | jq -r '.status'); printf '%s\t%s\n' "$status" "$expr"; done
```

The first query-validation helper failed because `status` is read-only in zsh:

```text
zsh:1: read-only variable: status
```

Fix:

Use a different variable name:

```bash
jq -r '.. | objects | select(has("expr")) | .expr' Obervability-Stack/grafana/dashboards/application/opensis-operations.json | sort -u | while IFS= read -r expr; do encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$expr"); query_status=$(curl -fsS "http://localhost:9090/api/v1/query?query=$encoded" | jq -r '.status'); printf '%s\t%s\n' "$query_status" "$expr"; done
```

Ran the operator check:

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
```

### What Changed

Added:

```text
Obervability-Stack/grafana/dashboards/application/opensis-operations.json
```

The dashboard is titled:

```text
OpenSIS Operations
```

It contains 12 panels:

- `UI Probe`
- `MariaDB`
- `Vault Health`
- `Apache Runtime`
- `Firing Alerts`
- `OpenSIS Probe Latency`
- `Apache Request Rate`
- `MariaDB Connection Usage`
- `MariaDB Slow Queries`
- `Vault Required Secret Reads`
- `Apache Worker Pool`
- `Apache Egress`

Updated:

```text
Obervability-Stack/grafana/datasources/datasource.yml
```

The datasource provisioning now assigns stable UIDs:

```text
Prometheus    prometheus
Loki          loki
Alertmanager  alertmanager
Jaeger        jaeger
TestData      testdata
```

Updated:

```text
Obervability-Stack/grafana/dashboards/dashboard.yml
```

The broad recursive default provider was removed. Dashboards now have explicit provider directories for active dashboard types:

- `system`
- `application`

`infrastructure` and `alerting` providers should be added when real dashboards exist for those categories.

Moved:

```text
Obervability-Stack/grafana/dashboards/node-exporter.json
```

to:

```text
Obervability-Stack/grafana/dashboards/system/node-exporter.json
```

Updated:

```text
METRICS-STRATEGY.md
```

OpenSIS now records dashboard coverage as implemented, and the next dashboard backlog is FoodPulse, MemFlip, and SwiftPay.

### Why We Did This

The previous metrics work gave us raw signals and recording rules. Grafana turns those signals into an operator-facing view.

This matters because a real platform does not ask an operator to remember PromQL during an incident. The dashboard should answer the first questions quickly:

- Is the app reachable?
- Is the database up and saturated?
- Is Vault healthy and are required secrets readable?
- Is Apache serving traffic?
- Are Apache workers becoming exhausted?
- Are OpenSIS alerts firing?

The dashboard is also Kubernetes-minded. It uses recording rules and stable datasource UIDs, so the same panel queries can later move behind Kubernetes `ServiceMonitor` and Grafana provisioning without rewriting the operational story.

### Problems Found And Fixes

#### 1. Grafana datasource UIDs were auto-generated

Live Grafana initially showed generated datasource UIDs:

```text
Prometheus  PBFA97CFB590B2093
Loki        P8E80F9AEF21F6940
```

That is fragile for provisioned dashboards because a recreated Grafana volume can change UIDs.

Fix:

Added stable `uid` values in `Obervability-Stack/grafana/datasources/datasource.yml`.

#### 2. Dashboard provider directories were referenced but missing

`dashboard.yml` referenced `system`, `application`, `infrastructure`, and `alerting`, but those directories were not all present.

Fix:

Created the active provider directories and moved the node exporter dashboard into `system`.

Follow-up correction:

Removed inactive empty providers for `infrastructure` and `alerting`. They should not be active until there are real dashboards to provision.

#### 3. The broad default provider caught subdirectory dashboards

The original default provider pointed at the dashboard root and used `foldersFromFilesStructure: true`. That could catch dashboards from subdirectories before the app-specific provider.

Fix:

Removed the broad default provider and made each provider explicit.

#### 4. Existing Grafana volume kept older folder metadata

After the provider cleanup, the live API still reported the OpenSIS and node exporter dashboards under `General`.

Evidence:

```text
OpenSIS Operations  opensis-operations  /d/opensis-operations/opensis-operations
Node Exporter Dashboard  node-exporter  /d/node-exporter/node-exporter-dashboard
```

Grafana's live database already had provisioned dashboard records from the previous provider layout. We did not wipe the Grafana volume because that would be destructive to local state and unnecessary for the code change.

Decision:

Leave the code in the correct future-safe shape and document that existing local Grafana state may keep old folder metadata until the volume is recreated or manually cleaned. Fresh environments should provision with the explicit provider layout.

#### 5. zsh reserves `status`

The first PromQL validation loop used `status` as a variable and failed:

```text
zsh:1: read-only variable: status
```

Fix:

Renamed the variable to `query_status`.

### Validation

Grafana health passed after restart:

```text
{
  "commit": "81d85ce802",
  "database": "ok",
  "version": "10.0.0"
}
```

Datasource UIDs are now stable:

```text
Alertmanager  alertmanager  alertmanager  http://alertmanager:9093
Jaeger        jaeger        jaeger        http://jaeger:16686
Loki          loki          loki          http://loki:3100
Prometheus    prometheus    prometheus    http://prometheus:9090
TestData      testdata      testdata
```

The OpenSIS dashboard loads through the Grafana API:

```text
title: OpenSIS Operations
uid: opensis-operations
panels: 12
url: /d/opensis-operations/opensis-operations
```

All dashboard PromQL expressions returned `success`:

```text
success	app:probe_latency_p95_seconds{app="opensis"}
success	count(ALERTS{service="opensis",alertstate="firing"}) or vector(0)
success	max(probe_success{job="blackbox-http",app="opensis"})
success	opensis:apache_busy_workers
success	opensis:apache_idle_workers
success	opensis:apache_request_rate_5m
success	opensis:apache_sent_kilobytes_rate_5m * 1024
success	opensis:apache_up
success	opensis:mariadb_connection_usage_percent
success	opensis:mariadb_slow_queries_rate_5m
success	opensis:mariadb_up
success	opensis:vault_health
success	opensis:vault_secret_read_success
```

Operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
OpenSIS: healthy | primary=OpenSIS UI | latency=62ms | browser=http://localhost:8088
SwiftPay: healthy | primary=SwiftPay Frontend | latency=1ms | browser=http://localhost:8081
MemFlip: healthy | primary=MemFlip Frontend | latency=4ms | browser=http://localhost:8080
FoodPulse: healthy | primary=FoodPulse UI | latency=3ms | browser=http://localhost:8090
```

### Next Step

Continue the dashboard pattern in this order:

1. FoodPulse operations dashboard
2. MemFlip onboarding dashboard
3. SwiftPay money-flow dashboard

## 2026-04-22 06:15 EDT - FoodPulse Grafana Operations Dashboard

### Objective

Continue the app-specific Grafana dashboard rollout with FoodPulse after completing OpenSIS.

FoodPulse was selected second because it represents the resilience and voting-behavior story. The goal was to expose the central signals we already have without pretending that every HA dependency is centrally exported yet.

Current central FoodPulse coverage includes:

- blackbox UI availability and latency
- API scrape health
- API request rate
- API error ratio
- API p95 latency
- vote rate
- pageviews
- leading venue votes
- API process memory
- firing alert count for the FoodPulse service

### Commands Run

Checked the branch state, FoodPulse recording rules, alert rules, scrape config, and existing dashboard inventory:

```bash
git status --short --branch
rg -n "foodpulse" Obervability-Stack/prometheus/recording_rules.yml Obervability-Stack/prometheus/alert_rules.yml Obervability-Stack/prometheus/prometheus.yml METRICS-STRATEGY.md
find Obervability-Stack/grafana/dashboards -maxdepth 3 -type f -print | sort
sed -n '1,180p' Obervability-Stack/grafana/dashboards/dashboard.yml && sed -n '90,125p' METRICS-STRATEGY.md
```

Validated the new dashboard JSON and every PromQL expression:

```bash
jq empty Obervability-Stack/grafana/dashboards/application/foodpulse-operations.json
jq -r '.. | objects | select(has("expr")) | .expr' Obervability-Stack/grafana/dashboards/application/foodpulse-operations.json | sort -u | while IFS= read -r expr; do encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$expr"); query_status=$(curl -fsS "http://localhost:9090/api/v1/query?query=$encoded" | jq -r '.status'); printf '%s\t%s\n' "$query_status" "$expr"; done
jq '{title,uid,panels: [.panels[] | {id,title,type,exprs: [.targets[]?.expr]}]}' Obervability-Stack/grafana/dashboards/application/foodpulse-operations.json | sed -n '1,260p'
git diff --check
```

Reloaded Grafana dashboard provisioning and verified the dashboard through Grafana APIs:

```bash
curl -fsS -u admin:admin -X POST http://localhost:3000/api/admin/provisioning/dashboards/reload
curl -fsS -u admin:admin http://localhost:3000/api/dashboards/uid/foodpulse-operations | jq '{title: .dashboard.title, uid: .dashboard.uid, folderTitle: .meta.folderTitle, panels: (.dashboard.panels|length), url: .meta.url}'
curl -fsS -u admin:admin 'http://localhost:3000/api/search?query=FoodPulse' | jq -r '.[] | [.title,.uid,.folderTitle,.url] | @tsv'
docker exec grafana sh -c 'tail -n 80 /var/log/grafana/grafana.log 2>/dev/null || tail -n 80 /var/lib/grafana/grafana.log 2>/dev/null' | rg -n "foodpulse|FoodPulse|failed|error|duplicate|Cannot read directory|failed to search"
```

Ran the operator check:

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
```

Captured timestamp and worktree state:

```bash
date '+%Y-%m-%d %H:%M %Z'
git status --short && git diff --stat
```

### What Changed

Added:

```text
Obervability-Stack/grafana/dashboards/application/foodpulse-operations.json
```

The dashboard is titled:

```text
FoodPulse Operations
```

It contains 13 panels:

- `UI Probe`
- `API Scrape`
- `API Error Ratio`
- `API p95 Latency`
- `Firing Alerts`
- `FoodPulse Probe Latency`
- `API Request Rate`
- `API Error Ratio Trend`
- `API Latency Trend`
- `API Process Memory`
- `Vote Rate`
- `Pageviews`
- `Leading Venue Votes`

Updated:

```text
METRICS-STRATEGY.md
```

FoodPulse now records dashboard coverage as implemented, and the remaining dashboard backlog is MemFlip and SwiftPay.

### Why We Did This

FoodPulse is the resilience and voting lab. The dashboard needs to show whether the user-facing path is alive, whether the API is healthy, whether requests are failing or slowing down, and whether voting behavior is moving.

We intentionally did not add panels for PostgreSQL primary/replica health, HAProxy backend health, Redis Sentinel state, or failover topology yet because those are not centrally exported into the shared Prometheus stack today. Adding fake or unavailable panels would weaken the dashboard. The honest production-grade choice is to show the central metrics we actually have and leave dependency topology as a future instrumentation step.

### Problems Found And Fixes

No code conflict was present before editing.

The main design constraint was metric truthfulness. `METRICS-STRATEGY.md` lists FoodPulse dependency health as a target, but current central recording rules only cover API, UI probe, and voting/business signals. The dashboard therefore avoids dependency panels until those exporters or synthetic checks are centrally wired.

The Grafana provider cleanup from the previous OpenSIS step worked correctly for this new dashboard. Unlike the existing OpenSIS dashboard record in the local Grafana volume, the new FoodPulse dashboard provisioned directly under:

```text
Application Monitoring
```

### Validation

Dashboard JSON passed:

```text
jq empty Obervability-Stack/grafana/dashboards/application/foodpulse-operations.json
```

All dashboard PromQL expressions returned `success`:

```text
success	app:probe_latency_p95_seconds{app="foodpulse"}
success	count(ALERTS{service="foodpulse",alertstate="firing"}) or vector(0)
success	foodpulse:api_process_resident_memory_bytes
success	foodpulse:api_up
success	foodpulse:http_error_ratio_5m
success	foodpulse:http_p95_latency_seconds
success	foodpulse:http_request_rate_5m
success	foodpulse:leading_venue_votes
success	foodpulse:pageviews
success	foodpulse:votes_rate_5m
success	max(probe_success{job="blackbox-http",app="foodpulse"})
```

Grafana provisioning reload succeeded:

```text
{"message":"Dashboards config reloaded"}
```

The dashboard loaded through the Grafana API:

```text
title: FoodPulse Operations
uid: foodpulse-operations
folderTitle: Application Monitoring
panels: 13
url: /d/foodpulse-operations/foodpulse-operations
```

Grafana search found the dashboard:

```text
FoodPulse Operations	foodpulse-operations	Application Monitoring	/d/foodpulse-operations/foodpulse-operations
```

Operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
OpenSIS: healthy | primary=OpenSIS UI | latency=72ms | browser=http://localhost:8088
SwiftPay: healthy | primary=SwiftPay Frontend | latency=2ms | browser=http://localhost:8081
MemFlip: healthy | primary=MemFlip Frontend | latency=5ms | browser=http://localhost:8080
FoodPulse: healthy | primary=FoodPulse UI | latency=3ms | browser=http://localhost:8090
```

### Next Step

Continue the dashboard pattern in this order:

1. MemFlip onboarding dashboard
2. SwiftPay money-flow dashboard

## 2026-04-22 15:18 EDT - MemFlip Grafana Onboarding Dashboard

### Objective

Continue the app-specific Grafana dashboard rollout with MemFlip after OpenSIS and FoodPulse.

MemFlip was selected third because it represents the smallest repeatable app onboarding pattern. The dashboard should teach what a lightweight app needs to expose to become a first-class managed workload:

- frontend probe health
- backend probe health
- backend metrics scrape health
- app health signal
- request rate
- error ratio
- p95 latency
- active games
- completed games
- firing alert count

### Commands Run

Checked repo state, MemFlip recording rules, alert rules, scrape config, and current dashboard inventory:

```bash
git status --short --branch
rg -n "memflip" Obervability-Stack/prometheus/recording_rules.yml Obervability-Stack/prometheus/alert_rules.yml Obervability-Stack/prometheus/prometheus.yml METRICS-STRATEGY.md
find Obervability-Stack/grafana/dashboards/application -maxdepth 1 -type f -print | sort
sed -n '78,105p' METRICS-STRATEGY.md
```

Validated the dashboard JSON and PromQL expressions:

```bash
jq empty Obervability-Stack/grafana/dashboards/application/memflip-onboarding.json
jq -r '.. | objects | select(has("expr")) | .expr' Obervability-Stack/grafana/dashboards/application/memflip-onboarding.json | sort -u | while IFS= read -r expr; do encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$expr"); query_status=$(curl -fsS "http://localhost:9090/api/v1/query?query=$encoded" | jq -r '.status'); result_count=$(curl -fsS "http://localhost:9090/api/v1/query?query=$encoded" | jq -r '.data.result | length'); printf '%s\t%s\t%s\n' "$query_status" "$result_count" "$expr"; done
curl -fsS 'http://localhost:9090/api/v1/query?query=probe_success%7Bjob%3D%22blackbox-http%22%2Capp%3D%22memflip%22%7D' | jq -r '.data.result[] | [.metric.component,.metric.instance,.value[1]] | @tsv'
git diff --check
```

The first validation pass found that the MemFlip error-ratio recording rule returned no series when no error metric samples existed:

```text
success	0	memflip:http_error_ratio_5m
```

Fixed the dashboard expression by using a zero fallback:

```text
memflip:http_error_ratio_5m or vector(0)
```

Revalidated:

```bash
jq empty Obervability-Stack/grafana/dashboards/application/memflip-onboarding.json
jq -r '.. | objects | select(has("expr")) | .expr' Obervability-Stack/grafana/dashboards/application/memflip-onboarding.json | sort -u | while IFS= read -r expr; do encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$expr"); response=$(curl -fsS "http://localhost:9090/api/v1/query?query=$encoded"); query_status=$(printf '%s' "$response" | jq -r '.status'); result_count=$(printf '%s' "$response" | jq -r '.data.result | length'); printf '%s\t%s\t%s\n' "$query_status" "$result_count" "$expr"; done
jq '{title,uid,panels: [.panels[] | {id,title,type,exprs: [.targets[]?.expr]}]}' Obervability-Stack/grafana/dashboards/application/memflip-onboarding.json | sed -n '1,260p'
```

Reloaded Grafana provisioning and checked the dashboard:

```bash
curl -fsS -u admin:admin -X POST http://localhost:3000/api/admin/provisioning/dashboards/reload
curl -fsS -u admin:admin http://localhost:3000/api/dashboards/uid/memflip-onboarding | jq '{title: .dashboard.title, uid: .dashboard.uid, folderTitle: .meta.folderTitle, panels: (.dashboard.panels|length), url: .meta.url}'
curl -fsS -u admin:admin 'http://localhost:3000/api/search?query=MemFlip' | jq -r '.[] | [.title,.uid,.folderTitle,.url] | @tsv'
docker exec grafana sh -c 'tail -n 80 /var/log/grafana/grafana.log 2>/dev/null || tail -n 80 /var/lib/grafana/grafana.log 2>/dev/null' | rg -n "memflip|MemFlip|failed|error|duplicate|Cannot read directory|failed to search"
```

Ran the operator check and captured timestamp/worktree state:

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
date '+%Y-%m-%d %H:%M %Z'
git status --short && git diff --stat
```

### What Changed

Added:

```text
Obervability-Stack/grafana/dashboards/application/memflip-onboarding.json
```

The dashboard is titled:

```text
MemFlip Onboarding
```

It contains 12 panels:

- `Frontend Probe`
- `Backend Probe`
- `App Health`
- `API Error Ratio`
- `Firing Alerts`
- `MemFlip Probe Latency`
- `Backend Request Rate`
- `Backend Error Ratio Trend`
- `Backend Latency Trend`
- `Active Games`
- `Completed Games`
- `Backend Metrics Scrape`

Updated:

```text
METRICS-STRATEGY.md
```

MemFlip now records dashboard coverage as implemented, and the remaining app dashboard backlog is SwiftPay.

### Why We Did This

MemFlip is not the flagship workload. Its value is showing the smallest repeatable onboarding path for a browser-first app:

- blackbox probes prove user-facing reachability
- backend scrape health proves central Prometheus can collect app metrics
- app health proves the backend can report its own internal state
- request, error, and latency panels provide a basic service-quality view
- active/completed game panels prove the app is doing business work

This is the right dashboard pattern for small services we onboard later. It is intentionally compact compared with OpenSIS and FoodPulse.

### Problems Found And Fixes

#### 1. Error ratio returned no data when there were no errors

Initial validation showed:

```text
success	0	memflip:http_error_ratio_5m
```

That is a bad dashboard experience because a healthy zero-error state can look like missing telemetry.

Fix:

The dashboard uses:

```text
memflip:http_error_ratio_5m or vector(0)
```

This keeps the panel honest: if no error series exists, the dashboard displays `0`.

#### 2. Probe labels were verified before relying on component filters

Checked live blackbox probe labels:

```text
backend	http://memflip-backend:3001/health	1
frontend	http://memflip-frontend/api/health	1
```

This confirmed that `component="frontend"` and `component="backend"` are safe for the dashboard stat panels.

### Validation

Dashboard JSON passed:

```text
jq empty Obervability-Stack/grafana/dashboards/application/memflip-onboarding.json
```

All dashboard PromQL expressions returned `success` and at least one result after the error-ratio fallback:

```text
success	1	count(ALERTS{service="memflip",alertstate="firing"}) or vector(0)
success	1	max(probe_success{job="blackbox-http",app="memflip",component="backend"})
success	1	max(probe_success{job="blackbox-http",app="memflip",component="frontend"})
success	1	memflip:active_games
success	1	memflip:app_health
success	1	memflip:games_completed_rate_5m
success	1	memflip:http_error_ratio_5m or vector(0)
success	1	memflip:http_p95_latency_seconds
success	1	memflip:http_request_rate_5m
success	2	probe_duration_seconds{job="blackbox-http",app="memflip"}
success	1	up{job="memflip-backend"}
```

Grafana provisioning reload succeeded:

```text
{"message":"Dashboards config reloaded"}
```

The dashboard loaded through the Grafana API:

```text
title: MemFlip Onboarding
uid: memflip-onboarding
folderTitle: Application Monitoring
panels: 12
url: /d/memflip-onboarding/memflip-onboarding
```

Grafana search found the dashboard:

```text
MemFlip Onboarding	memflip-onboarding	Application Monitoring	/d/memflip-onboarding/memflip-onboarding
```

Operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
OpenSIS: healthy | primary=OpenSIS UI | latency=81ms | browser=http://localhost:8088
SwiftPay: healthy | primary=SwiftPay Frontend | latency=0ms | browser=http://localhost:8081
MemFlip: healthy | primary=MemFlip Frontend | latency=2ms | browser=http://localhost:8080
FoodPulse: healthy | primary=FoodPulse UI | latency=1ms | browser=http://localhost:8090
```

### Next Step

Complete this dashboard rollout with the SwiftPay money-flow dashboard.

## 2026-04-22 15:25 EDT - SwiftPay Grafana Money-Flow Dashboard

### Objective

Complete the app-specific Grafana dashboard rollout with SwiftPay.

SwiftPay was selected last because it is the flagship money-flow workload and already had the deepest alert coverage. The dashboard needed to focus on operationally important transaction signals:

- frontend and service probe health
- metrics scrape health for each SwiftPay microservice
- pending transactions
- pending amount
- completed transfers
- transaction queue depth
- transaction failure rate
- wallet failure rate
- wallet circuit breaker state
- firing alert count

### Commands Run

Checked repo state, SwiftPay recording rules, alert rules, scrape config, and existing dashboard inventory:

```bash
git status --short --branch
rg -n "swiftpay" Obervability-Stack/prometheus/recording_rules.yml Obervability-Stack/prometheus/alert_rules.yml Obervability-Stack/prometheus/prometheus.yml METRICS-STRATEGY.md
find Obervability-Stack/grafana/dashboards/application -maxdepth 1 -type f -print | sort
sed -n '52,78p' METRICS-STRATEGY.md
```

Validated available SwiftPay Prometheus expressions before designing the dashboard:

```bash
sed -n '40,62p' METRICS-STRATEGY.md
for expr in 'swiftpay:pending_transactions' 'swiftpay:pending_amount' 'swiftpay:transaction_queue_depth' 'swiftpay:completed_transfers_total' 'swiftpay:transaction_failure_rate_5m' 'swiftpay:wallet_failed_transfer_rate_5m' 'swiftpay:wallet_circuit_breaker_state' 'count(ALERTS{service="swiftpay",alertstate="firing"}) or vector(0)' 'up{job=~"swiftpay-.+"}' 'probe_success{job="blackbox-http",app="swiftpay"}' 'probe_duration_seconds{job="blackbox-http",app="swiftpay"}'; do encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$expr"); response=$(curl -fsS "http://localhost:9090/api/v1/query?query=$encoded"); query_status=$(printf '%s' "$response" | jq -r '.status'); result_count=$(printf '%s' "$response" | jq -r '.data.result | length'); printf '%s\t%s\t%s\n' "$query_status" "$result_count" "$expr"; done
curl -fsS 'http://localhost:9090/api/v1/query?query=probe_success%7Bjob%3D%22blackbox-http%22%2Capp%3D%22swiftpay%22%7D' | jq -r '.data.result[] | [.metric.component,.metric.instance,.value[1]] | @tsv'
curl -fsS 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D~%22swiftpay-.%2B%22%7D' | jq -r '.data.result[] | [.metric.job,.metric.instance,.value[1]] | @tsv'
```

Validated the new dashboard JSON and every dashboard PromQL expression:

```bash
jq empty Obervability-Stack/grafana/dashboards/application/swiftpay-money-flow.json
jq -r '.. | objects | select(has("expr")) | .expr' Obervability-Stack/grafana/dashboards/application/swiftpay-money-flow.json | sort -u | while IFS= read -r expr; do encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$expr"); response=$(curl -fsS "http://localhost:9090/api/v1/query?query=$encoded"); query_status=$(printf '%s' "$response" | jq -r '.status'); result_count=$(printf '%s' "$response" | jq -r '.data.result | length'); printf '%s\t%s\t%s\n' "$query_status" "$result_count" "$expr"; done
jq '{title,uid,panels: [.panels[] | {id,title,type,exprs: [.targets[]?.expr]}]}' Obervability-Stack/grafana/dashboards/application/swiftpay-money-flow.json | sed -n '1,280p'
git diff --check
```

Reloaded Grafana provisioning and verified the dashboard:

```bash
curl -fsS -u admin:admin -X POST http://localhost:3000/api/admin/provisioning/dashboards/reload
curl -fsS -u admin:admin http://localhost:3000/api/dashboards/uid/swiftpay-money-flow | jq '{title: .dashboard.title, uid: .dashboard.uid, folderTitle: .meta.folderTitle, panels: (.dashboard.panels|length), url: .meta.url}'
curl -fsS -u admin:admin 'http://localhost:3000/api/search?query=SwiftPay' | jq -r '.[] | [.title,.uid,.folderTitle,.url] | @tsv'
docker exec grafana sh -c 'tail -n 80 /var/log/grafana/grafana.log 2>/dev/null || tail -n 80 /var/lib/grafana/grafana.log 2>/dev/null' | rg -n "swiftpay|SwiftPay|failed|error|duplicate|Cannot read directory|failed to search"
```

Ran the operator check and captured timestamp/worktree state:

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
date '+%Y-%m-%d %H:%M %Z'
git status --short && git diff --stat
```

### What Changed

Added:

```text
Obervability-Stack/grafana/dashboards/application/swiftpay-money-flow.json
```

The dashboard is titled:

```text
SwiftPay Money Flow
```

It contains 13 panels:

- `All Probes`
- `All Scrapes`
- `Pending Transactions`
- `Pending Amount`
- `Wallet Circuit`
- `Firing Alerts`
- `SwiftPay Probe Latency`
- `Completed Transfers`
- `Pending Money Movement`
- `Transaction Queue Depth`
- `Failure Rates`
- `Service Metrics Scrapes`
- `Component Probes`

Updated:

```text
METRICS-STRATEGY.md
```

SwiftPay now records dashboard coverage as implemented. The app-specific dashboard rollout is now complete for:

- OpenSIS
- FoodPulse
- MemFlip
- SwiftPay

### Why We Did This

SwiftPay is the money-flow story. This dashboard gives an operator one place to answer the highest-value operational questions:

- Are all SwiftPay service health probes passing?
- Is Prometheus scraping all SwiftPay microservices?
- Are transactions stuck pending?
- Is money stuck in pending state?
- Is the transaction queue backing up?
- Are transaction or wallet failures appearing?
- Is the wallet circuit breaker open?
- Are alerts firing for SwiftPay?

The dashboard intentionally uses `swiftpay:*` recording rules where available so the panel contract stays stable when we later move the implementation into Kubernetes and ServiceMonitor resources.

### Problems Found And Fixes

#### 1. Failure-rate rules returned no data when there were no failures

Pre-dashboard validation showed:

```text
success	0	swiftpay:transaction_failure_rate_5m
success	0	swiftpay:wallet_failed_transfer_rate_5m
```

This is not a Prometheus syntax problem, but it is an operator experience problem. A healthy no-failure state should display as zero, not missing data.

Fix:

The dashboard uses zero fallbacks:

```text
swiftpay:transaction_failure_rate_5m or vector(0)
swiftpay:wallet_failed_transfer_rate_5m or vector(0)
```

#### 2. Probe and scrape label shapes were verified before panel design

SwiftPay blackbox components were verified:

```text
api-gateway	http://swiftpay-api-gateway:3000/health	1
auth-service	http://swiftpay-auth-service:3004/health	1
frontend	http://swiftpay-frontend/	1
notification-service	http://swiftpay-notification-service:3003/health	1
transaction-service	http://swiftpay-transaction-service:3002/health	1
wallet-service	http://swiftpay-wallet-service:3001/health	1
```

SwiftPay scrape targets were verified:

```text
swiftpay-api-gateway	swiftpay-api-gateway:3000	1
swiftpay-auth-service	swiftpay-auth-service:3004	1
swiftpay-notification-service	swiftpay-notification-service:3003	1
swiftpay-transaction-service	swiftpay-transaction-service:3002	1
swiftpay-wallet-service	swiftpay-wallet-service:3001	1
```

### Validation

Dashboard JSON passed:

```text
jq empty Obervability-Stack/grafana/dashboards/application/swiftpay-money-flow.json
```

All dashboard PromQL expressions returned `success` and at least one result:

```text
success	1	count(ALERTS{service="swiftpay",alertstate="firing"}) or vector(0)
success	1	min(probe_success{job="blackbox-http",app="swiftpay"})
success	1	min(up{job=~"swiftpay-.+"})
success	6	probe_duration_seconds{job="blackbox-http",app="swiftpay"}
success	6	probe_success{job="blackbox-http",app="swiftpay"}
success	1	swiftpay:completed_transfers_total
success	1	swiftpay:pending_amount
success	1	swiftpay:pending_transactions
success	1	swiftpay:transaction_failure_rate_5m or vector(0)
success	1	swiftpay:transaction_queue_depth
success	1	swiftpay:wallet_circuit_breaker_state
success	1	swiftpay:wallet_failed_transfer_rate_5m or vector(0)
success	5	up{job=~"swiftpay-.+"}
```

Grafana provisioning reload succeeded:

```text
{"message":"Dashboards config reloaded"}
```

The dashboard loaded through the Grafana API:

```text
title: SwiftPay Money Flow
uid: swiftpay-money-flow
folderTitle: Application Monitoring
panels: 13
url: /d/swiftpay-money-flow/swiftpay-money-flow
```

Grafana search found the dashboard:

```text
SwiftPay Money Flow	swiftpay-money-flow	Application Monitoring	/d/swiftpay-money-flow/swiftpay-money-flow
```

Operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
OpenSIS: healthy | primary=OpenSIS UI | latency=132ms | browser=http://localhost:8088
SwiftPay: healthy | primary=SwiftPay Frontend | latency=1ms | browser=http://localhost:8081
MemFlip: healthy | primary=MemFlip Frontend | latency=6ms | browser=http://localhost:8080
FoodPulse: healthy | primary=FoodPulse UI | latency=3ms | browser=http://localhost:8090
```

### Next Step

The app-specific Grafana dashboard rollout is complete. The next production-maturity step is to decide between:

- SLO burn-rate alerting after enough stable historical data exists.
- Kubernetes preparation by mapping the Prometheus scrape jobs and dashboards to k3s-friendly `ServiceMonitor` and Grafana provisioning patterns.
