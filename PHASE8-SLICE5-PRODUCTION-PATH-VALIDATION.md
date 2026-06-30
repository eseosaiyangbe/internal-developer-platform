# Phase 8 Slice 5 Production-Path Validation

Date: `2026-06-29`

## Purpose

This document records the first Slice 5 pass for broader production-path proof.

This pass is intentionally non-disruptive.

It does not touch the running `dev` workloads.

It focuses on three questions:

1. Do the owned `prod` overlays render cleanly as valid Git contracts?
2. Are the shared cluster dependencies those overlays assume actually present and ready?
3. What is still only production intent in Git rather than live production-style runtime proof?

## Scope

Owned repos reviewed in this pass:

- `SwiftPay`
- `FoodPulse`
- `MemFlip`
- `OpenSIS`
- `Obervability-Stack`

## Commands Used

Render validation:

```bash
for repo in swiftpay foodpulse memflip opensis observability-stack; do
  kubectl kustomize "/Users/raymond/Documents/DevOps-Easy-Learning/$repo/k8s/overlays/prod" >/tmp/${repo}-prod.yaml
done
```

Shared dependency checks:

```bash
kubectl get ns | rg 'cert-manager|argocd|platform-observability-prod|platform-observability-dev|vault' || true
kubectl get clusterissuer,issuer -A 2>/dev/null || true
kubectl get crd | rg 'externalsecrets|secretstores|postgresql.cnpg.io|applications.argoproj.io|cert-manager.io' || true
```

Overlay-control sweep:

```bash
for repo in swiftpay foodpulse memflip opensis observability-stack; do
  rg -n "kind: (HorizontalPodAutoscaler|PodDisruptionBudget|SecretStore|ExternalSecret|Ingress|StatefulSet)|cert-manager.io/cluster-issuer|topologySpreadConstraints|podAntiAffinity|emptyDir:|storageClassName|volumeClaimTemplates|host:" \
    "/Users/raymond/Documents/DevOps-Easy-Learning/$repo/k8s/overlays/prod" \
    "/Users/raymond/Documents/DevOps-Easy-Learning/$repo/k8s/base" \
    -g '*.yaml' -g '*.yml'
done
```

## Findings

### 1. Every owned `prod` overlay currently renders cleanly

Rendered successfully:

- `SwiftPay`
  - `2221` lines
- `FoodPulse`
  - `816` lines
- `MemFlip`
  - `1057` lines
- `OpenSIS`
  - `1551` lines
- `Obervability-Stack`
  - `8602` lines

What this means:

- the current production overlays are not just conceptual folder structure
- they are renderable Kubernetes contracts that can be inspected, diffed, and reviewed without touching the live `dev` runtime

### 2. The shared cluster dependencies assumed by the production overlays are present and ready

Observed shared dependencies:

- `argocd` namespace present
- `cert-manager` namespace present
- `vault` namespace present
- `platform-observability-prod` namespace present

Observed issuer state:

- `clusterissuer.cert-manager.io/letsencrypt-prod`
  - `Ready=True`
- `clusterissuer.cert-manager.io/letsencrypt-staging`
  - `Ready=True`

Observed CRD support present for:

- ArgoCD applications
- cert-manager issuers and certificate flows
- External Secrets `SecretStore` and `ExternalSecret`
- CloudNativePG cluster resources

What this means:

- the platform already carries the shared controller and CRD foundation that the owned production overlays expect
- Slice 5 does not start from missing platform primitives

### 3. The production overlays express a coherent cross-repo production-control model

Common production-path signals now present across the owned repos:

- Vault-first secret delivery through `SecretStore` and `ExternalSecret`
- explicit production ingress posture
- `cert-manager.io/cluster-issuer` production TLS contract
- production `HorizontalPodAutoscaler` posture for replicated stateless workloads
- production `PodDisruptionBudget` posture for replicated stateless workloads
- anti-affinity and topology-spread intent for replicated stateless workloads

What this means:

- the owned platform now has a coherent production-style control language in Git
- Slice 5 can build on a real contract baseline instead of inventing one

### 4. The main remaining gap is still live production-style runtime proof, not missing Git posture

