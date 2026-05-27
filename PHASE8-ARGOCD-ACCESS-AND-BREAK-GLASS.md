# Phase 8 ArgoCD Access And Break-Glass Model

Date: `2026-05-27`

## Purpose

This document defines the current operator access model for ArgoCD on the local `k3s` platform and the break-glass rules that apply when GitOps-managed recovery work needs temporary live intervention.

This is not a production SSO design.

It is the disciplined local-platform access contract that keeps the GitOps operating model honest while Phase 8 continues.

## Current Access Posture

ArgoCD is active and authoritative for the owned `dev` paths, but access is intentionally operator-local.

Current truth:

- no public ingress for ArgoCD
- no SSO integration
- no audited identity-aware access proxy in front of the UI
- UI access is available only through local port-forwarding

That posture is acceptable for the current local platform if it is treated as:

- a local operator surface
- a controlled recovery tool
- not a general shared admin endpoint

## Normal Operator Access

### 1. Command-line status first

The normal first step is not the browser.

Use `kubectl` first:

```bash
kubectl get application internal-developer-platform-dev-root observability-dev swiftpay-dev foodpulse-dev memflip-dev opensis-dev -n argocd -o wide
```

Use the UI only when you need:

- richer sync history
- tree-level resource inspection
- a visual diff or health read

### 2. Local browser access path

Start a local port-forward:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Open:

- [http://localhost:8080](http://localhost:8080)

### 3. Bootstrap admin credential path

If the initial bootstrap secret still exists:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode && echo
```

Login:

- username: `admin`
- password: output from the command above

Operator rule:

- treat the bootstrap secret as a setup or recovery credential, not as the preferred day-two workflow
- prefer `kubectl` for routine status and Git-first changes for routine operations

## Day-Two GitOps Rule

The default operating path is:

1. change Git in the authoritative repo
2. push the change
3. let ArgoCD reconcile
4. verify sync and workload health

Direct live mutation is acceptable only for:

- bootstrap
- break-glass stabilization
- tightly controlled restore drills

If live mutation is used, the permanent correction must go back into Git afterward.

## Break-Glass Categories

### Category A. Safe read-only intervention

Examples:

- `kubectl get application ...`
- `kubectl describe application ...`
- `kubectl logs` against `argocd-application-controller`
- `kubectl logs` against `argocd-repo-server`
- local UI access through port-forward

These do not change desired state.

### Category B. Controlled reconcile-path intervention

Examples:

- hard refresh on the root or child application
- temporary GitOps suspension during a restore drill
- re-enable of automated sync after the drill

These are acceptable when the action is:

- deliberate
- documented
- reversed after the recovery step

### Category C. True break-glass mutation

Examples:

- direct `kubectl apply` against Git-managed workload manifests
- deleting or replacing ArgoCD objects to recover controller behavior
- forcing emergency runtime state outside the intended reconcile path

These are higher-risk actions and should be treated as:

- temporary stabilization only
- followed by Git reconciliation
- recorded in the runbook if they represent a new operational pattern

## Standard Commands

### ArgoCD application status snapshot

```bash
kubectl get application internal-developer-platform-dev-root observability-dev swiftpay-dev foodpulse-dev memflip-dev opensis-dev -n argocd -o wide
```

### Inspect the root application

```bash
kubectl describe application internal-developer-platform-dev-root -n argocd
```

### Inspect a child application

```bash
kubectl describe application opensis-dev -n argocd
```

### Inspect controller logs

```bash
kubectl logs -n argocd statefulset/argocd-application-controller --tail=200
kubectl logs -n argocd deployment/argocd-repo-server --tail=200
```

### Force a hard refresh

```bash
kubectl annotate application internal-developer-platform-dev-root -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application opensis-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

## Standard Restore-Drill GitOps Procedure

For a controlled restore drill on a GitOps-managed child application, the root application and the child application must both be considered.

Reason:

- the child app can reconcile the workload back to the Git-defined state
- the root app can also recreate or reassert the child application spec itself

### Scripted operator path

Suspend automated sync:

```bash
./scripts/argocd-restore-drill-sync.sh suspend --app opensis-dev
```

Check current posture:

```bash
./scripts/argocd-restore-drill-sync.sh status --app opensis-dev
```

Resume automated sync and refresh:

```bash
./scripts/argocd-restore-drill-sync.sh resume --app opensis-dev
```

Supported child apps:

- `observability-dev`
- `swiftpay-dev`
- `foodpulse-dev`
- `memflip-dev`
- `opensis-dev`

### Equivalent manual path

Suspend:

```bash
kubectl patch application internal-developer-platform-dev-root -n argocd --type json -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
kubectl patch application opensis-dev -n argocd --type json -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
```

Resume:

```bash
kubectl patch application internal-developer-platform-dev-root -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl patch application opensis-dev -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true"]}}}'
kubectl annotate application opensis-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

## Known Operational Patterns

### 1. `Unknown` does not automatically mean workload failure

ArgoCD can temporarily report a child app as `Unknown` when the repo-server comparison path fails even if the workload namespace remains healthy.

First question:

- is this a comparison-path failure, or a workload failure?

Check:

```bash
kubectl get application opensis-dev -n argocd -o yaml
kubectl logs -n argocd statefulset/argocd-application-controller --tail=200
kubectl logs -n argocd deployment/argocd-repo-server --tail=200
```

### 2. Manual validation Jobs can make an app appear `OutOfSync`

This is expected when a one-off Job is created against a Git-managed namespace for validation.

Operator action:

- clean up the manual Job
- refresh the child application if needed

### 3. GitOps authority should be re-established after any live drill

A restore drill is complete only when:

- the workload verification passes
- automated sync is re-enabled
- the child application returns to `Synced`
- the runtime is healthy again

## Current Phase 8 Assessment

This access model is stronger than the earlier implicit posture because it now has:

- explicit normal access rules
- explicit break-glass categories
- a repeatable restore-drill suspension and resume path
- a scripted helper for root-plus-child GitOps toggle control

What still remains outside this step:

- a stronger production-style access model than local port-forward
- SSO or identity-aware ArgoCD access
- audited operator identity beyond local cluster access
