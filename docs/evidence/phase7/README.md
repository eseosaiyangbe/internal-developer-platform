# Phase 7 Visual Evidence

Curated screenshot evidence for the Phase 7 k3s dev certification of the
platform control plane. These are the selected captures referenced by the
project documentation, moved here from the raw capture location
(`output/playwright/phase7/`, still the landing zone for new raw captures)
so the evidence set reads as a deliberate pack rather than tool output.

## Capture baseline

- Capture date: 2026-04-25
- Baseline command: `./Obervability-Stack/scripts/devops-monitor.sh operator`
- Validated before capture: control-plane smoke check passed 30/30,
  inventory validation passed, and OpenSIS, SwiftPay, MemFlip, and
  FoodPulse all reported healthy.
- Full log: [PHASE7-VISUAL-CAPTURE-LOG.md](../../../PHASE7-VISUAL-CAPTURE-LOG.md)
- Pack definition: [VISUAL-EVIDENCE-PACK.md](../../../VISUAL-EVIDENCE-PACK.md)

## The set

| # | File | Shows | Proves |
|---|------|-------|--------|
| 01 | `01-landing-page.png` | Presenter landing page | The control plane presents one entry point for the whole platform |
| 02 | `02-dashboard.png` | Simplified dashboard | Fleet health is visible at a glance |
| 03 | `03-services.png` | Services page | Every managed workload is inventoried in one place |
| 04 | `04-compare.png` | App comparison view | Workloads can be compared side by side on the same signals |
| 05 | `05-opensis-app-page.png` | OpenSIS app detail page | Per-app drill-down from the control plane into one workload |
| 06 | `06-alerts.png` | Alerts page | Alert state across the platform in one view |
| 07 | `07-notifications.png` | Notifications and resolved history | Alerts have a tracked lifecycle, not just a firing state |
| 08 | `08-demo-center.png` | Demo Center | The platform story can be presented from the product itself |
| 09 | `09-swiftpay-ui.png` | SwiftPay live app UI | A managed app running live behind the control plane |
| 10 | `10-foodpulse-ui.png` | FoodPulse live app UI | A second managed app running live behind the control plane |
| 11 | `11-incident-drills-doc.png` | Incident drills document (cropped) | Incident response is documented and drilled, not improvised |
| 12 | `12-architecture-diagram.png` | Platform architecture diagram | The control-plane design behind the screenshots |

## Curation notes

- The uncropped full-page version of capture 11 was dropped on
  2026-11-24; the cropped version above is the one the documentation
  references.
- All images were losslessly recompressed on 2026-11-24. Pixel content
  is unchanged.
- Captures 02 (dashboard, 1900 x 930), 03 (services, 1600 x 1796),
  and 04 (compare, 1600 x 2524) were replaced on 2026-11-24 with fresh
  live captures, so those three post-date the shared capture baseline
  above and reflect the platform's current state.
- New raw captures still land in `output/playwright/` (gitignored).
  Promote only the selected set here, in capture order, using the
  `NN-name.png` naming convention.
