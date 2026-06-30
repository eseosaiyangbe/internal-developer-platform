# Internal Developer Platform CI/CD Workflow

This repository is intentionally validation-first and does not publish application images.

## Why

The workload image pipelines live in the authoritative child repositories:

- `swiftpay`
- `opensis`
- `foodpulse`
- `memflip`
- `observability-stack`

This central repository owns:

- workspace coordination scripts
- GitOps root and environment manifests
- platform bootstrap and recovery automation
- Hermes Agent read-only operator tooling

That means the correct CI/CD contract here is repository validation, not image publication.

## Active Lane

- `validate.yml`
  - lints GitHub Actions workflows
  - lints shell scripts
  - validates the Hermes Python entrypoint
  - lints YAML
  - renders GitOps and platform manifests
  - performs client-side dry runs for the root application contracts

## Promotion Boundary

Workload promotion happens in the child repositories where images are built and versioned.

This repository should only receive reviewed GitOps and platform changes after those child-repo contracts are satisfied.

## Child Repository Workflow Standard

The current expected child-repository workflow model is:

1. validation lane
2. Docker Hub publish lane
3. active public `dev` smoke lane
4. dormant or manual `prod` promotion only where it remains useful

That standard now applies across:

- `swiftpay`
- `opensis`
- `foodpulse`
- `memflip`
- `observability-stack`

Why this matters:

- validation proves repository and build integrity
- image publishing proves artifact creation and registry availability
- public `dev` smoke proves that users can actually reach the active runtime
- manual `prod` posture prevents the local platform from pretending to be a continuously promoted production system
