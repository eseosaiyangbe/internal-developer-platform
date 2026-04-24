# Port Allocation Matrix

This document is the workspace-level source of truth for host port allocation across:

- `Obervability-Stack`
- `OpenSIS`
- `SwiftPay`
- `MemFlip`
- `FoodPulse`

It exists to prevent silent port collisions as multiple apps are run together on the same Mac or Linux workstation and to keep local Compose behavior aligned with the later Kubernetes separation of concerns.

## Allocation Policy

Use these rules going forward:

1. Keep service-internal ports on their platform defaults whenever possible.
2. Treat host-exposed ports as a shared workspace resource and assign them intentionally.
3. Reserve the common monitoring ports for the central `Obervability-Stack`.
4. Avoid publishing database ports to the host unless there is a real operator need.
5. Prefer loopback-only exposure (`127.0.0.1`) for app UIs and admin surfaces that do not need LAN access.
6. Use environment-variable overrides for host ports so Mac Intel, Apple Silicon, and Linux operators can recover from local conflicts without editing Compose files.

## Reserved Ranges For Future Apps

New apps joining the workspace should allocate from these host-port bands first.

| Range | Intended Use |
|---|---|
| `80-99` | explicit local ingress simulation only |
| `3000-3199` | application APIs, gateways, and internal operator surfaces |
| `4000-4199` | shared control-plane and workspace-level UIs |
| `5400-5499` | PostgreSQL host listeners and SQL proxies |
| `6300-6399` | Redis host listeners and Redis proxies |
| `8080-8099` | browser-facing application frontends |
| `9000-9199` | monitoring, logging, and exporter surfaces |

When adding a new app:

1. reserve host ports from the correct band
2. parameterize them with env vars
3. document them in this matrix as part of onboarding

## Current Standard

These are the recommended workspace host ports when all major apps coexist locally.

| Area | Service | Host Port | Internal Port | Repo |
|---|---|---:|---:|---|
| Control plane | DevOps Monitor UI | `4000` | `3000` | `Obervability-Stack` |
| Control plane DB | Observability PostgreSQL | `5434` | `5432` | `Obervability-Stack` |
| Monitoring | Grafana | `3000` | `3000` | `Obervability-Stack` |
| Monitoring | Prometheus | `9090` | `9090` | `Obervability-Stack` |
| Monitoring | Alertmanager | `9093` | `9093` | `Obervability-Stack` |
| Logging | Loki | `3100` | `3100` | `Obervability-Stack` |
| Logging | Promtail | `9080` | `9080` | `Obervability-Stack` |
| Monitoring | Node Exporter | `9100` | `9100` | `Obervability-Stack` |
| Monitoring | Blackbox Exporter | `9115` | `9115` | `Obervability-Stack` |
| Monitoring | cAdvisor | `8082` | `8080` | `Obervability-Stack` |
| OpenSIS | UI | `127.0.0.1:8088` | `80` | `OpenSIS` |
| OpenSIS | Vault | `127.0.0.1:8200` | `8200` | `OpenSIS` |
| SwiftPay | Frontend | `8081` | `80` | `SwiftPay` |
| SwiftPay | API Gateway | `3007` | `3000` | `SwiftPay` |
| SwiftPay | Auth Service | `3004` | `3004` | `SwiftPay` |
| SwiftPay | Wallet Service | `3001` | `3001` | `SwiftPay` |
| SwiftPay | Transaction Service | `3008` | `3002` | `SwiftPay` |
| SwiftPay | Notification Service | `3003` | `3003` | `SwiftPay` |
| SwiftPay | PostgreSQL | `5432` | `5432` | `SwiftPay` |
| SwiftPay | Redis | `6379` | `6379` | `SwiftPay` |
| SwiftPay | RabbitMQ AMQP | `5672` | `5672` | `SwiftPay` |
| SwiftPay | RabbitMQ UI | `15672` | `15672` | `SwiftPay` |
| MemFlip | Frontend | `8080` | `80` | `MemFlip` |
| MemFlip | Backend | `3101` | `3001` | `MemFlip` |
| FoodPulse | UI | `127.0.0.1:8090` | `80` | `FoodPulse` |
| FoodPulse | API | `127.0.0.1:3102` | `4567` | `FoodPulse` |
| FoodPulse | PostgreSQL RW HAProxy | `127.0.0.1:5442` | `5432` | `FoodPulse` |
| FoodPulse | PostgreSQL RO HAProxy | `127.0.0.1:5443` | `5433` | `FoodPulse` |
| FoodPulse | Redis HAProxy | `127.0.0.1:6380` | `6379` | `FoodPulse` |
| FoodPulse | Redis Sentinel 1 | `127.0.0.1:26380` | `26379` | `FoodPulse` |

