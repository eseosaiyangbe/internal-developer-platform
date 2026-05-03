# Production TLS With cert-manager

## Purpose

This document defines the current production TLS direction for the owned Kubernetes overlays in this workspace.

The chosen path is:

- `cert-manager`
- Let's Encrypt ACME issuers
- Traefik ingress controller
- per-app TLS secrets created by cert-manager through ingress-shim behavior

This applies to:

- `MemFlip`
- `SwiftPay`
- `FoodPulse`
- `OpenSIS`
- `Obervability-Stack`

## Why This Path

This workspace already standardizes on:

- shared `k3s` runtime patterns
- Traefik ingress
- Vault for secrets
- ArgoCD-oriented deployment structure

For TLS, the cleanest production-quality direction is:

- keep certificate issuance outside app repos
- keep TLS attached to ingress contracts
- let cert-manager own issuance and renewal lifecycle

That gives us:

- a consistent issuer model
- automatic renewal
- explicit ingress-to-certificate mapping
- a reusable platform pattern across every workload slice

## What Is In The Repo Now

### Shared cert-manager platform manifests

- [k8s/platform/cert-manager/kustomization.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/k8s/platform/cert-manager/kustomization.yaml)
- [k8s/platform/cert-manager/clusterissuer-letsencrypt-staging.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/k8s/platform/cert-manager/clusterissuer-letsencrypt-staging.yaml)
- [k8s/platform/cert-manager/clusterissuer-letsencrypt-prod.yaml](/Users/raymond/Documents/DevOps-Easy-Learning/k8s/platform/cert-manager/clusterissuer-letsencrypt-prod.yaml)

### Install helper

- [scripts/install-cert-manager.sh](/Users/raymond/Documents/DevOps-Easy-Learning/scripts/install-cert-manager.sh)

This helper:

- installs cert-manager via Helm
- waits for the core deployments
- applies both staging and production ClusterIssuers
- requires an explicit `--email` so ACME registration is not hidden

## Current Ingress Contract

The production overlays now assume cert-manager will issue the TLS secrets referenced by the ingresses.

ClusterIssuer annotation standard:

- `cert-manager.io/cluster-issuer: letsencrypt-prod`

Traefik entrypoint standard:

- `traefik.ingress.kubernetes.io/router.entrypoints: web,websecure`

Each production ingress now carries:

- explicit production hostnames
- explicit `spec.tls`
- a concrete TLS secret name

## Installation Workflow

Run:

```bash
./scripts/install-cert-manager.sh --email you@example.com
```

If cert-manager is already installed and you only need to re-apply issuers with a new email:

```bash
./scripts/install-cert-manager.sh --email you@example.com --skip-install
```

## Important Production Notes

### 1. Placeholder email must be replaced

The checked-in ClusterIssuer manifests use `platform@example.com` only as a template value.

They are not meant to be applied unchanged in a real production environment.

### 2. Real DNS must already point at the ingress layer

Let's Encrypt HTTP-01 will not work unless the production hostnames already resolve to the Traefik ingress entrypoint.

### 3. This does not eliminate the need for ingress ownership decisions

TLS issuance is now standardized, but production still needs clear decisions for:

- public DNS ownership
- certificate lifecycle monitoring
- renewal failure alerting
- ingress exposure model per environment

## Remaining Follow-Up

After cert-manager is in place, the next production-hardening slice should be:

1. anti-affinity and topology spread constraints
2. stronger persistence posture for stateful observability components
3. production alerting for certificate expiry and renewal failures