This first pass did not exercise live production workloads.

It only proved:

- overlays render
- shared dependencies exist
- cross-repo production controls are explicit

It did not yet prove:

- production namespaces can reconcile the owned overlays end to end
- production ingress hosts can issue and bind certificates successfully in a real target path
- production HPAs, PDBs, and placement contracts behave correctly under live runtime conditions
- observability-state durability is strong enough for a more serious production claim

## Current Slice 5 Classification

This first pass supports a stronger but still bounded statement:

- production-style control posture is credible in Git
- shared production-path dependencies are present in the current cluster
- broader production-path proof is now limited more by live-runtime exercise scope than by missing overlay structure

This pass does not justify claiming:

- full production readiness
- deep production runtime validation
- production namespace operating maturity equivalent to the heavily exercised `dev` path

## Repo-Wide Workflow Normalization Update

Date: `2026-06-29`

As part of the same production-path honesty pass, the child repositories were normalized around the current runtime truth.

Standard now applied across:

- `SwiftPay`
- `OpenSIS`
- `FoodPulse`
- `MemFlip`
- `Obervability-Stack`

Normalized workflow shape:

- validation lane
- Docker Hub publish lane
- active public `dev` smoke lane
- dormant or manual `prod` promotion only where still useful

What this improves:

- the current public runtime story no longer depends on old `prod` naming assumptions
- image publication is no longer allowed to stand in for user-facing runtime proof
- the Slice 5 production-path narrative now separates live `dev` runtime proof from dormant `prod` contract posture more honestly

## Recommended Next Step

The next safe Slice 5 step should remain selective and explicit:

1. choose one narrow production-path validation target that does not jeopardize the current `dev` operating baseline
2. prefer a validation target that proves a shared production control rather than only another app-specific manifest render
3. document the difference between:
   - rendered production contract
   - dependency-ready platform path
   - live production-style runtime proof

The strongest current candidate is:

- selective production TLS and ingress-path proof, because the issuer path is live, the production overlays reference it consistently, and that validation can strengthen the production narrative without requiring a full owned-app production deployment.

## Second Slice 5 TLS And Ingress Validation Update

Date: `2026-06-29`

## What This Follow-Up Targeted

This follow-up took the next safe Slice 5 step:

1. determine whether the production TLS and ingress path is only declared in Git or already partially real in the cluster
2. identify the exact reason production certificate issuance is not yet complete

## Findings

### 1. The production observability TLS path is already live as a partially reconciled runtime path

Observed live production objects in `platform-observability-prod`:

- production ingresses for:
  - `devops-monitor-ui`
  - `grafana`
  - `prometheus`
  - `alertmanager`
  - `loki`
  - `node-exporter`
  - `blackbox-exporter`
  - `cadvisor`
  - `promtail`
- cert-manager `Certificate` objects for the same host set
- corresponding `CertificateRequest`, `Order`, and `Challenge` resources
- HTTP-01 solver ingresses, services, and pods

What this means:

- the production TLS path is no longer only a Git contract
- cert-manager is actively reconciling production-style issuance objects in the cluster
- Slice 5 now has real runtime evidence for the existence of the shared production TLS machinery

### 2. Certificate issuance is currently blocked at HTTP-01 self-check, not at controller installation

Observed challenge states:

- all inspected production observability challenges remained:
  - `Presented=true`
  - `Processing=true`
  - `State=pending`

Observed failure reasons split into two classes:

- DNS resolution failure for:
  - `portfolio-prod.eseosadevbox.com`
- unexpected HTML response instead of the ACME token for hosts such as:
  - `grafana.eseosadevbox.com`
  - `alertmanager.eseosadevbox.com`
  - `prometheus.eseosadevbox.com`

Representative cert-manager self-check reasons:

- `dial tcp: lookup portfolio-prod.eseosadevbox.com ... no such host`
- `did not get expected response ... but got: <!DOCTYPE html>`

What this means:

- the production TLS path is blocked by hostname and challenge-routing conditions, not by missing cert-manager, missing issuers, or missing ingress resources
- this is a stronger Slice 5 result than a pure render audit because it proves the platform reaches the ACME challenge stage before stalling