## Live Host Bindings Observed

This reflects the currently running workspace state at the time of this update.

| Host Port | Bound Service |
|---:|---|
| `3000` | `grafana` |
| `3001` | `swiftpay-wallet-service-1` |
| `3003` | `swiftpay-notification-service-1` |
| `3004` | `swiftpay-auth-service-1` |
| `3007` | `swiftpay-api-gateway-1` |
| `3008` | `swiftpay-transaction-service-1` |
| `3100` | `loki` |
| `3101` | `humor-game-backend` |
| `3102` | `foodpulse-api` |
| `4000` | `devops-monitor-ui` |
| `5432` | `swiftpay-postgres-1` |
| `5434` | `observability-postgres` |
| `5442` | `foodpulse-pg-haproxy` read-write listener |
| `5443` | `foodpulse-pg-haproxy` read-only listener |
| `5672` | `swiftpay-rabbitmq-1` |
| `6379` | `swiftpay-redis-1` |
| `6380` | `foodpulse-redis-haproxy` |
| `8080` | `humor-game-frontend` |
| `8081` | `swiftpay-frontend-1` |
| `8082` | `cadvisor` |
| `8088` | `opensis-ui` |
| `8090` | `foodpulse-ui` |
| `8200` | `vault` |
| `9080` | `promtail` |
| `9090` | `prometheus` |
| `9093` | `alertmanager` |
| `9100` | `node-exporter` |
| `9115` | `blackbox-exporter` |
| `15672` | `swiftpay-rabbitmq-1` |
| `26380` | `foodpulse-redis-sentinel01` |

## Declared Compose Exposure By Repo

### `Obervability-Stack`

Primary stack:

- `4000 -> 3000` `devops-monitor-ui`
- `5434 -> 5432` `postgres`
- `3000 -> 3000` `grafana`
- `9090 -> 9090` `prometheus`
- `9093 -> 9093` `alertmanager`
- `3100 -> 3100` `loki`
- `9080 -> 9080` `promtail`
- `9100 -> 9100` `node-exporter`
- `9115 -> 9115` `blackbox-exporter`
- `8082 -> 8080` `cadvisor`

Dev stack mirrors most of the same ports and should not be run alongside the primary observability stack on the same host.

### `OpenSIS`

- `127.0.0.1:8088 -> 80` `opensis-ui`
- `127.0.0.1:8200 -> 8200` `vault`

Optional edge profile:

- `127.0.0.1:80 -> 80` `traefik`

### `SwiftPay`

Core application:

- `5432 -> 5432` `postgres`
- `6379 -> 6379` `redis`
- `5672 -> 5672` `rabbitmq`
- `15672 -> 15672` `rabbitmq management`
- `3004 -> 3004` `auth-service`
- `3001 -> 3001` `wallet-service`
- `3008 -> 3002` `transaction-service`
- `3003 -> 3003` `notification-service`
- `3007 -> 3000` `api-gateway`
- `8081 -> 80` `frontend`

Optional monitoring and logging profiles:

- `9090 -> 9090` `prometheus`
- `3006 -> 3000` `grafana`
- `9093 -> 9093` `alertmanager`
- `3100 -> 3100` `loki`

