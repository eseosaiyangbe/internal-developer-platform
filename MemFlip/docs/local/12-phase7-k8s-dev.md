# MemFlip Phase 7 Kubernetes Dev Path

## Purpose

This is the first production-minded Kubernetes implementation slice for the workspace.

It exists to prove that one workload can move from local Compose into a `dev` cluster without losing:

- browser availability
- backend health
- metrics exposure
- stateful dependency clarity
- a clean operator handoff path

This path is the Phase 7 reference implementation for future workload migrations.

## What This Path Uses

Directory layout:

```text
MemFlip/k8s/
├── argocd/
│   └── memflip-dev-application.yaml
├── base/
│   ├── app-config.yaml
│   ├── backend.yaml
│   ├── frontend.yaml
│   ├── ingress.yaml
│   ├── kustomization.yaml
│   ├── postgres.yaml
│   └── redis.yaml
└── overlays/
    └── dev/
        ├── dev-secrets.env
        ├── kustomization.yaml
        └── namespace.yaml
```

The current `dev` shape is:

- `Namespace`: `memflip-dev`
- `StatefulSet`: PostgreSQL
- `StatefulSet`: Redis
- `Deployment`: backend
- `Deployment`: frontend
- `Service`: frontend, backend, postgres, redis
- `Ingress`: Traefik
- `ConfigMap`: non-secret runtime configuration
- `Secret`: dev-only Kubernetes secret generated from `dev-secrets.env`

## Why This Is The Right First Slice

This implementation keeps the first migration disciplined:

- simple enough to reason about quickly
- real enough to exercise ingress, config, secrets, and persistent storage
- aligned with the root platform direction: ArgoCD, Traefik, and future Vault

It is intentionally not over-engineered.

## Important Secret-Management Note

This first `dev` overlay uses a checked-in secret generator file:

- `MemFlip/k8s/overlays/dev/dev-secrets.env`

That is acceptable only because this path is for a local `dev` cluster bootstrap and the values are non-production development credentials.

It is not the final secret-management standard.

The intended progression is:

1. prove the workload migration pattern
2. prove GitOps reconciliation with ArgoCD
3. replace dev secret material with Vault-backed delivery
4. never use this checked-in secret path for production

## Build The Application Images

Build the local images first:

```bash
docker build -t memflip-backend:dev MemFlip/backend
docker build -t memflip-frontend:dev MemFlip/frontend
```

If your local cluster does not share the host Docker image store, import or push these images using the cluster-specific workflow before applying the manifests.

## Validate The Manifests

Render the overlay:

```bash
kubectl kustomize MemFlip/k8s/overlays/dev
```

Dry-run the overlay:

```bash
kubectl apply --dry-run=client -k MemFlip/k8s/overlays/dev
```

## Apply The Dev Overlay

```bash
kubectl apply -k MemFlip/k8s/overlays/dev
```

Expected namespace:

```bash
kubectl get ns memflip-dev
```

Expected workloads:

```bash
kubectl get pods -n memflip-dev
kubectl get svc -n memflip-dev
kubectl get ingress -n memflip-dev
```

## Traefik Route

Current dev hostname:

- `memflip.devops.local`

Traefik handles ingress for this path.

If local DNS is not yet wired, add a temporary hosts entry that points the hostname to the Traefik entry address for your cluster.

## ArgoCD Path

ArgoCD application manifest:

- `MemFlip/k8s/argocd/memflip-dev-application.yaml`

Apply it after ArgoCD is available:

```bash
kubectl apply -f MemFlip/k8s/argocd/memflip-dev-application.yaml
```

Then verify:

```bash
kubectl get application -n argocd memflip-dev
```

## Operator Validation Checklist

The MemFlip migration should not be considered complete until all of these are true:

- frontend page is reachable through Traefik
- backend `/health` is ready
- backend `/metrics` is available in-cluster
- PostgreSQL is writable
- Redis is reachable with the configured password
- the control plane can still describe MemFlip as a managed app with a clear operator narrative

## Relationship To The Older `MemFlip/k8s` Directory

The older `MemFlip/k8s-legacy-lab` manifests remain in the repository as learning-path artifacts.

They are not the authoritative Phase 7 migration path.

Use:

- `MemFlip/k8s/`

Do not treat the older ingress, monitoring, and tutorial manifests in `MemFlip/k8s-legacy-lab/` as the forward migration standard.
