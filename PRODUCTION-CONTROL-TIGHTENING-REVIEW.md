# Production-Control Tightening Review

This document records the post-GitOps production-control review for the owned platform as of `2026-05-21`.

It is intended to answer one specific Phase 7 question:

- after GitOps activation and validation, what production-style controls are already credible,
- what is acceptable for Phase 7 but not yet final production posture,
- and what still needs explicit follow-up before Phase 7 can be closed honestly?

## Scope

The review covers:

- `Obervability-Stack`
- `OpenSIS`
- `SwiftPay`
- `FoodPulse`
- `MemFlip`
- the central `internal-developer-platform` GitOps composition

The review evaluates both:

- repository-defined controls
- current live local `k3s` runtime truth where that truth materially affects the claim

## Commands Used

Cluster truth checks:

```bash
kubectl get applications -n argocd -o wide
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get ns | rg 'cert-manager|platform-observability-prod|memflip-prod|swiftpay-prod|foodpulse-prod|opensis-prod|argocd' || true
kubectl get clusterissuer,issuer 2>/dev/null || true
kubectl get pvc -n platform-observability-dev
kubectl get pvc -n memflip-dev
kubectl get pvc -n swiftpay-dev
kubectl get pvc -n foodpulse-dev
kubectl get pvc -n opensis-dev
```

Repository control sweep:

```bash
for repo in observability-stack opensis swiftpay foodpulse memflip; do
  rg -n "kind: HorizontalPodAutoscaler|kind: PodDisruptionBudget|topologySpreadConstraints|podAntiAffinity|spec:\\s*tls|cert-manager.io/cluster-issuer|emptyDir:|StatefulSet|ClusterIssuer|networking.k8s.io/v1" \
    /Users/raymond/Documents/DevOps-Easy-Learning/$repo/k8s -g '*.yaml' -g '*.yml' | head -n 200
done
```

Reference documents reviewed:

- [PROD-OVERLAY-AUDIT.md](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/PROD-OVERLAY-AUDIT.md)
- [ENVIRONMENT-MODEL.md](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/ENVIRONMENT-MODEL.md)
- [PHASE7-REMAINING-WORK-CHECKLIST.md](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/PHASE7-REMAINING-WORK-CHECKLIST.md)
- [PROJECT-ROADMAP.md](/Users/raymond/Documents/DevOps-Easy-Learning/internal-developer-platform/PROJECT-ROADMAP.md)

## Current Verdict

The platform now has a credible production-style control story for Phase 7.

That does not mean the platform is “production-complete” in a strict enterprise sense.

It does mean:

- GitOps is now the default reconciler for the owned `dev` paths
- the owned workloads have explicit production overlay control posture in Git
- the cluster is currently healthy and converged
- the platform can now be described honestly as production-style, not just migration-in-progress

## What Is Strong Already

### 1. GitOps ownership is now real

Live truth:

- `argocd` is active
- root app is active
- all `dev` child applications are `Synced` and `Healthy`

This closes the previous gap where ArgoCD was a documented standard but not yet the default reconciler.

### 2. Secrets and ingress posture are explicit

Repository and cluster truth now support these claims:

- Vault-first secrets are the intended source of truth
- External Secrets delivery is part of the runtime path
- `cert-manager` is installed in the cluster
- `letsencrypt-prod` and `letsencrypt-staging` `ClusterIssuer`s are live and `Ready`
- production overlays explicitly reference TLS and issuer posture

This means the TLS and secret-delivery story is no longer hypothetical.

### 3. Availability controls exist across the owned overlays

The repo now has explicit:

- `HorizontalPodAutoscaler` posture
- `PodDisruptionBudget` posture
- anti-affinity guidance
- topology-spread guidance

This is no longer concentrated only in `SwiftPay`.

### 4. Stateful development workloads have durable storage

Live dev PVCs are bound for:

- `Obervability-Stack`
- `MemFlip`
- `SwiftPay`
- `FoodPulse`
- `OpenSIS`

