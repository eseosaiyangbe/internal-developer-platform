# OpenSIS Kubernetes Assessment

This document records the current `OpenSIS` Kubernetes position after the Phase 7 workload and control-plane migration work.

It exists to answer one question clearly:

- what should the owned `OpenSIS` Kubernetes path be now that the workspace has standardized on `k3s`, Traefik, Vault, ArgoCD, and a shared observability control plane?

## Current Reality

`OpenSIS` is not starting from zero.

The older Kubernetes tree discussed in this assessment is now preserved at:

- [OpenSIS/k8s-legacy-platform](/Users/raymond/Documents/DevOps-Easy-Learning/OpenSIS/k8s-legacy-platform)

The repo already contains:

- a substantial `k8s/` tree
- `dev` and `prod` overlays
- Argo CD application manifests
- Vault-backed secret delivery through Vault Agent Injector
- MariaDB `StatefulSet`
- Redis-backed PHP session support
- backup and restore workflows
- Cloudflare-facing production guidance

That is useful, but it does not mean the current path should be adopted unchanged.

The older Kubernetes path was built around a different cluster story than the one the workspace now uses.

## Sweep Findings

### 1. `OpenSIS` already models the right secret-delivery principle

This is the strongest part of the current path.

The current manifests already assume:

- Vault is the source of truth
- workloads authenticate through Kubernetes auth
- secrets are rendered into files at runtime

That aligns with the application’s actual needs better than a generic `ExternalSecret`-only pattern.

For `OpenSIS`, file-based runtime secret rendering is still the correct Kubernetes direction because the app and DB startup contract already depend on rendered env files.

Recommendation:

- keep Vault as the source of truth
- keep runtime file rendering
- keep Kubernetes-native auth
- preserve Vault Agent Injector, or an equivalent file-rendering Vault path, as the owned runtime model

### 2. The ingress model is out of alignment with the workspace standard

The current public-facing Kubernetes docs still teach:

- `ingress-nginx` for the bootstrap path
- an older dev expectation centered on `nginx`

The workspace standard is now:

- Traefik for ingress

Recommendation:

- standardize the owned `OpenSIS` Kubernetes path on Traefik
- treat remaining `nginx` guidance as historical or transitional
- keep public-edge concerns separate from the core app ingress contract

### 3. The current legacy `OpenSIS` base duplicates observability concerns that now belong to the shared control plane

The existing legacy `OpenSIS/k8s-legacy-platform/base` includes:

- Prometheus
- Grafana
- Alertmanager
- node-exporter
- blackbox-exporter
- mysqld-exporter
- kube-state-metrics

That made sense when `OpenSIS` was carrying its own platform story. It is now misaligned with the workspace architecture.

The workspace already has a shared observability platform with:

- Prometheus
- Grafana
- Alertmanager
- Loki
- control-plane UI

Recommendation:

- remove embedded observability platform components from the owned `OpenSIS` app path
- keep only workload-local surfaces that the shared control plane should scrape:
  - `mysqld-exporter`
  - app probe target
  - Vault synthetic checks if still valuable
- let the shared control plane remain the only platform observability layer

### 4. The repo has a real GitOps path, but it needs to be reinterpreted rather than copied forward blindly

The existing repo already has:

- Argo CD project and application manifests
- `dev` and `prod` overlays
- promotion thinking

That is directionally correct.

But it still assumes older environment names, ingress expectations, and a more self-contained platform model than the workspace now uses.

Recommendation:

- keep Argo CD as the reconciler
- keep `dev` and `prod` overlays
- rebuild the owned path around the current workspace standards instead of preserving every old assumption

### 5. Session Redis should stay

The current overlays already include Redis-backed PHP sessions.

That is important and should remain in the owned path because:

- multi-replica UI behavior depends on shared session state
- this is part of the real production contract, not optional polish

Recommendation:

- keep session Redis in both `dev` and `prod`
- treat it as part of the core application runtime, not a temporary convenience