### 3. External host behavior confirms the current blocker sits outside the Kubernetes object model

Observed external hostname behavior from both the host and an in-cluster curl pod:

- `portfolio-prod.eseosadevbox.com`
  - did not resolve in DNS at all
- `grafana.eseosadevbox.com`
  - returned `HTTP/1.1 301 Moved Permanently`
- `alertmanager.eseosadevbox.com`
  - returned `HTTP/1.1 301 Moved Permanently`
- `prometheus.eseosadevbox.com`
  - returned `HTTP/1.1 301 Moved Permanently`

Observed response traits:

- the responding server was:
  - `cloudflare`
- the redirect target remained the same ACME path on `https://...`

What this means:

- for several production observability hosts, HTTP-01 is currently intercepted before the ACME token is served from the cluster ingress path
- for `portfolio-prod.eseosadevbox.com`, issuance cannot succeed until a resolvable DNS record exists
- the remaining blocker is therefore environmental:
  - public DNS ownership and publication
  - CDN or edge redirect behavior
  - ACME path passthrough on plain HTTP

### 4. The production namespace posture is still deliberately paused for workload scale, which limits what can be claimed

Observed live production namespace posture in `platform-observability-prod`:

- Deployments scaled to `0/0`
- StatefulSets scaled to `0/0`
- HPAs present but reporting `Replicas=0`
- only solver pods are actively running in the namespace

What this means:

- the current production observability path is real enough to test ingress and certificate reconciliation
- it is not yet a live application-runtime proof for the production workloads themselves
- the current safe proof band is:
  - production ingress objects exist
  - production certificate objects reconcile
  - production ACME solver flow is active
  - final issuance is still blocked

## Current Slice 5 Classification

This follow-up improves the production-path claim materially:

- production TLS is not merely described in repo documentation
- the cluster is actively attempting issuance for production observability hosts
- the current blocker is now concrete and operational:
  - unresolved or incorrect DNS visibility for at least one host
  - HTTP-to-HTTPS edge redirection before ACME token delivery for several others

This still does not justify claiming:

- successful live production certificate issuance
- production ingress readiness end to end
- complete production runtime proof for the owned workloads

## Recommended Next Step

The next Slice 5 step should stay narrow and evidence-driven:

1. decide whether to correct production DNS and ACME challenge routing for the observability production hosts in this environment
2. if that is intentionally out of scope for the local cluster, document the pending certificate state as an environmental constraint rather than a missing platform design
3. only after that, choose whether to expand Slice 5 into:
   - successful production TLS issuance proof
   - or a different low-risk shared production control path

## Third Slice 5 Shared Secret-Delivery Validation Update

Date: `2026-06-29`

## What This Follow-Up Targeted

This follow-up moved Slice 5 to the next low-risk shared production control:

1. prove that paused production namespaces can still receive runtime secrets through the real Vault-to-External-Secrets path
2. strengthen the production-path narrative without requiring active production workload scale-up
3. close the current TLS gap honestly as an environmental constraint in the local setup rather than conflating it with missing secret-delivery maturity

## Commands Used

```bash
kubectl get secretstore,externalsecret,secret -n platform-observability-prod
kubectl describe externalsecret observability-grafana-admin-external -n platform-observability-prod
kubectl describe externalsecret observability-postgres-app-external -n platform-observability-prod
kubectl describe externalsecret observability-ui-secrets-external -n platform-observability-prod
kubectl get secret -n platform-observability-prod \
  observability-ui-secrets \
  observability-grafana-admin \
  observability-postgres-app \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.type}{"\t"}{range $k,$v := .data}{$k}{" "}{end}{"\n"}{end}'
```

## Findings

### 1. The production `SecretStore` path is live and valid

Observed in `platform-observability-prod`:

- `secretstore.external-secrets.io/vault-backend`
  - `STATUS=Valid`
  - `READY=True`

What this means:

- the paused production namespace is not pointing at a speculative secret backend
- the shared Vault integration path is live and accepted by the External Secrets controller

### 2. Production `ExternalSecret` reconciliation is live for the core observability runtime secrets

