# DevOps Easy Learning Demo Walkthrough

## Purpose

This walkthrough is the presenter script for the workspace.

Use it when you want to show the project to a reviewer, teammate, student, recruiter, or future contributor without wandering through five repos manually.

## Demo Promise

By the end of the walkthrough, the audience should understand:

- what each workload teaches
- how the control plane sees the workspace
- how operators move from dashboard signal to live audit
- how incident drills are captured and recovered
- why the local Compose model is being shaped with Kubernetes in mind

## Pre-Demo Checklist

Run this first:

```bash
git status --short
./Obervability-Stack/scripts/devops-monitor.sh operator
```

Expected result:

```text
Checks passed: 26/26
Inventory validation passed.
All monitored apps are currently healthy.
```

If the operator check fails, do not start the demo yet. Use the standard health workflow first:

```bash
./Obervability-Stack/scripts/devops-monitor.sh health
./Obervability-Stack/scripts/devops-monitor.sh inventory
```

## Story Arc

### 1. Start With The Platform

Open:

```text
http://localhost:4000
```

Say:

```text
This is not a dashboard pasted onto one app. It is a control plane for a mixed-architecture workspace.
The goal is to teach how different apps become operable through one shared model.
```

Show:

- the app inventory
- health state
- app categories
- primary app URLs
- clickable managed-app cards on the services page
- the app comparison view at `http://localhost:4000/services/compare`
- app-specific operator pages for latency, uptime, alerts, recent logs, and guidance
- clickable operator runbook and incident drill handoff buttons on each app page
- operator guidance

### 2. Explain The Four Workloads

Use this quick framing:

| App | Demo Role | What To Say |
|---|---|---|
| SwiftPay | Microservices | Money movement, async workers, service health, business telemetry |
| OpenSIS | Legacy platform app | Legacy PHP app wrapped with Vault, database checks, and Kubernetes thinking |
| FoodPulse | Resilience lab | Redis/Postgres/HAProxy topology and failover behavior |
| MemFlip | Onboarding app | The simplest app, useful for showing the minimum integration pattern |

### 3. Show The Operator First Check

Run:

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
```

Say:

```text
Every troubleshooting story starts here. First we prove the control plane is trustworthy, then we validate inventory, then we look at app health.
```

Point out:

- control-plane smoke check
- inventory validation
- workspace app snapshot
- next operator paths

### 4. Show One Deep App Audit

Pick one based on the audience.

For microservices:

```bash
./Obervability-Stack/scripts/devops-monitor.sh swiftpay-live
```

For legacy/platform wrapping:

```bash
./Obervability-Stack/scripts/devops-monitor.sh opensis-live
```

For failover/resilience:

```bash
./Obervability-Stack/scripts/devops-monitor.sh foodpulse-live
```

For simple onboarding:

```bash
./Obervability-Stack/scripts/devops-monitor.sh memflip-live
```

Say:

```text
The generic dashboard tells us where to look. The live audit proves the app-specific behavior.
```

### 5. Show The Incident Drill Catalog

Open:

```text
Obervability-Stack/docs/INCIDENT_DRILLS.md
```

Show the executed drill log:

- MemFlip backend down
- SwiftPay transaction worker down
- OpenSIS Vault unavailable
- FoodPulse Redis failover
- Control plane probe drift

Say:

```text
These are not hypothetical runbooks. We actually broke the lab, recovered it, and documented what happened.
```

### 6. Show The Journey Runbook

Open:

```text
JOURNEY-RUNBOOK.md
```

Jump to one executed drill section.

Say:

```text
This runbook records every command, what failed, why it failed, and what fixed it.
That is the teaching asset. It shows the thinking, not just the final state.
```

### 7. Show One App

Use the dashboard links or open directly:

```text
SwiftPay:  http://localhost:8081
OpenSIS:   http://localhost:8088
FoodPulse: http://localhost:8090
MemFlip:   http://localhost:8080
```

Recommended Phase 6 flow:

1. Open the control plane first.
2. Open the Services page and explain that it is now a simple managed-app launch board.
3. Open `Compare Apps` to explain why the workspace has a microservices app, legacy platform app, HA lab, and onboarding app.
4. Click the FoodPulse label to show its operator page, then open the live app from there.
5. Use the app page's `Open operator runbook` button to show the Markdown handoff.
6. Use `View incident drills` to connect the app page to the executed drill catalog.
7. Open SwiftPay to show the flagship microservices app and its operator page.
8. Open OpenSIS to explain legacy modernization and its Vault/platform signals.
9. Open MemFlip as the lightweight onboarding reference.

### 8. Close With Kubernetes Direction

Say:

```text
Compose is the proving ground. Kubernetes is the destination.
The local choices are intentionally Kubernetes-shaped: health endpoints, stable service names, env contracts, and operator runbooks.
```

Point to:

- [WORKSPACE-ARCHITECTURE.md](WORKSPACE-ARCHITECTURE.md)
- [WORKSPACE-SETUP-MATRIX.md](WORKSPACE-SETUP-MATRIX.md)
- app-specific Kubernetes docs where available

## Optional Live Drill

Use this only when you have time and the baseline is healthy.

The safest live drill is the control-plane probe drift drill:

```bash
cd Obervability-Stack
docker compose stop blackbox-exporter
cd ..
./Obervability-Stack/scripts/devops-monitor.sh operator
curl -fsSI http://localhost:8080/api/health
curl -fsSI http://localhost:8081
curl -fsSI http://localhost:8088
curl -fsSI http://localhost:8090
cd Obervability-Stack
docker compose start blackbox-exporter
cd ..
./Obervability-Stack/scripts/devops-monitor.sh operator
```

Teaching point:

```text
When every app probe fails at once but direct app URLs work, suspect the shared probe layer before blaming every workload.
```

## Five-Minute Version

If you only have five minutes:

1. Open `http://localhost:4000`.
2. Run `./Obervability-Stack/scripts/devops-monitor.sh operator`.
3. Explain the four workload roles.
4. Show `Obervability-Stack/docs/INCIDENT_DRILLS.md`.
5. Open `JOURNEY-RUNBOOK.md` to one drill.
6. Close with the Kubernetes-ready direction.

## What Not To Do During A Demo

- Do not start with individual app repos before explaining the control plane.
- Do not run a destructive drill without a clean baseline.
- Do not skip the direct app probe when explaining monitoring drift.
- Do not claim Kubernetes is complete yet; the project is intentionally building toward it.
- Do not hide failures. The failures are the point of the learning journey.