That does not make the platform fully durable in a production sense, but it does prove state is not being treated casually at the current operating level.

### 5. Network isolation is not an afterthought

All workload repos expose explicit `NetworkPolicy` posture in Kubernetes.

This is a strong signal because it means:

- ingress intent is declared
- cross-service paths are constrained intentionally
- observability scraping paths are modeled explicitly

## What Is Acceptable For Phase 7 But Not Final Production Posture

These are acceptable for the current phase, but they should not be overstated.

### 1. Local single-node reality still shapes the platform

Even with production-style controls in Git, the live environment is still:

- local
- single-node
- `Colima`-backed

That means:

- anti-affinity is mostly intent signaling
- topology spread is mostly portability signaling
- true multi-node or multi-zone resilience is not yet proven live

### 2. Some production overlays are credible contracts, not fully exercised runtime paths

Examples:

- production HPAs exist in Git
- production PDBs exist in Git
- TLS and issuer posture exist in Git

But the active day-to-day validation cluster is still the owned `dev` environment.

That is acceptable for Phase 7 as long as we say it plainly.

### 3. OpenSIS remains intentionally conservative

This is the right posture, not a flaw.

`OpenSIS` is a legacy-sensitive workload with:

- legacy runtime assumptions
- startup sensitivity
- a narrower safe scaling profile

The repo now has the right kind of cautious production posture for `OpenSIS`, but it should not be marketed as horizontally mature in the same way as the lighter services.

## Remaining Gaps

These are the real remaining issues.

### 1. Observability durability is still mixed

Repository evidence still shows `emptyDir` in important control-plane areas, including:

- Grafana
- Alertmanager
- Promtail positions
- parts of the UI/init path

This means the observability plane is operationally useful and portfolio-credible, but not yet hardened for stronger persistence guarantees.

### 2. Multi-node placement is still policy intent, not proven behavior

Current placement posture is mostly:

- preferred anti-affinity
- hostname topology spread
- `ScheduleAnyway`

That is the correct portable baseline, but not the same as:

- required anti-affinity
- zone-aware spread
- node-pool segregation
- stronger HA guarantees

### 3. ArgoCD access is still operator-local

Current access path:

- local port-forward to `argocd-server`

That is perfectly acceptable for the current local platform, but it is not a full production access model with:

- ingress
- SSO
- audited access flow

### 4. Production namespaces are not the main validated runtime

The platform has a production overlay model, but the validated operating baseline remains `dev`.

That means the production narrative is:

- strong in Git
- strong architecturally
- partial in live operational exercise

### 5. Local runtime capacity remains a real operational constraint

Recent activation work proved that:

- `metrics-server` can flap under local runtime pressure
- `Colima` restart can still be the decisive recovery step during severe churn
- shared `dev` plus extra local `prod` footprint can create pressure on the single-node environment

This is a real operational constraint and should remain documented honestly.

## Control Classification

### Strong and defensible now

- GitOps as the default reconciler for owned `dev`
- Vault-first secret delivery model
- cert-manager and shared issuer contract
- public ingress model
- repo-wide HPA/PDB/placement posture
- explicit network-policy posture
- stateful PVC-backed dev runtime

### Acceptable for Phase 7

- production overlays as the main production-control expression
- single-node local validation of a production-style platform
- conservative `OpenSIS` production posture
- ArgoCD local port-forward access

### Should be treated as remaining work

- stronger observability durability
- stronger production access model for ArgoCD
- more explicit multi-node and zone-aware placement rules
- clearer line between “prod overlay exists” and “prod runtime has been exercised deeply”

## Recommendation

Phase 7 should not be blocked on perfect production parity.

The right next move is:

1. complete documentation closeout using this review
2. make the formal Phase 7 closeout decision
3. classify the remaining durability and deeper production rigor work as the opening operational scope of Phase 8

## Final Assessment

The platform is now past the point where the primary story is “platform assembly.”

The primary story is now:

- controlled operation
- Git-driven reconciliation
- explicit production-style contracts
- honest identification of what is still maturing

That is a credible Phase 7 end-state.
