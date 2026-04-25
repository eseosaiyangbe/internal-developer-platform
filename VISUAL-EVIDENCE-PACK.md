# Visual Evidence Pack

## Purpose

This document defines the screenshot and diagram pack for Phase 7.

Its job is to make the workspace understandable to a reviewer without needing:

- a live walkthrough
- verbal patch notes
- deep repo archaeology

## Audience

This pack is intended for:

- hiring managers
- engineering interview panels
- collaborators
- students following the project

## Capture Principles

1. Every screenshot must prove something operationally meaningful.
2. Prefer live, healthy platform states unless the screenshot is explicitly about incidents.
3. Avoid decorative captures that do not strengthen the platform story.
4. Keep the pack small enough to scan quickly, but strong enough to show depth.
5. Architecture diagrams should explain flow and responsibility, not just component names.

## Core Screenshot Set

### 1. Presenter Landing Page

URL:

```text
http://localhost:4000
```

What it proves:

- the workspace has a real front door
- the project is framed as one control plane, not five unrelated apps

### 2. Simplified Dashboard

URL:

```text
http://localhost:4000/dashboard
```

What it proves:

- the control plane surfaces platform state cleanly
- the UI is oriented toward operators, not generic admin clutter

### 3. Services Page

URL:

```text
http://localhost:4000/services
```

What it proves:

- the managed app inventory is real
- app onboarding is visible and structured

### 4. App Comparison View

URL:

```text
http://localhost:4000/services/compare
```

What it proves:

- the four workload roles are intentional
- the platform story explains why these apps coexist

### 5. One App Detail Page

Recommended target:

```text
http://localhost:4000/apps/opensis
```

What it proves:

- the control plane can hand off from high-level inventory to app-specific operator context
- probes, logs, alerts, and guidance are connected

Alternative captures:

- `SwiftPay` for microservices
- `FoodPulse` for resilience
- `MemFlip` for onboarding simplicity

### 6. Alerts Page

URL:

```text
http://localhost:4000/alerts
```

What it proves:

- the platform has real alerting
- the UI reflects active operational state instead of static mock data

### 7. Notifications / Resolved History

URL:

```text
http://localhost:4000/notifications
```

What it proves:

- the project captures alert lifecycle, not only current failures

### 8. Demo Center

URL:

```text
http://localhost:4000/demo
```

What it proves:

- the project can be presented intentionally
- demo readiness is treated as a repeatable workflow

### 9. One Live App UI

Recommended priority:

1. `SwiftPay`
2. `OpenSIS`
3. `FoodPulse`
4. `MemFlip`

What it proves:

- the platform manages real applications, not only observability infrastructure

### 10. Incident Drill Evidence

Recommended targets:

- [Obervability-Stack/docs/INCIDENT_DRILLS.md](Obervability-Stack/docs/INCIDENT_DRILLS.md)
- [INCIDENT-RESPONSE.md](INCIDENT-RESPONSE.md)

What it proves:

- the repo contains real break/fix evidence
- incident handling is part of the project identity

## Core Diagram Set

### 1. Platform System Diagram

Source:

- [WORKSPACE-ARCHITECTURE.md](WORKSPACE-ARCHITECTURE.md)

What it proves:

- the control plane, observability backends, and workloads fit together coherently

### 2. Workload-To-Control-Plane Mapping

Source:

- [WORKSPACE-ARCHITECTURE.md](WORKSPACE-ARCHITECTURE.md)

What it proves:

- each app contributes a different operational lesson

### 3. Kubernetes Migration Direction

Source:

- [KUBERNETES-MIGRATION-PLAN.md](KUBERNETES-MIGRATION-PLAN.md)

What it proves:

- the project has a phased path beyond local Compose

## Capture Order

Recommended order when building the visual pack:

1. run operator baseline checks
2. capture landing page
3. capture dashboard and services pages
4. capture comparison view
5. capture one app detail page
6. capture alerts and notifications
7. capture Demo Center
8. capture one live app UI
9. capture incident evidence
10. export or screenshot architecture diagrams

## Capture Preconditions

Before taking screenshots:

```bash
git status --short
./Obervability-Stack/scripts/devops-monitor.sh operator
```

Expected state:

- control plane healthy
- monitored apps healthy unless intentionally capturing an incident state
- no stale banner or loading artifact that would misrepresent normal behavior

## Suggested File Naming

Use a simple, reviewable naming convention:

```text
phase7-01-landing-page.png
phase7-02-dashboard.png
phase7-03-services.png
phase7-04-compare.png
phase7-05-opensis-app-page.png
phase7-06-alerts.png
phase7-07-notifications.png
phase7-08-demo-center.png
phase7-09-swiftpay-ui.png
phase7-10-incident-drill.png
phase7-11-architecture-system.png
phase7-12-architecture-workload-mapping.png
```

## Capture Standards

- Use desktop-width captures for the portfolio pack unless a mobile state is the point.
- Prefer clean browser chrome and readable text sizes.
- Do not crop out useful operator context.
- If sensitive data ever appears, stop and sanitize before keeping the image.
- If the page is loading live data, wait until the stable state is visible.

## Where These Visuals Should Be Used

The visual pack should feed:

- the root README
- portfolio sharing
- presentation decks
- interview walkthroughs
- future documentation refreshes

## Success Criteria

This pack is successful when:

- a reviewer can understand the platform story quickly
- screenshots reinforce the architecture narrative instead of duplicating it
- the repo looks like a serious engineering project without relying on live narration