Observed live `ExternalSecret` state:

- `observability-grafana-admin-external`
  - `STATUS=SecretSynced`
  - `READY=True`
- `observability-postgres-app-external`
  - `STATUS=SecretSynced`
  - `READY=True`
- `observability-ui-secrets-external`
  - `STATUS=SecretSynced`
  - `READY=True`

Observed Vault source paths from the controller descriptions:

- `internal-developer-platform/observability/prod/grafana`
- `internal-developer-platform/observability/prod/postgres`
- `internal-developer-platform/observability/prod/ui`

What this means:

- the production observability namespace is already consuming production-scoped secret material through the intended Vault-backed control path
- Slice 5 now has live runtime proof for a second shared production control beyond ingress and cert-manager object reconciliation

### 3. The target production runtime secrets exist with the expected contract shape

Observed target Kubernetes secrets:

- `observability-ui-secrets`
  - type `Opaque`
  - populated keys:
    - `DATABASE_URL`
    - `NEXTAUTH_SECRET`
- `observability-grafana-admin`
  - type `Opaque`
  - populated keys:
    - `admin-user`
    - `admin-password`
- `observability-postgres-app`
  - type `kubernetes.io/basic-auth`
  - populated keys:
    - `username`
    - `password`

What this means:

- the production namespace is not merely holding placeholder `ExternalSecret` manifests
- the rendered secret contracts are being materialized into live runtime objects with the expected key sets
- this is production-style control proof that can be exercised safely while the workload replicas remain intentionally paused

### 4. The current TLS gap should now be treated as an intentional local-runtime constraint for Slice 5

After the secret-delivery proof, the remaining production TLS gap reads more cleanly:

- cert-manager, issuers, ingresses, orders, challenges, and solver objects are live
- production secret delivery is live
- final certificate issuance still depends on environmental factors outside the cluster object model in this local setup

What this means:

- the current blocker is not a missing production control-plane primitive
- for the present local-runtime Phase 8 objective, pending production certificate issuance should be tracked as an external environment constraint unless we explicitly choose to remediate DNS and edge-routing behavior

## Current Slice 5 Classification

Slice 5 now has three distinct proof layers:

- production overlays render cleanly as valid Git contracts
- shared production dependencies are present and reconciling in the cluster
- at least two shared production controls now have live runtime evidence:
  - cert-manager challenge reconciliation
  - Vault-backed production secret delivery

This still does not justify claiming:

- full production ingress readiness
- successful public production certificate issuance
- sustained production workload-runtime proof across the owned applications

## Recommended Next Step

The next Slice 5 step should remain selective and non-disruptive:

1. keep the production TLS issuance gap documented as an environmental local-runtime constraint unless DNS and edge-routing remediation becomes an explicit objective
2. choose the next proof target from shared controls that can be validated without scaling production workloads broadly
3. preserve the distinction among:
   - rendered production contract
   - live shared-control reconciliation
   - active production workload-runtime proof

## Fourth Slice 5 Production GitOps Contract Validation Update

Date: `2026-06-29`

## What This Follow-Up Targeted

This follow-up validated and hardened the central production GitOps contract:

1. verify whether the platform repo currently publishes a production app-of-apps path comparable to the live `dev` path
2. close any central GitOps composition gap without activating live production workloads
3. strengthen the production-path narrative at the deployment-control layer, not only at the manifest-render layer

## Commands Used

```bash
kubectl get applications.argoproj.io -A
find /Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/gitops -maxdepth 3 -type f | sort
for f in /Users/raymond/Documents/DevOps-Easy-Learning/{swiftpay,foodpulse,memflip,opensis,observability-stack}/k8s/argocd/*-prod-application.yaml; do
  sed -n '1,220p' "$f"
done
kubectl apply --dry-run=client -k /Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/gitops/argocd/prod
kubectl apply --dry-run=client -f /Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/gitops/argocd/root/internal-developer-platform-prod-root-application.yaml
```

## Findings

### 1. The live cluster still publishes only the `dev` ArgoCD application set

Observed live `Application` objects:

