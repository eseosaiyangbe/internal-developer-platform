# Phase 7 Visual Capture Log

## Purpose

This document records the first real screenshot capture pass for the Phase 7 portfolio pack.

It exists so the visual artifacts are:

- traceable
- reviewable
- tied back to a known healthy platform state

## Capture Baseline

Capture date:

```text
2026-04-25
```

Baseline command:

```bash
./Obervability-Stack/scripts/devops-monitor.sh operator
```

Validated result before capture:

- control-plane smoke check passed `30/30`
- inventory validation passed
- `OpenSIS`, `SwiftPay`, `MemFlip`, and `FoodPulse` all reported healthy

## Captured Artifacts

Stored under:

```text
output/playwright/phase7/
```

Artifacts captured:

1. `phase7-01-landing-page.png`
2. `phase7-02-dashboard.png`
3. `phase7-03-services.png`
4. `phase7-04-compare.png`
5. `phase7-05-opensis-app-page.png`
6. `phase7-06-alerts.png`
7. `phase7-07-notifications.png`
8. `phase7-08-demo-center.png`
9. `phase7-09-swiftpay-ui.png`

## What This Capture Pass Covers

This first pass already covers the strongest control-plane story:

- presenter front door
- simplified operator dashboard
- managed app launch board
- workload comparison view
- app-specific handoff page
- active alerts
- resolved history / notifications
- demo workflow
- one live managed workload

## What Is Still Worth Capturing

The next visual pass should add:

1. one incident-drill evidence screenshot
2. one exported architecture diagram image
3. one additional live app UI if we want broader workload coverage

## Why The Baseline Fix Matters

During this capture pass, the operator baseline initially failed because the control-plane health script treated `devops-monitor-db-init` as a long-running service even though it is a one-shot init path.

That was corrected in:

- [health-check.sh](/Users/raymond/Documents/DevOps-Easy-Learning/Obervability-Stack/scripts/health-check.sh)

The script now treats successful one-shot init services correctly, which makes the visual-capture baseline truthful instead of noisy.

## Recommended Next Use

These captures are now suitable for:

- README curation
- portfolio sharing
- presentation decks
- interview walkthroughs

They should remain tied to the Phase 7 narrative in:

- [PORTFOLIO-SNAPSHOT.md](/Users/raymond/Documents/DevOps-Easy-Learning/PORTFOLIO-SNAPSHOT.md)
- [VISUAL-EVIDENCE-PACK.md](/Users/raymond/Documents/DevOps-Easy-Learning/VISUAL-EVIDENCE-PACK.md)
