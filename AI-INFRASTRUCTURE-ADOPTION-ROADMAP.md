# AI Infrastructure Adoption Roadmap

Date: `2026-06-29`

## Purpose

This roadmap defines how the Internal Developer Platform becomes AI-infrastructure aware without weakening operator control, cluster safety, or platform credibility.

This is not a generic chatbot plan.

It is a platform-operating plan for introducing a self-hosted AI agent into a real local Kubernetes lab in a way that remains:

- private
- observable
- reversible
- approval-bound
- production-minded

## Executive Decision

The correct strategic model is:

1. self-host upstream Hermes as the agent runtime
2. retain the current repo-local Hermes script as the trusted platform tool boundary
3. keep all cluster interaction read-only by default
4. require explicit manual operator approval for any proposed change

This means:

- upstream Hermes becomes the orchestrator
- the current `scripts/hermes-agent.py` becomes the cluster-facing control adapter
- mutation remains outside the agent unless a later phase explicitly approves a stronger control model

## Why This Is The Right Approach

The platform already has the right control-plane primitives:

- Kubernetes runtime visibility
- ArgoCD health and sync surfaces
- Vault-backed secret management
- observability and incident context
- runbooks and drill evidence

What is missing is not raw infrastructure.

What is missing is an AI control layer that can:

- interpret status quickly
- summarize operator context
- accelerate incident-note creation
- recommend next steps

The wrong move would be to let an agent mutate the platform directly before we have earned that trust boundary.

The right move is to let AI observe first, recommend second, and act only later if a stronger governance model is deliberately designed.

## Architecture Direction

### Target Model

- upstream Hermes runtime
  - self-hosted on the operator machine first
  - private access only
  - persistent memory and session layer
  - optional scheduling and gateway later
- repo-local Hermes platform adapter
  - `scripts/hermes-agent.py`
  - read-only Kubernetes and ArgoCD inspection
  - incident-note and remediation rendering
  - explicit refusal of automatic mutation
- human operator approval boundary
  - all recommended actions are reviewed and run manually
  - no direct `kubectl apply`, `patch`, `delete`, or ArgoCD sync operations exposed to the agent initially

### Design Principle

The AI runtime and the cluster control surface must remain separate concerns.

That gives us:

- safer failure boundaries
- clearer auditability
- easier rollback
- less naming and responsibility confusion

## Non-Negotiable Guardrails

These guardrails are mandatory for the first adoption path:

1. no internet-facing Hermes surface in the initial rollout
2. no direct cluster mutation from the AI runtime
3. no direct Vault write access from the AI runtime
4. no ArgoCD suspend, resume, sync, or refresh privileges from the AI runtime
5. all AI outputs must be explainable as:
   - observation
   - summary
   - recommendation
   - proposed manual command

These are not optional convenience constraints.

They are what keep the AI layer from undermining the platform story we have already built.

## Adoption Phases

The adoption should be executed in six ordered phases.

### Phase A1. Naming And Control-Boundary Cleanup

Goal:

- remove ambiguity between the upstream Hermes runtime and the current repo-local Hermes script

Why this must happen first:

- today the platform has a local tool called `Hermes Agent`
- we also intend to introduce upstream Hermes as a self-hosted runtime
- leaving both under the same identity will create operator confusion and architectural drift

Required outputs:

- rename the current platform script to a boundary-specific identity such as:
  - `hermes-control`
  - or `idp-hermes-control`
- update docs, aliases, and command references
- document the distinction between:
  - AI runtime
  - platform control adapter

Definition of done:

- no ambiguity remains about which Hermes component does what
- the read-only platform adapter has a stable identity

### Phase A2. Upstream Hermes Local Self-Hosting

Goal:

- run upstream Hermes privately on the local operator machine

Scope:

- local-only runtime
- no public endpoint
- no messaging gateway yet
- no cluster mutation privileges

Required outputs:

- upstream Hermes installed and runnable locally
- runtime persistence path defined
- model-provider choice documented
- startup and stop procedure documented
- local security posture documented

Definition of done:

- upstream Hermes runs on the machine reliably
- it can be restarted without workspace confusion
- it is not exposed publicly

