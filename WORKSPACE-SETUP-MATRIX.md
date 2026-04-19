# Workspace Setup Matrix

## Purpose

This file is the normalization contract for local setup.

It answers, for each repo:

- how to start it locally
- what env file or env contract exists
- what URL to open
- what health endpoint to check
- what `observability-net` alias the control plane expects

## Setup Matrix

| Repo | Primary Start Command | Optional Helper | Env Contract | Main Local URL | Health Check | `observability-net` Alias / Aliases | Kubernetes Readiness Note | Notes |
|---|---|---|---|---|---|---|---|---|
| `Obervability-Stack` | `docker compose up -d` | `./devops-monitor.sh start` | `env.example`, `docker-compose.env.example`, `ui-next/env.example` | `http://localhost:4000` | `curl -fsS http://localhost:4000/` | n/a, this repo owns the network too | App inventory should drift away from container-specific assumptions over time | Control plane repo |
| `SwiftPay` | `docker compose up -d` | `./scripts/validate.sh` after startup | `.env.example` | `http://localhost:8081` | `curl -fsS http://localhost:3007/health` | `swiftpay-frontend`, `swiftpay-api-gateway`, `swiftpay-auth-service`, `swiftpay-wallet-service`, `swiftpay-transaction-service`, `swiftpay-notification-service` | Strongest candidate for early Service, Deployment, and probe mapping | Best flagship workload |
| `OpenSIS` | `./scripts/compose-start.sh --build-local` on Apple Silicon, otherwise `./scripts/compose-start.sh` | `docker compose up -d` | `.env.example` should be used at repo root | `http://localhost:8088` | `curl -I http://localhost:8088` | `opensis-ui` | Already has the strongest native Kubernetes and GitOps posture | Includes Vault bootstrap and secret rendering; arm64 operators should prefer the local build path |
| `FoodPulse` | `cp .env.example .env && ./scripts/start.sh` | `./scripts/cluster-status.sh` after startup | `.env.example` should be used at repo root | `http://localhost:8090` | `curl -I http://localhost:8090` | `foodpulse-ui` | Good lab for StatefulSet-era concerns, with a cleaner UI/API split for future Services and probes | Workspace-owned React/Node app with observability delegated to `Obervability-Stack` |
| `MemFlip` | `cp .env.example .env && docker compose up -d` | none yet | `.env.example` at repo root, with deeper reference in `env/env.example` | `http://localhost:8080` | `curl -fsS http://localhost:8080/api/health` | `memflip-frontend`, `memflip-backend` | Frontend and backend are now expressed through a cleaner local service boundary that maps better to future Service and probe design | Lightweight onboarding app with a clearer local browser path |

## Alias Verification Against Control Plane

The following aliases match the monitored app inventory in:

`Obervability-Stack/ui-next/lib/monitored-apps.ts`

| App ID | Expected Alias | Repo Status |
|---|---|---|
| `opensis` | `opensis-ui` | matches `OpenSIS/docker-compose.yaml` |
| `swiftpay` | `swiftpay-*` service aliases | matches `SwiftPay/docker-compose.yml` |
| `memflip` | `memflip-frontend`, `memflip-backend` | matches `MemFlip/docker-compose.yml` |
| `foodpulse` | `foodpulse-ui` | matches `FoodPulse/docker-compose.yml` |

## Known Gaps

### `OpenSIS`

- no committed `.env.example` existed before Phase 2 normalization
- Apple Silicon operators should prefer `./scripts/compose-start.sh --build-local` because the published `opensis-ui:dev` image is not multi-arch

### `FoodPulse`

- no committed `.env.example` existed before Phase 2 normalization
- no top-level `README.md` existed before Phase 2 normalization
- published host ports and generic container names are now normalized so the lab can coexist with the control plane

### `MemFlip`

- frontend is now published locally at `http://localhost:8080`
- backend health is still directly available on `http://localhost:3101/health`, but the preferred operator check is the user-facing proxied path
- `frontend/dist` may exist locally after frontend builds, but it is ignored and should be treated as generated output rather than repo source of truth

### `Obervability-Stack`

- root README and docs index now agree on the primary local ports
- deeper control plane docs still need periodic drift checks as the repo evolves

## Migration Lens

During normalization, favor changes that reduce future Kubernetes friction:

- document env inputs before inventing new helper scripts
- prefer probe-ready HTTP endpoints over container-local checks
- treat Docker aliases as temporary local equivalents of Kubernetes Services
- keep generated frontend assets out of the architecture contract unless the repo truly depends on checked-in build output

## Recommended Startup Order For Workspace Work

When validating the full platform locally, use this order:

1. create the shared Docker network if needed
2. start `Obervability-Stack`
3. start `SwiftPay`
4. start `OpenSIS`
5. start `FoodPulse`
6. start `MemFlip`
7. verify probes, logs, and health from the control plane

Why this order:

- the control plane should be available before app verification starts
- `SwiftPay` is the richest first app for validating service-level observability
- `OpenSIS` and `FoodPulse` add platform and resilience complexity afterward
- `MemFlip` is the lightest app and easiest to add late
