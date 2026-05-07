# GitOps Activation

This document defines the repeatable activation path for ArgoCD in the live `k3s` development cluster.

## Current Status

The repository-side activation work is ready:

- root ArgoCD orchestration exists in the central repo
- `SwiftPay` now has a matching `dev` `Application` manifest
- the activation script is safe to rerun

The first live activation attempt on `2026-05-07` did not complete and was rolled back.

Why it was rolled back:

- the `colima` node briefly flapped `NotReady`
- `metrics-server` was already degraded with `MissingEndpoints`
- `k3s` and `cri-dockerd` showed timeout behavior during the install window
- ArgoCD controller pods stalled in image acquisition and pod startup long enough that the install could not be called trustworthy

This means:

- the GitOps design work is complete
- the live cluster activation still requires a stable runtime window

## Objective

Make ArgoCD the default reconciler for the live development platform without collapsing the multi-repo ownership model.

Ownership model:

- child repos own workload overlays and workload-local manifests
- the central platform repo owns environment composition and root orchestration

## Live Scope

This activation path targets the current development environment:

- `platform-observability-dev`
- `memflip-dev`
- `swiftpay-dev`
- `foodpulse-dev`
- `opensis-dev`

It does not attempt to activate `prod` in the current local `k3s` cluster.

## GitOps Layout

Central root orchestration lives here:

- [gitops/argocd/dev](/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/gitops/argocd/dev)
- [gitops/argocd/root/internal-developer-platform-dev-root-application.yaml](/Users/raymond/Documents/devops-easy-learning/internal-developer-platform/gitops/argocd/root/internal-developer-platform-dev-root-application.yaml)

The root application applies:

- one `AppProject`
- one `Application` per child repo for the live `dev` environment

## Activation Steps

1. Verify cluster access.

```bash
kubectl get ns
```

2. Verify the cluster is stable enough for controller bootstrap.

```bash
kubectl get nodes
kubectl get apiservice v1beta1.metrics.k8s.io -o wide
kubectl get pods -n kube-system
```

Do not proceed if:

- the node is flapping `NotReady`
- `metrics-server` is missing endpoints
- the runtime is already showing broad liveness/readiness churn across existing workloads

3. Install ArgoCD from the pinned upstream manifest.

The activation script uses:

- ArgoCD version: `v3.3.7`
- install manifest: `https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.7/manifests/install.yaml`

4. Apply the root platform application.

That root application points back to this repo and syncs the `dev` GitOps composition.

5. Verify application visibility.

```bash
kubectl get applications -n argocd
```

6. Verify sync and health behavior.

```bash
kubectl get applications -n argocd -o wide
kubectl describe application internal-developer-platform-dev-root -n argocd
```

## Operator Command

```bash
cd /Users/raymond/Documents/devops-easy-learning/internal-developer-platform
./scripts/activate-argocd-gitops.sh
```

## Expected Result

After activation:

- ArgoCD is installed in `argocd`
- the root application exists:
  - `internal-developer-platform-dev-root`
- child applications exist for:
  - `observability-dev`
  - `memflip-dev`
  - `swiftpay-dev`
  - `foodpulse-dev`
  - `opensis-dev`

## Day-Two Operating Rule

Normal Kubernetes changes for the owned development paths should move through Git first.

That means:

- commit changes in the authoritative child repo or central repo
- let ArgoCD reconcile
- only use direct `kubectl apply` for break-glass recovery or bootstrap work

## Recovery Notes

If the root application exists but child applications do not converge:

1. inspect the root application:

```bash
kubectl describe application internal-developer-platform-dev-root -n argocd
```

2. inspect one child application:

```bash
kubectl describe application observability-dev -n argocd
```

3. inspect controller logs:

```bash
kubectl logs -n argocd statefulset/argocd-application-controller
kubectl logs -n argocd deployment/argocd-repo-server
```

4. force a refresh if needed:

```bash
kubectl annotate application internal-developer-platform-dev-root -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

## Rollback Procedure

If the controller install starts during a bad runtime window and the pods do not become usable, remove the partial install instead of leaving the cluster noisy.

```bash
kubectl delete namespace argocd --ignore-not-found=true
kubectl delete pod -n argocd --all --force --grace-period=0 2>/dev/null || true
kubectl get namespace argocd -o json | jq '.spec.finalizers=[]' | kubectl replace --raw /api/v1/namespaces/argocd/finalize -f -
```

Use the finalizer-removal step only if the namespace is stuck `Terminating` and the namespace contains no live content you intend to preserve.