### Phase A3. Read-Only Tool Integration

Goal:

- let upstream Hermes use the repo-local platform adapter as a tool layer

Scope:

- health inspection
- ArgoCD summary
- log reads
- incident-note generation
- remediation proposals

Required outputs:

- upstream Hermes can call the platform adapter
- command outputs are structured enough for reliable summarization
- read-only behavior is preserved end to end

Definition of done:

- a prompt through upstream Hermes can trigger:
  - cluster health summary
  - ArgoCD sync summary
  - log retrieval
  - incident-note generation
- no cluster mutation path exists

### Phase A4. Incident Intelligence And Memory Discipline

Goal:

- make the AI layer useful for operations, not just interactive demos

Scope:

- incident-note templates
- severity-based summaries
- app-aware heuristics
- optional note persistence

Required outputs:

- structured incident-note templates for:
  - cluster health degradation
  - ArgoCD comparison or sync anomalies
  - workload restart storms
  - ingress or TLS path incidents
- app-specific heuristics for:
  - `SwiftPay`
  - `FoodPulse`
  - `OpenSIS`
  - `MemFlip`
  - `observability-stack`
- rules for what memory Hermes may retain locally

Definition of done:

- Hermes produces useful operator notes faster than manual drafting
- incident summaries are scoped and technically credible
- memory behavior is documented and bounded

### Phase A5. Private Remote Access And Scheduling

Goal:

- make Hermes available beyond a single active terminal session without making it public

Scope:

- private access only
- optional scheduled reporting
- optional heartbeat or daily status notes

Required outputs:

- approved remote access model:
  - Tailscale preferred
  - SSH-only acceptable
  - private local gateway optional
- scheduled read-only jobs for:
  - morning cluster summary
  - ArgoCD drift summary
  - incident-note prefill when warnings appear

Definition of done:

- Hermes can be reached privately from a trusted operator path
- scheduled reports remain read-only and bounded

### Phase A6. Governance Review For Higher-Trust Actions

Goal:

- decide whether Hermes should ever move beyond read-only behavior

This is a review phase, not an implementation promise.

Possible future options:

- remain permanently read-only
- allow generated runbooks only
- allow proposed command bundles only
- allow staged changes in a sandboxed dry-run lane

Not allowed in this phase without explicit redesign:

- direct `kubectl apply`
- direct `kubectl patch`
- direct `kubectl delete`
- direct ArgoCD sync or rollback
- direct Vault writes

Definition of done:

- a conscious governance decision exists
- either the platform stays read-only for AI control
- or a new higher-trust design is approved as a separate roadmap

## Recommended Execution Order

The immediate correct order is:

1. Phase A1
2. Phase A2
3. Phase A3
4. Phase A4
5. Phase A5
6. Phase A6

Do not skip A1.

Do not expose upstream Hermes publicly before A3 and A4 are complete.

Do not attempt write-capable automation before A6.

## What We Should Explicitly Avoid

These are tempting shortcuts, but they are the wrong engineering choices:

- exposing Hermes on the public internet early
- giving Hermes raw `kubectl` write access
- letting Hermes talk directly to Vault with write-capable credentials
- mixing upstream Hermes runtime code into the same responsibility layer as the platform adapter
- calling the project “AI-enabled” before the trust boundary is documented and verified

## Success Criteria

This AI-infrastructure track will be successful when:

- the platform has a private self-hosted AI runtime
- the runtime can interpret real platform signals
- the runtime can generate credible operator notes and suggestions
- the cluster control boundary remains read-only by default
- the AI story strengthens the platform’s credibility instead of weakening it

## Immediate Next Step

Proceed with **Phase A1: Naming And Control-Boundary Cleanup**.

That means:

- rename the current repo-local Hermes command surface so it is clearly the platform control adapter
- preserve its read-only guardrail
- document the runtime-versus-adapter distinction before introducing upstream Hermes itself

## Final Position

The AI-infrastructure-aware version of this project should be built as:

- a self-hosted AI runtime
- a separate trusted read-only platform adapter
- a manual-approval operating model
- a private operator tool, not a public autonomous controller

That is the strongest, safest, and most technically credible path for this project.
