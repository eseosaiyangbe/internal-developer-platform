# Incident Response Log

This file is the dedicated incident response record for the DevOps Easy Learning project.

Going forward:

- `JOURNEY-RUNBOOK.md` remains the broad project journey and implementation runbook.
- `INCIDENT-RESPONSE.md` records operational incidents, alert investigations, root causes, mitigations, validation, and follow-up actions.
- Every incident entry should include the user-visible symptom, commands run, evidence found, root cause, fix, verification, and remaining risk.

## Incident Template

```text
Incident ID:
Date:
Severity:
Status:
Primary service:
Detected by:
User-visible symptom:
Impact:
Root cause:
Fix:
Verification:
Follow-up:
```

## IR-2026-04-20-001 - HighContainerCPUUsage on cAdvisor

### Summary

Alertmanager showed:

```text
HighContainerCPUUsage
High container CPU usage on cadvisor
Firing
Warning
Service: containers
Value: 80%
Duration: 5m
Description: Container CPU usage is above 80% on cadvisor
```

Important labels:

```text
alertname=HighContainerCPUUsage
component=cpu
cpu=total
id=/
instance=cadvisor
job=cadvisor
service=containers
severity=warning
```

### Status

Resolved.

Prometheus no longer reported the alert as active when investigated:

```text
HighContainerCPUUsage: no active alerts
```

### Impact

No live application impact was found.

Current container CPU usage was normal during investigation. cAdvisor itself was around `1%` CPU, and the highest visible app containers were well below the warning threshold.

### Commands Run

Checked active Prometheus alerts:

```bash
curl -fsS 'http://localhost:9090/api/v1/alerts' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); const alerts=j.data.alerts.filter(a=>a.labels.alertname==="HighContainerCPUUsage"); if (!alerts.length) console.log("HighContainerCPUUsage: no active alerts"); for (const a of alerts) console.log(JSON.stringify({state:a.state,value:a.value,labels:a.labels,annotations:a.annotations,activeAt:a.activeAt},null,2));})'
```

Searched the Prometheus rules and cAdvisor scrape config:

```bash
rg -n "HighContainerCPUUsage|container_cpu|cadvisor|id=\"/\"" Obervability-Stack/prometheus -g '*.{yml,yaml}'
```

Queried cAdvisor CPU usage from Prometheus:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=sort_desc(rate(container_cpu_usage_seconds_total%7Bjob%3D%22cadvisor%22%7D%5B5m%5D)%20*%20100)' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); for (const r of j.data.result.slice(0,20)) console.log(`${Number(r.value[1]).toFixed(2)} ${r.metric.name||r.metric.container_label_com_docker_compose_service||r.metric.id||"unknown"} id=${r.metric.id||""}`);})'
```

Checked live Docker CPU usage:

```bash
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'
```

Inspected the alert rule:

```bash
sed -n '210,250p' Obervability-Stack/prometheus/alert_rules.yml
```

Inspected the container recording rule:

```bash
sed -n '20,36p' Obervability-Stack/prometheus/recording_rules.yml
```

Checked whether cAdvisor exposed named container CPU series:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=sort_desc(rate(container_cpu_usage_seconds_total%7Bjob%3D%22cadvisor%22%2Cid%21%3D%22%2F%22%2Cname%21%3D%22%22%7D%5B5m%5D)%20*%20100)' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); if (!j.data.result.length) console.log("no named container cpu series"); for (const r of j.data.result.slice(0,20)) console.log(`${Number(r.value[1]).toFixed(2)} ${r.metric.name||r.metric.container_label_com_docker_compose_service||"unknown"} id=${r.metric.id||""}`);})'
```

