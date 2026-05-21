# GitOps Activation

This document defines the repeatable activation path for ArgoCD in the live `k3s` development cluster.

## Current Status

ArgoCD is now active in the live `k3s` development cluster and is the default reconciler for the owned `dev` paths.

Current result:

- `argocd` is installed and healthy
- root application `internal-developer-platform-dev-root` is active
- child applications reconcile for:
  - `observability-dev`
  - `memflip-dev`
  - `swiftpay-dev`
  - `foodpulse-dev`
  - `opensis-dev`

The repository-side activation work is complete:

- root ArgoCD orchestration exists in the central repo
- `SwiftPay` now has a matching `dev` `Application` manifest
- the activation script is safe to rerun

The first live activation attempt on `2026-05-07` did not complete and was rolled back.

Why it was rolled back:

- the `colima` node briefly flapped `NotReady`
- `metrics-server` was already degraded with `MissingEndpoints`
- `k3s` and `cri-dockerd` showed timeout behavior during the install window
- ArgoCD controller pods stalled in image acquisition and pod startup long enough that the install could not be called trustworthy

That failed attempt is now superseded by the successful activation and validation pass completed on `2026-05-20` and `2026-05-21`.

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

## Browser Access

There is no public ingress for ArgoCD in the current local `k3s` environment.

Use local port-forwarding:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Open in browser:

- [http://localhost:8080](http://localhost:8080)

Get the initial admin password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode && echo
```

Login:

- username: `admin`
- password: output from the command above

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

## Live Completion Record

The successful live activation was completed across `2026-05-20` and `2026-05-21`.

### Activation Commands Used

Cluster and runtime validation:

```bash
kubectl get ns
kubectl get nodes
kubectl get apiservice v1beta1.metrics.k8s.io -o wide
kubectl get pods -n kube-system
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

ArgoCD activation:

```bash
cd /Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform
./scripts/activate-argocd-gitops.sh
kubectl get applications -n argocd -o wide
kubectl describe application internal-developer-platform-dev-root -n argocd
```

Private GitHub repository credential fix for ArgoCD:

```bash
kubectl create secret generic argocd-github-eseosaiyangbe-creds \
  -n argocd \
  --from-literal=url=https://github.com/eseosaiyangbe \
  --from-literal=username=eseosaiyangbe \
  --from-literal=password="$(gh auth token)" \
  --from-literal=type=git \
  --dry-run=client -o yaml \
  | kubectl label -f - argocd.argoproj.io/secret-type=repo-creds --local -o yaml \
  | kubectl apply -f -
```

Root and child refresh operations used during validation:

```bash
kubectl annotate application internal-developer-platform-dev-root -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application swiftpay-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application memflip-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application opensis-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

### Runtime Issues Faced

The activation did not start from a clean cluster window. These issues had to be resolved first:

- `opensis-ui` degraded during the pre-activation stabilization window
- `metrics-server` showed `MissingEndpoints`
- `metrics.k8s.io` became unavailable during the same runtime churn
- `platform-observability-prod` was adding unnecessary footprint on the single-node local `Colima` cluster
- `SwiftPay` later exposed a GitOps ownership conflict between ArgoCD and HPA on `transaction-service`

### Runtime Recovery Actions Used

To create a trustworthy activation window:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io -o wide
kubectl logs -n kube-system deployment/metrics-server --tail=200
colima restart
```

To reduce local runtime pressure before activation:

- the local `platform-observability-prod` slice was paused
- the production observability footprint was treated as non-essential for the `dev` GitOps activation window

### GitOps Drift Issues Resolved

#### SwiftPay

`swiftpay-dev` initially remained `Healthy` but `OutOfSync`.

Root cause:

- `transaction-service` is HPA-managed
- Git pinned `spec.replicas`
- ArgoCD kept trying to force the deployment back to the Git replica count

Fix:

- added `ignoreDifferences` for `/spec/replicas` on the HPA-managed SwiftPay deployments in:
  - [gitops/argocd/dev/swiftpay-dev-application.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/gitops/argocd/dev/swiftpay-dev-application.yaml)

#### OpenSIS

`OpenSIS` exposed probe sensitivity during the stabilization window.

Fix:

- probe timeout and failure thresholds were hardened in:
  - [k8s/base/ui.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/k8s/base/ui.yaml)
  - [k8s/base/db.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/k8s/base/db.yaml)
  - [k8s/base/redis.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/k8s/base/redis.yaml)
  - [k8s/base/observability-apache-exporter.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/k8s/base/observability-apache-exporter.yaml)
  - [k8s/base/observability-mysqld-exporter.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/k8s/base/observability-mysqld-exporter.yaml)
  - [k8s/base/observability-vault-synthetic.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/opensis/k8s/base/observability-vault-synthetic.yaml)

### Validation Pass Executed

Three Git-driven validation slices were executed:

1. Workload app validation:
   - `MemFlip` commit:
     - `afa2204` `Add GitOps validation marker to MemFlip frontend`
   - live result:
     - `memflip-dev` reconciled to the new revision
     - the live frontend deployment received:
       - `gitops.dev/validation-marker=2026-05-20-memflip-frontend`

2. Application operational baseline validation:
   - `OpenSIS` commit:
     - `a150b24` `Harden OpenSIS probe thresholds for k3s stability`
   - live result:
     - `opensis-dev` reconciled to the new revision
     - the new probe settings became live through ArgoCD reconciliation

3. Shared platform primitive validation:
   - `internal-developer-platform` commit:
     - `17a68a4` `Add GitOps validation marker to ArgoCD project`
   - live result:
     - the live `AppProject` received:
       - `gitops.dev/validation-marker=2026-05-20-argocd-project`

### Commits Pushed During Activation And Validation

- `internal-developer-platform` -> `ac320ce` `Ignore SwiftPay HPA replica drift in ArgoCD`
- `internal-developer-platform` -> `17a68a4` `Add GitOps validation marker to ArgoCD project`
- `MemFlip` -> `afa2204` `Add GitOps validation marker to MemFlip frontend`
- `OpenSIS` -> `a150b24` `Harden OpenSIS probe thresholds for k3s stability`

### Final State

At the end of the activation and validation pass:

- ArgoCD is active and healthy
- root application is `Synced` and `Healthy`
- all `dev` child applications are `Synced` and `Healthy`
- Git is now the default reconciler path for the owned `dev` platform

## Rollback Procedure

If the controller install starts during a bad runtime window and the pods do not become usable, remove the partial install instead of leaving the cluster noisy.

```bash
kubectl delete namespace argocd --ignore-not-found=true
kubectl delete pod -n argocd --all --force --grace-period=0 2>/dev/null || true
kubectl get namespace argocd -o json | jq '.spec.finalizers=[]' | kubectl replace --raw /api/v1/namespaces/argocd/finalize -f -
```

Use the finalizer-removal step only if the namespace is stuck `Terminating` and the namespace contains no live content you intend to preserve.
