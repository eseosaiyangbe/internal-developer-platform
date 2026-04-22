# Metrics Strategy

Last updated: 2026-04-22

## Purpose

This document defines the metrics standard for DevOps Easy Learning. The goal is to make the platform observable in a way that is useful for operators, realistic for production environments, and teachable for people following the project.

The stack should answer four questions quickly:

1. Is the control plane healthy?
2. Are the managed applications reachable and meeting basic service objectives?
3. Which dependency is failing when an application is unhealthy?
4. Which business signal proves the application is doing useful work?

## Operating Principles

- Track golden signals first: availability, latency, traffic, errors, and saturation.
- Keep labels bounded. Labels must describe stable dimensions such as `app`, `component`, `route`, `status_code`, `difficulty`, or `score_range`.
- Do not use usernames, emails, request IDs, session IDs, tokens, or free-form text as labels.
- Prefer application metrics for behavior and blackbox probes for user-facing reachability.
- Use recording rules for dashboard and alert queries so the UI is stable and PromQL complexity stays out of the presentation layer.
- Keep local Docker Compose names aligned with the future Kubernetes service model.

## Platform Metrics

The control plane should track these as first-class platform signals:

| Area | Metrics | Why It Matters |
|---|---|---|
| Prometheus | `up`, scrape duration, scrape sample count, rule evaluation failures | Confirms telemetry ingestion is working |
| Alertmanager | active alerts, notification success/failure, alert resolution rate | Confirms incidents can be routed and closed |
| Loki | ingestion rate, query rate, distributor errors | Confirms logs are being accepted and queried |
| Grafana | `up`, HTTP health, version status | Confirms dashboard access |
| Node exporter | CPU, memory, disk, network, filesystem usage | Catches host saturation before app symptoms appear |
| cAdvisor | container CPU, memory, restarts, filesystem pressure | Catches workload resource pressure |
| Blackbox exporter | endpoint success, probe latency, TLS/HTTP health | Confirms user-facing reachability |

## Managed Application Metrics

### SwiftPay

SwiftPay is the flagship microservices and business-transaction workload.

Track:

- API gateway request rate, error rate, p95 latency, and availability.
- Auth-service login/register rate, failures, and latency.
- Wallet balance and transfer operation rate, failures, and latency.
- Transaction completed, failed, pending count, pending amount, and queue depth.
- Notification send success and failure rate.
- Circuit breaker state and dependency failure counters.

Primary recording rules already exist under the `swiftpay:*` namespace.

### OpenSIS

OpenSIS represents a legacy monolith wrapped with platform practices.

Track:

- UI availability and probe latency.
- Apache/PHP request rate, error rate, and latency when an exporter or structured metric path is added.
- MariaDB availability, connections, slow queries, replication or backup status if enabled.
- Vault availability and secret-read path health.
- Login flow health and operator-relevant error patterns from logs.

Current central coverage is blackbox-first. The next production-grade improvement is adding MariaDB and application runtime exporters to the shared observability stack.

### MemFlip

MemFlip represents a lightweight app onboarding story.

Track:

- Frontend and backend blackbox availability.
- Backend request rate, error rate, p95 latency, and application health.
- Completed game submissions by bounded dimensions such as difficulty and score range.
- Active games and completion-time distribution.
- Database and Redis error counters where available.

Implementation status:

- The backend is scraped by central Prometheus through `memflip-backend:3001`.
- Recording rules are namespaced under `memflip:*`.
- Username was removed from the game score metric label set to avoid high-cardinality telemetry.

### FoodPulse

FoodPulse represents resilience, voting behavior, and data-layer failover.

Track:

- UI and API availability.
- API scrape health and process memory.
- Vote rate, page views, leading venue count, and vote persistence.
- PostgreSQL primary/replica health, HAProxy health, Redis Sentinel health, and failover state.
- Future API request rate, error rate, and latency after HTTP middleware metrics are added.

Implementation status:

- The API is attached to `observability-net` as `foodpulse-api`.
- The API is scraped by central Prometheus at `foodpulse-api:4567/metrics`.
- Recording rules are namespaced under `foodpulse:*`.
- HTTP request count, error count, and request-duration histogram metrics are exported by the API with bounded labels.

## Recommended Service Objectives

These are local-lab targets. They are intentionally simple, but they map to production SLO thinking.

| Scope | Objective |
|---|---|
| Control plane | Prometheus, Alertmanager, Loki, Grafana, node exporter, cAdvisor, blackbox exporter are up during demos |
| Managed app endpoint | 99% successful probes over a demo session |
| Managed app latency | p95 blackbox probe latency below 1 second locally |
| SwiftPay transaction flow | Pending transactions return to zero after test traffic |
| MemFlip backend | p95 API latency below 500 ms locally |
| FoodPulse API | scrape is up and vote metrics increase when users vote |
| OpenSIS UI | blackbox probe remains healthy during operator demo |

## Alerting Direction

Alerts should be actionable and tied to runbooks. The preferred pattern is:

- `warning`: symptom is persistent and needs investigation.
- `critical`: customer-facing flow or telemetry foundation is broken.
- Every production-grade alert must include `summary`, `description`, `service`, `severity`, and `runbook_url`.
- Avoid alerts on one-off spikes. Use `for:` durations and recording rules where possible.

## Next Implementation Backlog

1. Add OpenSIS MariaDB exporter coverage to the central stack.
2. Add Vault health and secret-read synthetic checks for OpenSIS.
3. Add app-specific Grafana dashboards based on the new recording rules.
4. Add SLO burn-rate style alerts after the recording rules have enough stable data.
5. Add Kubernetes `ServiceMonitor` or scrape annotations when the project moves to k3s.