- `foodpulse-dev`
- `internal-developer-platform-dev-root`
- `memflip-dev`
- `observability-dev`
- `opensis-dev`
- `swiftpay-dev`

What this means:

- the platform had a real and healthy GitOps control path for `dev`
- it did not yet have an equivalent centrally published `prod` app-of-apps contract in the platform repo
- this was a meaningful Slice 5 gap because broader production-path proof should include deployment-control composition, not only per-repo overlay rendering

### 2. The platform repo now carries a centralized production GitOps composition path

Added in the platform repo:

- `gitops/argocd/prod/internal-developer-platform-prod-project.yaml`
- `gitops/argocd/prod/kustomization.yaml`
- `gitops/argocd/prod/observability-prod-application.yaml`
- `gitops/argocd/prod/memflip-prod-application.yaml`
- `gitops/argocd/prod/swiftpay-prod-application.yaml`
- `gitops/argocd/prod/foodpulse-prod-application.yaml`
- `gitops/argocd/prod/opensis-prod-application.yaml`
- `gitops/argocd/root/internal-developer-platform-prod-root-application.yaml`

Design posture used for this contract:

- centralized `prod` `AppProject` scoping for the owned production namespaces
- production child applications point directly at the owned repo `k8s/overlays/prod` paths
- finalizers and environment labels are present consistently
- `CreateNamespace=true` is preserved
- child applications intentionally omit automated sync
- the root `prod` application is present in Git but not applied to the live cluster

What this means:

- Slice 5 now has a production deployment-control contract in the central platform repo rather than only scattered per-repo application manifests
- the current `prod` path is safer and more production-appropriate for this local environment because activation still requires an explicit operator decision

### 3. The new central production GitOps path validates cleanly without touching the running cluster

Validation performed:

- `kubectl apply --dry-run=client -k .../gitops/argocd/prod`
- `kubectl apply --dry-run=client -f .../gitops/argocd/root/internal-developer-platform-prod-root-application.yaml`

What this means:

- the new production GitOps composition path is syntactically valid as Kubernetes and ArgoCD contract material
- this adds real Slice 5 proof at the deployment-governance layer without broadening live production runtime risk

## Current Slice 5 Classification

Slice 5 now has four distinct proof layers:

- production overlays render cleanly as valid Git contracts
- shared production dependencies are present and reconciling in the cluster
- shared production controls have live runtime evidence for TLS challenge reconciliation and Vault-backed secret delivery
- the platform repo now publishes a centralized production GitOps composition path that validates cleanly without activating production workloads

This still does not justify claiming:

- full live production GitOps exercise in-cluster
- successful public production certificate issuance
- sustained production workload-runtime proof across the owned applications

## Sixth Slice 5 Production Namespace-Governance Validation Update

Date: `2026-06-29`

## What This Follow-Up Targeted

This follow-up validated the production namespace-governance contract:

1. determine whether the owned `prod` overlays carry explicit namespace-boundary governance rather than only workload manifests
2. standardize namespace labels where they were inconsistent
3. add missing production `ResourceQuota` contracts without changing the live cluster

## Commands Used

```bash
kubectl get resourcequota,limitrange -A

for repo in swiftpay foodpulse memflip opensis observability-stack; do
  kubectl kustomize "/Users/raymond/Documents/DevOps-Easy-Learning/$repo/k8s/overlays/prod" >/tmp/${repo}-prod-check.yaml
done

kubectl kustomize /Users/raymond/Documents/DevOps-Easy-Learning/swiftpay/k8s/overlays/prod | \
  rg -n "^kind: Namespace$|^kind: ResourceQuota$|app.kubernetes.io/part-of: internal-developer-platform|observability.dev/app:|environment: prod"
kubectl kustomize /Users/raymond/Documents/DevOps-Easy-Learning/foodpulse/k8s/overlays/prod | \
  rg -n "^kind: Namespace$|^kind: ResourceQuota$|app.kubernetes.io/part-of: internal-developer-platform|observability.dev/app:|environment: prod"
kubectl kustomize /Users/raymond/Documents/DevOps-Easy-Learning/memflip/k8s/overlays/prod | \
  rg -n "^kind: Namespace$|^kind: ResourceQuota$|app.kubernetes.io/part-of: internal-developer-platform|observability.dev/app:|environment: prod"
kubectl kustomize /Users/raymond/Documents/DevOps-Easy-Learning/opensis/k8s/overlays/prod | \
  rg -n "^kind: Namespace$|^kind: ResourceQuota$|app.kubernetes.io/part-of: internal-developer-platform|observability.dev/app:|environment: prod"
kubectl kustomize /Users/raymond/Documents/DevOps-Easy-Learning/observability-stack/k8s/overlays/prod | \
  rg -n "^kind: Namespace$|^kind: ResourceQuota$|app.kubernetes.io/part-of: internal-developer-platform|observability.dev/app:|environment: prod"
```