Checked whether cAdvisor exposed Docker Compose service labels:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=sort_desc(rate(container_cpu_usage_seconds_total%7Bjob%3D%22cadvisor%22%2Ccontainer_label_com_docker_compose_service%21%3D%22%22%7D%5B5m%5D)%20*%20100)' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); if (!j.data.result.length) console.log("no compose service cpu series"); for (const r of j.data.result.slice(0,20)) console.log(`${Number(r.value[1]).toFixed(2)} ${r.metric.container_label_com_docker_compose_service||r.metric.name||"unknown"} id=${r.metric.id||""}`);})'
```

Listed the cAdvisor CPU metric series:

```bash
curl -fsS 'http://localhost:9090/api/v1/series?match[]=container_cpu_usage_seconds_total%7Bjob%3D%22cadvisor%22%7D' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(`series=${j.data.length}`); for (const s of j.data.slice(0,20)) console.log(JSON.stringify(s));})'
```

Listed cAdvisor CPU `id` label values:

```bash
curl -fsS 'http://localhost:9090/api/v1/label/id/values?match[]=container_cpu_usage_seconds_total%7Bjob%3D%22cadvisor%22%7D' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(j.data.slice(0,50).join("\n"));})'
```

Listed cAdvisor CPU `name` label values:

```bash
curl -fsS 'http://localhost:9090/api/v1/label/name/values?match[]=container_cpu_usage_seconds_total%7Bjob%3D%22cadvisor%22%7D' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(j.data.slice(0,50).join("\n") || "no name labels");})'
```

Validated Prometheus rules after the fix:

```bash
docker exec prometheus promtool check rules /etc/prometheus/alert_rules.yml
```

Reloaded Prometheus:

```bash
curl -fsS -X POST -w 'prometheus_reload %{http_code}\n' http://localhost:9090/-/reload -o /tmp/prometheus-reload.txt
```

Checked active alerts again:

```bash
curl -fsS 'http://localhost:9090/api/v1/alerts' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); const alerts=j.data.alerts.filter(a=>a.labels.alertname==="HighContainerCPUUsage"); if (!alerts.length) console.log("HighContainerCPUUsage: no active alerts"); for (const a of alerts) console.log(`${a.labels.alertname} ${a.state} ${a.value}`);})'
```

Checked the updated non-root expression:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=rate(container_cpu_usage_seconds_total%7Bid%21%3D%22%2F%22%7D%5B5m%5D)%20*%20100' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(`non_root_series=${j.data.result.length}`);})'
```

Verified core alerting services:

```bash
docker compose ps prometheus cadvisor alertmanager
```

### Evidence

Prometheus had no active `HighContainerCPUUsage` alert when checked:

```text
HighContainerCPUUsage: no active alerts
```

The broad cAdvisor CPU query showed only the root cgroup:

```text
63.31 / id=/
```

cAdvisor exposed only one CPU metric series:

```json
{"__name__":"container_cpu_usage_seconds_total","cpu":"total","id":"/","instance":"cadvisor","job":"cadvisor"}
```

There were no named container CPU series:

```text
no named container cpu series
```

There were no Docker Compose service-labeled CPU series:

```text
no compose service cpu series
```

Live `docker stats` showed normal CPU:

```text
cadvisor: 1.16%
prometheus: 2.04%
devops-monitor-ui: 0.00%
```

Some FoodPulse database/Redis containers were active but still far below the alert threshold:

```text
foodpulse-api: 9.66%
foodpulse-db-replica1: 4.98%
foodpulse-db-replica2: 4.73%
foodpulse-db-replica3: 4.93%
```

### Root Cause

The alert rule was too broad:

```promql
(rate(container_cpu_usage_seconds_total[5m]) * 100) > 80
```

On this Docker Desktop setup, cAdvisor was exposing only the root cgroup CPU metric:

```text
id="/"
```

That root cgroup is not a specific application container. It can spike during heavy local work such as Docker image builds. We had just rebuilt OpenSIS and the monitoring UI, so the alert likely fired because the root cgroup crossed the threshold during build activity.

### Fix

Changed the `HighContainerCPUUsage` rule to exclude the root cgroup:

```promql
(rate(container_cpu_usage_seconds_total{id!="/"}[5m]) * 100) > 80
```

This keeps the alert available for real container-level CPU series, but prevents the root aggregate from creating a misleading "container CPU" alert.

### Verification

Prometheus rule validation passed:

```text
SUCCESS: 40 rules found
```

Prometheus reload worked:

```text
prometheus_reload 200
```

The alert stayed resolved:

```text
HighContainerCPUUsage: no active alerts
```

The fixed expression has no non-root container CPU series in the current local Docker Desktop cAdvisor setup:

```text
non_root_series=0
```

That is acceptable for this fix because it prevents the root cgroup from producing a misleading container alert. The follow-up is to improve cAdvisor's local container metric visibility if we want per-container CPU alerting before Kubernetes.

Core alerting services remained healthy:

```text
prometheus: healthy
cadvisor: healthy
alertmanager: healthy
```

### Follow-Up

Investigate why this local Docker Desktop cAdvisor deployment only exposes the root cgroup CPU series. If we want richer per-container CPU alerting in local Compose, cAdvisor may need additional host mounts, permissions, or Docker Desktop-specific tuning.

When we move to Kubernetes, prefer kube-state-metrics/cAdvisor/kubelet container metrics from the cluster path rather than relying on this local Docker Desktop behavior.
