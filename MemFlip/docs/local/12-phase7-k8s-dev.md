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

It is designed to run on both:

- macOS with Colima-backed `k3s`
- Linux with a locally installed `k3s` service

## What This Path Uses

Directory layout:

```text
MemFlip/k8s/
├── argocd/
│   ├── memflip-dev-application.yaml
│   └── memflip-prod-application.yaml
├── base/
│   ├── app-config.yaml
│   ├── backend.yaml
│   ├── frontend.yaml
│   ├── ingress.yaml
│   ├── kustomization.yaml
│   ├── networkpolicy.yaml
│   ├── postgres.yaml
│   └── redis.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── vault-external-secret.yaml
    │   ├── vault-secret-store.yaml
    │   └── vault-serviceaccount.yaml
    └── prod/
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── vault-external-secret.yaml
        ├── vault-secret-store.yaml
        └── vault-serviceaccount.yaml
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
- `SecretStore`: namespace-scoped Vault connector for External Secrets Operator
- `ExternalSecret`: Vault-backed materialization of `memflip-app-secrets`
- `NetworkPolicy`: default deny plus explicit workload traffic rules

The current `prod` shape is:

- `Namespace`: `memflip-prod`
- `Ingress`: `memflip.prod.example.com`
- `SecretStore`: namespace-scoped Vault connector for External Secrets Operator
- `ExternalSecret`: Vault-backed materialization of `memflip-app-secrets`
- higher application replica counts and larger persistent volumes than `dev`

## Why This Is The Right First Slice

This implementation keeps the first migration disciplined:

- simple enough to reason about quickly
- real enough to exercise ingress, config, secrets, and persistent storage
- aligned with the root platform direction: ArgoCD, Traefik, and future Vault

It is intentionally not over-engineered.

It does include a small but meaningful security baseline:

- namespace-scoped default deny network policy
- explicit frontend, backend, PostgreSQL, and Redis traffic rules
- DNS egress only where the workload needs it

## Secret-Management Standard

Both `dev` and `prod` now treat Vault as the source of truth.

The Kubernetes path assumes:

1. Vault is installed in the cluster namespace `vault`
2. External Secrets Operator is installed in namespace `external-secrets`
3. the workspace bootstrap script seeds the required secret paths in Vault
4. each overlay materializes only the Kubernetes Secret objects the workloads consume

Bootstrap the shared secrets platform from the workspace root:

```bash
./scripts/bootstrap-k3s-vault-secrets.sh
```

## Build The Application Images

Build the local images first:

```bash
docker build -t memflip-backend:dev MemFlip/backend
docker build -t memflip-frontend:dev MemFlip/frontend
```

If your local cluster does not share the host Docker image store, import or push these images using the cluster-specific workflow before applying the manifests.

## Use The Operator Scripts

Recommended operator path:

```bash
cd MemFlip
./scripts/k8s-dev-deploy.sh
```

That deploy script now bootstraps the shared Vault and External Secrets platform automatically unless you pass `--skip-secrets-platform`.

Verification only:

```bash
cd MemFlip
./scripts/k8s-dev-verify.sh
```

Tear down the dev slice:

```bash
cd MemFlip
./scripts/k8s-dev-destroy.sh
```

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

To discover the current Traefik entry address on either macOS or Linux:

```bash
kubectl get svc traefik -n traefik
```

Or use the workspace helper:

```bash
./scripts/ensure-k3s-runtime.sh
```

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