## Findings

### 1. Live namespace-governance enforcement is still largely a `dev`-side reality today

Observed live cluster governance state:

- `swiftpay-dev` has a live `ResourceQuota`
- no live `prod` `ResourceQuota` or `LimitRange` objects are currently present in the cluster

What this means:

- before this pass, production namespace governance was still much weaker as a platform claim than the other Slice 5 proof bands
- this was a Git-contract maturity gap, not a failure in the running `dev` baseline

### 2. All owned production overlays now render explicit namespace objects with stronger shared labeling

Post-hardening production render now includes:

- `Namespace` objects for:
  - `swiftpay-prod`
  - `foodpulse-prod`
  - `memflip-prod`
  - `opensis-prod`
  - `platform-observability-prod`
- standardized shared labels such as:
  - `app.kubernetes.io/part-of: internal-developer-platform`
  - `environment: prod`
  - `observability.dev/app: ...`

What this means:

- the production namespaces now read more like intentional platform boundaries than plain placeholders
- the labeling contract is more coherent for future policy, observability, and governance automation

### 3. Missing production `ResourceQuota` contracts have now been added in Git

Observed post-hardening production render:

- `swiftpay-prod`
  - existing rendered `ResourceQuota` retained
- `foodpulse-prod`
  - `foodpulse-prod-resource-quota` now renders
- `memflip-prod`
  - `memflip-prod-resource-quota` now renders
- `opensis-prod`
  - `opensis-prod-resource-quota` now renders
- `platform-observability-prod`
  - `observability-prod-resource-quota` now renders

What this means:

- the owned production overlays now express explicit namespace consumption boundaries instead of leaving most `prod` namespaces unbounded in Git
- this improves the production-path story at the governance layer without forcing any live production activation

### 4. This remains Git-contract proof, not live production enforcement proof

All five production overlays rendered cleanly after the governance hardening.

However:

- these `prod` quotas and namespace labels have not been applied to a live production application set in this local environment
- the current cluster still proves the `dev` operating baseline more deeply than the `prod` path

What this means:

- Slice 5 now has a stronger production namespace-governance contract in Git
- it still does not justify claiming live production enforcement maturity until a production GitOps path is intentionally activated

## Current Slice 5 Classification

Slice 5 now has six distinct proof layers:

- production overlays render cleanly as valid Git contracts
- shared production dependencies are present and reconciling in the cluster
- shared production controls have live runtime evidence for TLS challenge reconciliation and Vault-backed secret delivery
- the platform repo now publishes a centralized dormant production GitOps composition path that validates cleanly
- the owned apps now present a more coherent production observability network-policy contract, including a corrected SwiftPay `prod` overlay
- the owned production overlays now carry a stronger namespace-governance contract through standardized labels and explicit `ResourceQuota` objects

This still does not justify claiming:

- full live production GitOps exercise in-cluster
- successful public production certificate issuance
- sustained production workload-runtime proof across the owned applications

## Fifth Slice 5 Production Observability Network-Contract Validation Update

Date: `2026-06-29`

## What This Follow-Up Targeted

This follow-up validated the shared production observability access contract:

1. verify that the owned `prod` overlays actually include the intended network-policy posture for observability access
2. confirm whether the cross-repo production scraping contract is coherent rather than repo-specific drift
3. fix any production-only inconsistency without changing the live `dev` runtime

## Commands Used