### 6. The local startup helper does not match the current workspace Kubernetes runtime

The current `OpenSIS/scripts/k8s-start.sh` assumes:

- repo-local cluster lifecycle control
- `systemctl`-managed `k3s`
- manual Vault unseal tied to an older local path

The workspace standard is now:

- shared local `k3s`
- `./scripts/ensure-k3s-runtime.sh`
- shared Vault bootstrap and Traefik ingress model

Recommendation:

- stop treating `OpenSIS` as if it owns the cluster lifecycle
- make `OpenSIS` consume the shared runtime instead
- add deploy, verify, and destroy scripts that match the MemFlip, SwiftPay, FoodPulse, and Obervability-Stack pattern

## What Should Be Preserved

These parts of the current Kubernetes story are worth preserving:

- Vault-first secret design
- Argo CD application structure
- MariaDB as a `StatefulSet`
- Redis-backed session handling
- backup and restore discipline
- Cloudflare-facing production edge considerations

## What Should Change

These parts should change in the owned Phase 7 path:

- Traefik should replace `nginx` as the primary ingress standard
- the app path should stop embedding its own full observability stack
- local cluster assumptions should move to the shared workspace runtime
- the overlay story should align with the workspace `dev` and `prod` environment model more explicitly
- operator commands should match the new workspace convention:
  - deploy
  - verify
  - destroy

## Recommended Owned Kubernetes Shape

The owned `OpenSIS` Kubernetes path should look like this:

- `OpenSIS/k8s/base`
  - `opensis-ui`
  - `opensis-db`
  - `opensis-session-redis`
  - Services
  - Traefik ingress
  - minimal exporter/probe surfaces needed by the shared control plane
  - Vault Injector annotations for app and DB

- `OpenSIS/k8s/overlays/dev`
  - local image path
  - lower resources and storage
  - local hostnames
  - `opensis-dev` namespace
  - Vault roles and secret paths for `dev`

- `OpenSIS/k8s/overlays/prod`
  - pinned production image tags
  - stricter resources
  - production hostnames
  - `opensis-prod` namespace
  - production Vault roles and secret paths
  - Cloudflare-facing edge integration where appropriate

- `OpenSIS/k8s/argocd`
  - `dev` application
  - `prod` application

## Recommended Secret Strategy

For `OpenSIS`, the right answer is not “copy the other apps exactly.”

The right answer is:

- Vault remains the secret source of truth
- Kubernetes auth remains the workload auth path
- secret delivery stays file-based through Vault rendering
- `OpenSIS` uses the mechanism that matches its runtime needs

This is still consistent with the workspace standard because:

- source of truth is still Vault
- Git still holds desired state, not secret values
- Argo CD still reconciles workloads

The delivery mechanism is allowed to differ where the workload genuinely requires it.

## Recommended Implementation Order

1. Correct the docs and roadmap so `OpenSIS` is explicitly the next active Kubernetes slice.
2. Archive or mark older `nginx`-centric guidance as transitional.
3. Define the new owned `OpenSIS` base around:
   - app
   - DB
   - session Redis
   - Traefik ingress
   - Vault Injector
   - minimal exporter surfaces
4. Remove embedded full-platform observability components from the app path.
5. Add workspace-standard scripts:
   - `k8s-dev-deploy.sh`
   - `k8s-dev-verify.sh`
   - `k8s-dev-destroy.sh`
6. Validate the `dev` slice live on the shared `k3s` runtime.
7. Define the stricter `prod` contract after the `dev` path is stable.

## Final Recommendation

`OpenSIS` should be the next Phase 7 implementation slice.

But it should not be migrated as a blind lift-and-shift of the existing repo `k8s/` tree.

The correct approach is:

- preserve the strong parts
- retire the outdated platform assumptions
- align the owned path with the workspace standards already proven elsewhere

That gives the project the final advanced workload it still needs, without letting older design choices drag the platform story backward.