### `MemFlip`

Base stack:

- `${BACKEND_HOST_PORT:-3101} -> 3001` `backend`
- `${FRONTEND_HOST_PORT:-8080} -> 80` `frontend`

Override file:

- `${MEMFLIP_PROXY_HOST_PORT:-8083} -> 80` `reverse-proxy`

The override is now env-driven and defaults to `8083`, which avoids the central observability Grafana port.

### `FoodPulse`

- `127.0.0.1:${FOODPULSE_UI_HOST_PORT:-8090} -> 80` `foodpulse-ui`
- `127.0.0.1:${FOODPULSE_API_HOST_PORT:-3102} -> 4567` `foodpulse-api`
- `127.0.0.1:${FOODPULSE_SENTINEL_HOST_PORT:-26380} -> 26379` `redis-sentinel-1`
- `127.0.0.1:${FOODPULSE_PG_RW_HOST_PORT:-5442} -> 5432` `pg-haproxy`
- `127.0.0.1:${FOODPULSE_PG_RO_HOST_PORT:-5443} -> 5433` `pg-haproxy`
- `127.0.0.1:${FOODPULSE_REDIS_HOST_PORT:-6380} -> 6379` `redis-haproxy`

## Confirmed Collision Risks

### 1. `SwiftPay` PostgreSQL vs observability PostgreSQL

- `SwiftPay` already owns host `5432`.
- The observability stack originally attempted to publish PostgreSQL on `5432`.
- The observability stack now uses `5434` to avoid collision.

### 2. Shared monitoring ports must belong to the central observability stack

If `SwiftPay` monitoring/logging profiles are started together with `Obervability-Stack`, these host ports will collide:

- `9090`
- `9093`
- `3100`

`SwiftPay` Grafana uses `3006`, so it does not collide with the central Grafana on `3000`.

Recommendation:

- Do not run `SwiftPay` monitoring or logging profiles on the same host when the central observability stack is active.
- Treat the central observability stack as the only owner of shared monitoring/logging host ports.

### 3. Optional local reverse proxies remain a recurring risk

Historically `MemFlip/docker-compose.override.yml` published:

- `3000 -> 80`

That collided with the central observability Grafana on `3000`.

The workspace default is now:

- `${MEMFLIP_PROXY_HOST_PORT:-8083} -> 80`

Recommendation:

- Reserve `3000` for Grafana.
- Keep optional reverse proxies env-driven and outside the shared monitoring range.

### 4. `OpenSIS` edge mode uses host port `80`

`OpenSIS` Traefik edge profile publishes:

- `127.0.0.1:80 -> 80`

This is not a conflict right now, but it is a high-risk shared port because host `80` is commonly used by:

- local reverse proxies
- developer web servers
- other ingress simulations

Recommendation:

- Keep `OpenSIS` edge profile optional.
- Do not treat host `80` as part of the standard multi-repo local baseline.

## Standing Workspace Rules

These are not open issues. They are the operating rules we should keep as more apps join the workspace:

1. Keep database host exposure minimal:
   - `SwiftPay` on `5432`
   - `Obervability-Stack` on `5434`
   - `FoodPulse` on `5442/5443`
2. Prefer loopback-only publication for app UIs and admin surfaces unless remote access is explicitly needed.
3. Require every future app onboarding to reserve ports from the documented workspace ranges.

## Operator Guidance

When a new repo is added to this workspace:

1. Check this matrix before publishing any host port.
2. Prefer a repo-specific range instead of reusing common defaults blindly.
3. If the service is only needed by sibling containers, do not publish it to the host.
4. If a default port must change, change only the host side, not the service-internal port, unless there is a hard technical reason.

## Evidence Sources

This matrix was built from:

- live `docker ps` host bindings
- declared host `ports:` mappings in each repo Compose file
- direct validation of the current `5432` conflict source on the host
