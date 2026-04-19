# DevOps Easy Learning Workspace Architecture

## Purpose

This document explains how the workspace fits together as one platform.

The goal is not to run five unrelated repos side by side.
The goal is to operate a mixed-architecture application lab from one shared control plane.

## Workspace Roles

### `Obervability-Stack`

Role:

- control plane
- shared observability hub
- app inventory and operator UI

Owns:

- Prometheus
- Grafana
- Loki
- Alertmanager
- blackbox probing
- Next.js operator dashboard

Why it matters:

- this is the repo that turns the workspace into a platform instead of a pile of apps

### `SwiftPay`

Role:

- flagship microservices application

Architecture style:

- Node.js microservices
- PostgreSQL
- Redis
- RabbitMQ
- React frontend

Why it matters:

- best workload for service-level health, logs, metrics, and business telemetry

### `OpenSIS`

Role:

- legacy monolith with a serious platform wrapper

Architecture style:

- PHP/Apache app
- MariaDB
- Vault-based secret delivery
- Kubernetes and GitOps model

Why it matters:

- best workload for showing how to operate and observe a legacy application inside a modern platform model

### `FoodPulse`

Role:

- resilience and failover lab

Architecture style:

- Yelb-based app stack
- Redis master/replica/Sentinel
- Postgres primary/replicas
- HAProxy routing
- built-in monitoring stack

Why it matters:

- best workload for failover drills and infrastructure behavior demonstrations

### `MemFlip`

Role:

- lightweight onboarding and demo app

Architecture style:

- Node backend
- static frontend
- PostgreSQL
- Redis

Why it matters:

- easiest app to onboard and use as a simple reference pattern

## Shared Platform Model

The platform model has three layers.

### Layer 1: Workloads

The application repos:

- `SwiftPay`
- `OpenSIS`
- `FoodPulse`
- `MemFlip`

### Layer 2: Shared Runtime Integration

The common runtime integration is the external Docker network:

```text
observability-net
```

This network lets the control plane probe and observe app containers by stable internal aliases.

### Layer 3: Control Plane

`Obervability-Stack` consumes the shared aliases and maps them into:

- app metadata
- health targets
- log queries
- uptime probes
- latency probes
- business metrics where available

## Current App Alias Model

These are the runtime aliases that matter most to the shared platform.

| App | Alias / Aliases | Purpose |
|---|---|---|
| `OpenSIS` | `opensis-ui` | primary UI probe target |
| `SwiftPay` | `swiftpay-frontend`, `swiftpay-api-gateway`, `swiftpay-auth-service`, `swiftpay-wallet-service`, `swiftpay-transaction-service`, `swiftpay-notification-service` | service-level observability |
| `MemFlip` | `memflip-frontend`, `memflip-backend` | frontend and backend health |
| `FoodPulse` | `foodpulse-ui` | primary UI probe target |

## Control Plane Contract

For an app to participate cleanly in this workspace platform, it should have:

1. a stable `observability-net` alias
2. a documented local startup command
3. at least one health endpoint or HTTP probe target
4. a documented local browser URL if user-facing
5. a log and metrics story, even if minimal

## Architecture Pattern By Repo

This workspace is valuable because it compares different architecture styles under one operator model.

| Repo | Style | Main Platform Lesson |
|---|---|---|
| `SwiftPay` | microservices | service decomposition, queue-backed workflows, business telemetry |
| `OpenSIS` | legacy monolith | secret delivery, GitOps, platform wrapping, operability |
| `FoodPulse` | HA infrastructure lab | failover behavior, data-plane routing, resilience drills |
| `MemFlip` | simple web app | easy onboarding, lightweight app monitoring |

## Recommended Operator Mental Model

Think of the workspace like this:

```text
Operator -> Obervability-Stack -> App inventory -> Workload health / logs / metrics / drills
```

And think of the workloads like this:

```text
SwiftPay  = flagship app
OpenSIS   = legacy platform case
FoodPulse = resilience lab
MemFlip   = onboarding reference
```

## Near-Term Architecture Priorities

### 1. Normalize startup contracts

Every app should have:

- a clear startup command
- an env contract
- a health contract

### 2. Harden the control plane

The app inventory and docs in `Obervability-Stack` need to be fully trustworthy.

### 3. Keep app roles distinct

Do not force every app into the same story.
Use each workload for the thing it best demonstrates.
