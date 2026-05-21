# Phase 7 Remaining Work Checklist

This checklist translates late Phase 7 into concrete execution steps.

Use it as the operational closeout plan for:

- roadmap reconciliation
- GitOps activation
- final production-style tightening
- formal Phase 7 closeout

## Current Position

What is already true:

- the workload migration set is complete
- the control plane is live
- the child repo split is complete
- the platform identity migration is complete
- public ingress is live
- Cloudflare Access is working for the protected observability services
- Phase 7 `k3s` `dev` certification already exists

What is not yet true:

- ArgoCD is now the default reconciler for the owned `dev` paths
- the platform has completed an initial GitOps validation pass across workload, app baseline, and shared platform categories
- Phase 7 is not yet formally closed
- production-control tightening and formal closeout are still pending

## Remaining Work

### 1. GitOps Activation

Objective:

- make ArgoCD the default reconciler for the owned Kubernetes paths

Status:

- Completed on `2026-05-20` and `2026-05-21`

Tasks:

- verify all child-repo ArgoCD manifests still point to the correct post-split repo locations
- define the root GitOps ownership model explicitly:
  - child repos own workload-local manifests
  - central repo owns root orchestration and environment composition
- install or reconcile the root ArgoCD application set against the live cluster
- switch normal day-two updates from direct `kubectl apply` to Git-driven reconciliation
- document drift-handling and rollback expectations

Success criteria:

- ArgoCD can reconcile the owned paths from Git without manual manifest copying
- the platform can prove desired-state ownership from Git, not from ad hoc shell execution
- the default explanation for deployments becomes GitOps-first

### 2. GitOps Validation Pass

Objective:

- prove GitOps actually works under the current repo model

Status:

- Completed initial pass on `2026-05-20` and `2026-05-21`

Tasks:

- perform one controlled Git-driven change in each category:
  - workload app
  - observability/control-plane
  - shared platform primitive
- verify ArgoCD sync, health, and drift behavior
- verify the control plane remains honest during reconciliation
- capture the exact operator sequence and evidence

Success criteria:

- at least one successful end-to-end GitOps reconciliation is documented
- drift detection is demonstrated and understood
- rollback or re-sync behavior is validated at least once

### 3. Production-Control Tightening Review

Objective:

- decide what still belongs to late Phase 7 versus what should become Phase 8

Tasks:

- review whether current `prod` posture is sufficient for a credible portfolio claim
- re-check:
  - PDBs
  - HPAs
  - placement constraints
  - TLS contract
  - observability durability posture
  - access-control boundaries
- identify any remaining placeholder or incomplete production assumptions

Success criteria:

- remaining production gaps are explicitly classified
- no material “pretend prod” claims remain undocumented

### 4. Documentation Closeout

Objective:

- make the platform story easy to follow for a new reader

Tasks:

- ensure root docs reflect the current multi-repo model consistently
- link the main roadmap to:
  - repo model
  - certification
  - Cloudflare recovery procedure
  - production audit
- add a short “where we are now” closeout note after GitOps activation

Success criteria:

- a new reader can understand:
  - what exists
  - what is authoritative
  - what remains
  - what phase the platform is actually in

### 5. Formal Phase 7 Closeout Decision

Objective:

- decide whether GitOps activation closes Phase 7 or opens Phase 8

Decision rule:

- close Phase 7 if:
  - GitOps is active enough to be the default reconciler story
  - the production-style narrative is honest and documented
  - the remaining work is mostly operational maturity, not foundational platform construction

- open Phase 8 if:
  - GitOps remains partial or optional
  - the next major work is about deeper operational rigor rather than platform assembly

## Recommended Execution Order

1. production-control tightening review
2. documentation closeout
3. formal Phase 7 closeout decision

## Definition Of Done

Phase 7 can be considered operationally complete when:

- the platform is multi-repo and stable
- ArgoCD is the default reconciler for the owned paths
- the control plane, public ingress, and protected observability surfaces all work under the new structure
- production-style constraints are documented honestly
- the remaining roadmap story is no longer “build the platform” but “operate and mature the platform”
