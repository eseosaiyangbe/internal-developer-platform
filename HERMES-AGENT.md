# Hermes Agent

Hermes Agent is a read-only home-lab assistant for the Internal Developer Platform.

It is designed to help an operator:

- inspect Kubernetes health
- summarize ArgoCD sync posture
- read logs safely
- generate incident notes
- propose remediation steps

It is intentionally not allowed to apply changes on its own.

Any remediation output must be reviewed and run manually by the operator.

## Why It Exists

The platform now has enough operational surface area that a simple helper can reduce operator friction without weakening control discipline.

Hermes is deliberately scoped as an observer and summarizer, not a self-acting controller.

That keeps the project aligned with the current local-runtime trust model:

- evidence first
- recommendations second
- manual approval before any change

## Location

- Script: [scripts/hermes-agent.py](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/scripts/hermes-agent.py)
- Output directory for generated notes: [output/hermes](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/output/hermes)

## Capabilities

### 1. Cluster Health Inspection

Reads:

- current Kubernetes context
- node readiness
- unhealthy or restarting pods in the inspected namespaces
- ArgoCD application sync and health posture
- recent cluster events

Example:

```bash
./scripts/hermes-agent.py health
./scripts/hermes-agent.py health --namespace swiftpay-dev --namespace argocd --format json
```

### 2. ArgoCD Summary

Reads:

- `applications.argoproj.io` across namespaces
- sync status
- health status
- reported revision

Example:

```bash
./scripts/hermes-agent.py argocd
```

### 3. Safe Log Reading

Reads recent logs from:

- a direct Kubernetes resource reference
- or the first pod matched by a label selector

Examples:

```bash
./scripts/hermes-agent.py logs --namespace foodpulse-dev --resource deployment/foodpulse-api --tail 120
./scripts/hermes-agent.py logs --namespace argocd --selector app.kubernetes.io/name=argocd-repo-server --tail 80
```

### 4. Incident Note Generation

Generates a markdown incident note from the current read-only status surfaces.

Examples:

```bash
./scripts/hermes-agent.py incident-note --title "FoodPulse API health regression"
./scripts/hermes-agent.py incident-note --title "ArgoCD comparison instability" --write
```

### 5. Remediation Proposals

Builds manual next-step proposals from the inspected health signals.

It does not execute them.

Example:

```bash
./scripts/hermes-agent.py remediate --incident-title "SwiftPay degraded state"
```

## Guardrail

Hermes explicitly refuses automatic change execution.

Example:

```bash
./scripts/hermes-agent.py approve "restart deployment/auth-service"
```

Expected result:

- Hermes refuses
- the operator is told to review and run the command manually

## Operating Model

Hermes is intentionally conservative:

- it uses `kubectl get`, `kubectl logs`, and other read-only inspection paths
- it does not call `kubectl apply`, `kubectl patch`, `kubectl delete`, or any equivalent mutating operation
- it does not suspend or resume ArgoCD automation
- it does not write to Vault

This makes it appropriate for:

- day-two inspection
- drill note generation
- recruiter demo walkthroughs
- incident narrative acceleration

It is not a replacement for operator judgment.

## Verification

Recommended smoke checks:

```bash
./scripts/hermes-agent.py health
./scripts/hermes-agent.py argocd
./scripts/hermes-agent.py logs --namespace argocd --selector app.kubernetes.io/name=argocd-repo-server --tail 20
./scripts/hermes-agent.py incident-note --title "Hermes smoke test"
./scripts/hermes-agent.py remediate
```
