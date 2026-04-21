# DevOps Easy Learning

DevOps Easy Learning is a hands-on operations lab that turns several different application styles into one teachable platform.

The goal is not to collect random repos. The goal is to show how a DevOps engineer can onboard, observe, troubleshoot, and recover mixed workloads from a shared control plane.

## What This Workspace Contains

| Area | Role | Local URL |
|---|---|---|
| `Obervability-Stack` | Shared observability and operator control plane | `http://localhost:4000` |
| `SwiftPay` | Microservices money-flow app | `http://localhost:8081` |
| `OpenSIS` | Legacy monolith wrapped with modern platform practices | `http://localhost:8088` |
| `FoodPulse` | Resilience and failover lab | `http://localhost:8090` |
| `MemFlip` | Lightweight onboarding/demo app | `http://localhost:8080` |

## Platform Story

This project demonstrates five practical DevOps skills:

- onboarding existing applications into a common operations model
- building a control plane that knows about app health, probes, logs, and runbooks
- running real incident drills instead of only writing theoretical docs
- documenting every command and recovery lesson in a journey runbook
- preparing local Docker Compose workflows for a future Kubernetes migration

## Quick Start

Start with the workstation bootstrap guide if this is a fresh machine:

```bash
./scripts/bootstrap-macos-userland.sh
```

Linux users can use:

```bash
./scripts/bootstrap-linux-userland.sh
```

Then follow the workspace startup order:

1. Start `Obervability-Stack`.
2. Start `SwiftPay`.
3. Start `OpenSIS`.
4. Start `FoodPulse`.
5. Start `MemFlip`.
6. Run the operator check.

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
```

The target healthy result is:

```text
Control plane smoke check passed
Inventory validation passed
All monitored apps are currently healthy
```

## Demo Path

Use the guided walkthrough when presenting or practicing:

- [DEMO-WALKTHROUGH.md](DEMO-WALKTHROUGH.md)

The short version:

1. Open the Demo Center at `http://localhost:4000/demo`.
2. Confirm the live demo readiness state.
3. Open the managed app comparison view.
4. Run one app-specific live audit.
5. Show one recorded incident drill.
6. Explain how the same pattern maps to Kubernetes.

## Operator Entry Points

Run these commands from the repo root unless a doc says otherwise:

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
./Obervability-Stack/scripts/devops-monitor.sh swiftpay-live
./Obervability-Stack/scripts/devops-monitor.sh opensis-live
./Obervability-Stack/scripts/devops-monitor.sh foodpulse-live
./Obervability-Stack/scripts/devops-monitor.sh memflip-live
```

## Incident Drills Already Executed

The project now includes executed and recovered drills for:

- MemFlip backend down
- SwiftPay transaction worker down
- OpenSIS Vault unavailable
- FoodPulse Redis failover
- Control plane probe drift

Read the drill catalog here:

- [Obervability-Stack/docs/INCIDENT_DRILLS.md](Obervability-Stack/docs/INCIDENT_DRILLS.md)

Read the full command-by-command journey here:

- [JOURNEY-RUNBOOK.md](JOURNEY-RUNBOOK.md)

Read operational incident investigations here:

- [INCIDENT-RESPONSE.md](INCIDENT-RESPONSE.md)

## Key Docs

| Doc | Purpose |
|---|---|
| [PROJECT-ROADMAP.md](PROJECT-ROADMAP.md) | Phase plan and current project status |
| [WORKSPACE-ARCHITECTURE.md](WORKSPACE-ARCHITECTURE.md) | How the repos fit together as one platform |
| [WORKSPACE-SETUP-MATRIX.md](WORKSPACE-SETUP-MATRIX.md) | Startup commands, ports, health checks, and aliases |
| [WORKSTATION-BOOTSTRAP.md](WORKSTATION-BOOTSTRAP.md) | macOS/Linux tool installation guide |
| [INCIDENT-RESPONSE.md](INCIDENT-RESPONSE.md) | Dedicated incident response log for alerts, outages, fixes, and follow-ups |
| [Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md](Obervability-Stack/docs/OPERATOR_HEALTH_WORKFLOW.md) | Standard first-response workflow |

## Current Phase

The project is in Phase 6: UX and demo polish.

The engineering foundation is now real. The next job is making the control plane, docs, and demo flow feel polished enough for teaching, portfolio review, and future Kubernetes migration.