```bash
for repo in swiftpay foodpulse memflip opensis; do
  kubectl kustomize "/Users/raymond/Documents/DevOps-Easy-Learning/$repo/k8s/overlays/prod" | \
    rg -n "platform-observability-prod|platform-observability-dev|NetworkPolicy|prometheus.io/scrape"
done

sed -n '1,220p' /Users/raymond/Documents/DevOps-Easy-Learning/foodpulse/k8s/base/networkpolicy.yaml
sed -n '1,240p' /Users/raymond/Documents/DevOps-Easy-Learning/memflip/k8s/base/networkpolicy.yaml
sed -n '1,220p' /Users/raymond/Documents/DevOps-Easy-Learning/opensis/k8s/base/networkpolicy.yaml
sed -n '500,760p' /Users/raymond/Documents/DevOps-Easy-Learning/swiftpay/k8s/base/policies/network-policies.yaml

kubectl kustomize /Users/raymond/Documents/DevOps-Easy-Learning/swiftpay/k8s/overlays/prod | \
  rg -n "allow-observability-prometheus-scraping|allow-prometheus-|platform-observability-prod|platform-observability-dev|name: monitoring|15692|9187|9121"
```

## Findings

### 1. The production observability access contract is explicit across the owned app overlays

Observed rendered or base-contract signals:

- `FoodPulse` allows traffic from:
  - `platform-observability-dev`
  - `platform-observability-prod`
  - observability pods including `prometheus`, `blackbox-exporter`, and `devops-monitor-ui`
- `MemFlip` allows observability ingress from:
  - `platform-observability-dev`
  - `platform-observability-prod`
  - `prometheus` and `blackbox-exporter`
- `OpenSIS` allows observability ingress from:
  - `platform-observability-dev`
  - `platform-observability-prod`
  - `prometheus` and `blackbox-exporter`

What this means:

- the production overlays are not merely exposing ingress and TLS posture
- they already encode a cross-namespace observability access model that distinguishes platform monitoring traffic from general east-west traffic

### 2. SwiftPay production carried a stale observability selector model that was worth correcting

Observed pre-fix SwiftPay production render:

- legacy per-service `allow-prometheus-*` network policies were still present
- those policies referenced:
  - `namespaceSelector.matchLabels.name=monitoring`
- this differed from the current shared platform observability namespace contract used elsewhere

What this means:

- SwiftPay production observability access was still relying on an older namespace convention in Git
- leaving that drift in place would have weakened the credibility of the broader Slice 5 production-path claim

### 3. SwiftPay production now renders with the shared observability namespace contract

Production-only hardening added in the SwiftPay repo:

- a single consolidated `allow-observability-prometheus-scraping` network policy in the `prod` overlay
- explicit allowed source namespaces:
  - `platform-observability-dev`
  - `platform-observability-prod`
- explicit allowed observability pods:
  - `prometheus`
  - `blackbox-exporter`
- consolidated metrics ports for:
  - core services
  - `postgres-exporter`
  - `redis-exporter`
  - `rabbitmq`
- overlay-level deletion of the legacy `allow-prometheus-*` production policies during render

Validated post-fix production render:

- `allow-observability-prometheus-scraping` is present
- `platform-observability-dev` and `platform-observability-prod` survive in the rendered policy
- legacy `allow-prometheus-*` objects no longer survive the `prod` overlay render
- the old `name: monitoring` selector no longer survives the `prod` overlay render

What this means:

- the production observability network contract is now more coherent across the owned apps
- the fix improved production-path quality without altering the live `dev` cluster

## Current Slice 5 Classification

Slice 5 now has five distinct proof layers:

- production overlays render cleanly as valid Git contracts
- shared production dependencies are present and reconciling in the cluster
- shared production controls have live runtime evidence for TLS challenge reconciliation and Vault-backed secret delivery
- the platform repo now publishes a centralized dormant production GitOps composition path that validates cleanly
- the owned apps now present a more coherent production observability network-policy contract, including a corrected SwiftPay `prod` overlay

This still does not justify claiming:

- full live production GitOps exercise in-cluster
- successful public production certificate issuance
- sustained production workload-runtime proof across the owned applications
