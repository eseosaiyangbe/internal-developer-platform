# Phase 7 Visual Capture Log

## Purpose

This document records the live screenshot and diagram capture passes for the Phase 7 portfolio pack.

It exists so the visual artifacts are:

- traceable
- reviewable
- tied back to a known healthy platform state

## Shared Capture Baseline

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

## Artifact Location

Stored under:

```text
docs/evidence/phase7/
```

Relocated here from `output/playwright/phase7/` on 2026-11-24, with the
`phase7-` filename prefix dropped and the set indexed in that folder's
README. Raw captures still land in `output/playwright/`; only the
selected set is promoted.

## Capture Pass 1: Core Control-Plane Story

Artifacts captured:

1. `01-landing-page.png`
2. `02-dashboard.png`
3. `03-services.png`
4. `04-compare.png`
5. `05-opensis-app-page.png`
6. `06-alerts.png`
7. `07-notifications.png`
8. `08-demo-center.png`
9. `09-swiftpay-ui.png`

What this pass covers:

- presenter front door
- simplified operator dashboard
- managed app launch board
- workload comparison view
- app-specific handoff page
- active alerts
- resolved history / notifications
- demo workflow
- one live managed workload

## Capture Pass 2: Incident And Architecture Evidence

Artifacts captured:

10. `10-foodpulse-ui.png`
11. `11-incident-drills-doc.png`
12. `12-architecture-diagram.png`
13. `11-incident-drills-doc.png`

What this pass adds:

- a second live workload UI with a different operating story
- rendered incident-drill evidence from the public repo view
- a repo-native exported architecture diagram generated directly from the Mermaid source in [WORKSPACE-ARCHITECTURE.md](/Users/raymond/Documents/DevOps-Easy-Learning/WORKSPACE-ARCHITECTURE.md)
- a README-safe cropped incident-drill image for portfolio embedding without the full-page document height

## Why The Baseline Fix Matters

During the first capture pass, the operator baseline initially failed because the control-plane health script treated `devops-monitor-db-init` as a long-running service even though it is a one-shot init path.

That was corrected in:

- [health-check.sh](/Users/raymond/Documents/DevOps-Easy-Learning/Obervability-Stack/scripts/health-check.sh)

The script now treats successful one-shot init services correctly, which makes the visual-capture baseline truthful instead of noisy.

## Remaining Recommended Work

The visual pack now covers the required Phase 7 categories. The remaining work is curation, not missing evidence:

1. decide whether to export the second Mermaid diagram from [WORKSPACE-ARCHITECTURE.md](/Users/raymond/Documents/DevOps-Easy-Learning/WORKSPACE-ARCHITECTURE.md) as a companion image
2. decide whether to add one annotated incident screenshot from the live control plane for deck-ready storytelling
3. decide whether the four-visual README gallery should remain stable or whether a second surface such as the portfolio snapshot should keep the wider six-visual grid

## Recommended Next Use

These captures are now suitable for:

- README curation
- portfolio sharing
- presentation decks
- interview walkthroughs

They should remain tied to the Phase 7 narrative in:

- [PORTFOLIO-SNAPSHOT.md](/Users/raymond/Documents/DevOps-Easy-Learning/PORTFOLIO-SNAPSHOT.md)
- [VISUAL-EVIDENCE-PACK.md](/Users/raymond/Documents/DevOps-Easy-Learning/VISUAL-EVIDENCE-PACK.md)
