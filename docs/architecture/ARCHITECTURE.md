# Platform Architecture

![Platform architecture: k3s Kubernetes platform with GitOps, secrets, observability, and operator workflows](idp-platform-architecture.png)

This document is the architecture design of record for the Internal Developer Platform. The image above is rendered from the Mermaid source in this file, so the picture and the source never drift apart. It supersedes the Phase 7 architecture screenshot (`output/playwright/phase7/phase7-12-architecture-diagram.png`) as the current design record.

## The design in one paragraph

One platform, not five unrelated applications. Operator and public traffic enter through Cloudflare Tunnel and Traefik ingress into a Kubernetes on k3s runtime. The runtime hosts four managed workloads with deliberately different shapes: SwiftPay (cloud native microservices), Secure OpenSIS (a legacy PHP and MariaDB monolith), FoodPulse (a resilience and failover lab), and MemFlip (a lightweight onboarding workload). Shared capabilities sit below the workloads: HashiCorp Vault as the secret source of truth, delivered through External Secrets for cloud native workloads and Vault Agent injection for the legacy application; a single observability stack (Prometheus, Loki, Grafana, Alertmanager) feeding the control plane application, which presents inventory, comparison, services, alerts, and notifications; and operator workflows (onboarding contract, health workflow, incident matrix and runbooks, and static and live audits kept separate on purpose). Git is the delivery record. Argo CD is the declared GitOps standard; its live activation was rolled back after node runtime instability, and the diagram draws that path dashed because a GitOps controller that cannot be trusted cannot be the delivery record.

## Architecture diagram, Mermaid source

```mermaid
flowchart TB
    Operator["Operator"]
    PublicUser["Public visitor"]

    subgraph Edge["Edge and ingress"]
        CF["Cloudflare Tunnel"]
        Traefik["Traefik ingress"]
    end

    subgraph Cluster["Kubernetes on k3s, the platform runtime"]
        subgraph Workloads["Managed workloads"]
            SwiftPay["SwiftPay<br/>Node.js microservices<br/>PostgreSQL, Redis, RabbitMQ"]
            OpenSIS["Secure OpenSIS<br/>Legacy PHP application<br/>MariaDB"]
            FoodPulse["FoodPulse<br/>Resilience lab<br/>PostgreSQL, Redis, HAProxy"]
            MemFlip["MemFlip<br/>Onboarding workload<br/>Health endpoint as contract"]
        end

        subgraph Secrets["Secrets delivery"]
            Vault["HashiCorp Vault<br/>Source of truth, Kubernetes auth"]
            ExtSecrets["External Secrets<br/>Cloud native workloads"]
            VaultAgent["Vault Agent injection<br/>Legacy workloads"]
        end

        subgraph Observability["Observability stack"]
            Prom["Prometheus<br/>Metrics"]
            Loki["Loki<br/>Logs"]
            Grafana["Grafana<br/>Dashboards"]
            Alertm["Alertmanager<br/>Alert routing"]
        end

        ControlPlane["Control plane application<br/>Inventory, comparison, services,<br/>alerts, notifications"]
    end

    subgraph Delivery["Delivery, Git as the record"]
        Git["Git repositories<br/>App structure, Helm and Kustomize,<br/>runbooks, desired state"]
        ArgoCD["Argo CD<br/>Declared GitOps standard<br/>Live activation rolled back"]
    end

    subgraph Ops["Operator workflows"]
        Onboard["Onboarding contract<br/>Setup, health, telemetry,<br/>secrets path, operator guide"]
        Health["Health workflow<br/>Node, workloads, GitOps, Vault,<br/>ingress, Prometheus, alerts"]
        Incident["Incident matrix and runbooks<br/>Symptom to checks to runbook"]
        Audits["Static audits and live audits<br/>Kept separate on purpose"]
    end

    PublicUser --> CF
    Operator --> CF
    CF --> Traefik
    Traefik --> SwiftPay
    Traefik --> OpenSIS
    Traefik --> FoodPulse
    Traefik --> MemFlip
    Traefik --> ControlPlane

    Git -.-> ArgoCD
    ArgoCD -.->|"declared reconciliation path"| Workloads
    Git -->|"structure and configuration"| Workloads

    Vault --> ExtSecrets
    Vault --> VaultAgent
    ExtSecrets --> SwiftPay
    ExtSecrets --> FoodPulse
    ExtSecrets --> MemFlip
    VaultAgent --> OpenSIS

    SwiftPay -->|"metrics and logs"| Prom
    OpenSIS -->|"metrics and logs"| Prom
    FoodPulse -->|"metrics and logs"| Prom
    MemFlip -->|"metrics and logs"| Prom
    SwiftPay --> Loki
    OpenSIS --> Loki
    FoodPulse --> Loki
    MemFlip --> Loki
    Prom --> Grafana
    Prom --> Alertm
    Grafana --> ControlPlane
    Alertm --> ControlPlane
    ControlPlane --> Operator

    Onboard -->|"a workload joins through the contract"| Workloads
    Health --> Cluster
    Incident --> Workloads
    Audits --> Cluster
```

## Flow diagram: how a workload joins and is operated, Mermaid source

```mermaid
flowchart LR
    A["New workload"] --> B["Adopt the onboarding contract<br/>Setup expectations, ports, aliases"]
    B --> C["Add the health endpoint<br/>Metrics and logs expectations"]
    C --> D["Choose the secrets path<br/>External Secrets or Vault Agent"]
    D --> E["Join the shared inventory<br/>Control plane application"]
    E --> F["Operate through the health workflow<br/>One sequence, whole platform"]
    F --> G{"Incident or drill"}
    G --> H["Incident matrix<br/>Symptom to workload to runbook"]
    H --> I["Recovery validation<br/>Vault, GitOps, ingress,<br/>monitoring, active alerts"]
    I --> F
```

## Notes

- Audit counts and validation evidence for this design live in the platform case study and the Phase 6 and Phase 7 records in this repository. They are lab validation audits, point in time, not production service level results.
- The control plane application is provided by the `Obervability-Stack` repository and runs at `https://portfolio.eseosadevbox.com`.
