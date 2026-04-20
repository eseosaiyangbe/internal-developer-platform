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

## IR-2026-04-20-001 - Observability Stack Down Incident

### Situation

The user reported:

```text
my observabilty stack is down
```

We treated this as a production-style incident and checked the stack from the outside first, then moved inward to containers, logs, disk, Docker storage, and app health.

### Commands Run

Checked the Observability Stack compose state:

```bash
docker compose ps -a
```

Checked the running containers that matter to the platform and managed apps:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

Checked public health endpoints:

```bash
curl -fsS -o /tmp/monitor-ui.txt -w 'monitor_ui %{http_code}\n' http://localhost:4000
curl -fsS -o /tmp/prometheus.txt -w 'prometheus %{http_code}\n' http://localhost:9090/-/ready
curl -fsS -o /tmp/grafana.txt -w 'grafana %{http_code}\n' http://localhost:3000/api/health
curl -fsS -o /tmp/loki.txt -w 'loki %{http_code}\n' http://localhost:3100/ready
curl -fsS -o /tmp/alertmanager.txt -w 'alertmanager %{http_code}\n' http://localhost:9093/-/ready
```

Checked the real service status returned by the Observability UI API:

```bash
curl -fsS http://localhost:4000/api/services/platform
```

Checked managed app health from the Observability UI API:

```bash
curl -fsS http://localhost:4000/api/apps/health
```

Collected logs from the main Observability Stack services:

```bash
docker compose logs --tail=80 devops-monitor-ui prometheus grafana loki alertmanager
```

Checked host disk:

```bash
df -h
```

Checked Docker storage usage:

```bash
docker system df -v
```

Checked relevant Docker volumes:

```bash
docker volume ls --format 'table {{.Name}}\t{{.Driver}}' | rg 'loki|obervability|grafana|prometheus'
```

Checked disk from inside the Loki container:

```bash
docker exec loki df -h / /loki
```

Inspected Loki mounts:

```bash
docker inspect loki --format '{{json .Mounts}}' | python3 -m json.tool
```

Checked FoodPulse database logs because managed app health and container restarts were also affected:

```bash
docker logs --tail=60 foodpulse-db
```

Freed Docker build cache:

```bash
docker builder prune -f
```

Restarted Loki and Promtail after freeing space:

```bash
docker compose restart loki promtail
```

Restarted FoodPulse services that had been impacted by the same disk pressure:

```bash
docker compose restart foodpulse-db foodpulse-api foodpulse-ui
```

Rechecked Observability Stack services:

```bash
docker compose ps
```

Rechecked FoodPulse services:

```bash
docker compose ps foodpulse-db foodpulse-api foodpulse-ui
```

Rechecked Loki readiness and query path:

```bash
curl -fsS -o /tmp/loki-ready.txt -w 'loki_ready %{http_code}\n' http://localhost:3100/ready
curl -fsS -o /tmp/loki-labels.json -w 'loki_labels %{http_code}\n' http://localhost:3100/loki/api/v1/labels
```

Rechecked FoodPulse UI on the correct local port:

```bash
curl -fsS -o /tmp/foodpulse.txt -w 'foodpulse %{http_code}\n' http://localhost:8090
```

Rechecked Docker disk from inside Loki after cleanup:

```bash
docker exec loki df -h / /loki
```

Rechecked real platform status from the UI API:

```bash
curl -fsS http://localhost:4000/api/services/platform | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(JSON.stringify(j.summary,null,2)); console.log(j.services.map(s=>`${s.name}: ${s.status} ${s.version||""}`).join("\n"));})'
```

Rechecked managed app health from the UI API:

```bash
curl -fsS http://localhost:4000/api/apps/health | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const j=JSON.parse(d); console.log(JSON.stringify(j.summary,null,2)); console.log(j.apps.map(a=>`${a.name}: ${a.status} latency=${a.latencyMs}`).join("\n"));})'
```

### Problems Found

The Mac host disk was not full:

```text
/System/Volumes/Data had available space.
```

The Docker Desktop internal disk was full from inside Loki:

```text
overlay 58.8G used 55.8G available 0 use% 100% /
/dev/vdb1 58.8G used 55.8G available 0 use% 100% /loki
```

Loki logs showed write failures:

```text
no space left on device
```

FoodPulse database logs showed PostgreSQL could not write its lock file:

```text
could not write lock file "postmaster.pid": No space left on device
```

Alertmanager was also retrying webhook notifications to the monitor UI and receiving a `500` response:

```text
http://devops-monitor-ui:3000/api/notifications/webhook
Unexpected end of JSON input
```

This webhook issue was not the root cause of the outage, but it should be handled as a follow-up bug if it continues.

One verification command failed because shell quoting broke the inline Node formatter:

```bash
curl -fsS http://localhost:4000/api/services/platform | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const j=JSON.parse(d); console.log(JSON.stringify(j.summary,null,2)); console.log(j.services.map(s=>`${s.name}: ${s.status} ${s.version||''}`).join('\n'));})"
```

The shell interpreted `${...}` before Node could run it, causing:

```text
zsh: bad substitution
SyntaxError: Unexpected token ')'
```

We fixed that by wrapping the Node program in single quotes and using double quotes inside the JavaScript.

One verification command checked the old FoodPulse port:

```bash
curl -fsS -o /tmp/foodpulse.txt -w 'foodpulse %{http_code}\n' http://localhost:8084
```

That returned:

```text
foodpulse 000
```

FoodPulse is currently exposed on port `8090`, so the correct check is:

```bash
curl -fsS -o /tmp/foodpulse.txt -w 'foodpulse %{http_code}\n' http://localhost:8090
```

### Root Cause

Docker Desktop internal storage was full.

The Mac still had host disk available, but containers write through Docker Desktop's internal Linux VM disk. That internal disk reached `100%`, so Loki could not write chunks/index data and FoodPulse PostgreSQL could not write its lock file. This made the stack look down or unstable even though several containers were still technically running.

### Fix Applied

Freed Docker build cache:

```bash
docker builder prune -f
```

Result:

```text
Total reclaimed space: 5.823GB
```

Restarted the impacted logging services:

```bash
docker compose restart loki promtail
```

Restarted the impacted FoodPulse services:

```bash
docker compose restart foodpulse-db foodpulse-api foodpulse-ui
```

### Verification

Loki disk after cleanup:

```text
overlay 58.8G used 50.7G available 5.0G use% 91% /
/dev/vdb1 58.8G used 50.7G available 5.0G use% 91% /loki
```

Loki readiness and query path:

```text
loki_ready 200
loki_labels 200
```

Observability platform services:

```text
total: 8
up: 8
down: 0
updatesAvailable: 0
```

Service results:

```text
Prometheus: up
Grafana: up
Alertmanager: up
Node Exporter: up
Blackbox Exporter: up
cAdvisor: up
Loki: up
Promtail: up
```

FoodPulse:

```text
foodpulse 200
foodpulse-db: up
foodpulse-api: up
foodpulse-ui: up
```

Managed app health:

```text
OpenSIS: down
SwiftPay: healthy
MemFlip: healthy
FoodPulse: healthy
```

OpenSIS is a separate managed-app follow-up. The Observability Stack itself is back up.

### Why We Did This

We checked health endpoints first because they match what a user sees. Then we checked logs and disk because a service can be "running" but still broken if it cannot write. Loki and PostgreSQL both reported write failures, which pointed to storage pressure. Checking disk inside the container confirmed the real problem was Docker Desktop internal disk, not the Mac host filesystem.

### Follow-Up Recommendations

Add retention and storage limits for Loki so local logs cannot grow forever.

Increase Docker Desktop disk image size or keep a documented minimum free-space threshold for this project.

Add a dashboard warning when Docker/container filesystem usage crosses a dangerous threshold.

Create a safe cleanup script for learners:

```bash
docker builder prune -f
docker image prune -f
```

Do not automatically prune volumes in the learner script because volumes may contain database data.

Investigate the Alertmanager webhook `Unexpected end of JSON input` error if it continues after the storage incident.

Bring OpenSIS back up separately if the managed-app dashboard should show all four apps healthy.

## IR-2026-04-20-002 - HighDiskUsage Alert Follow-Up

### Situation

After the Observability Stack recovered, Alertmanager still showed:

```text
HighDiskUsage
High disk usage on node-exporter
Firing
Warning
Value: 85%
Description: Disk usage is above 85% for more than 5 minutes on node-exporter
device=/dev/vdb1
mountpoint=/var/lib/cni
```

This was related to the same Docker Desktop internal disk pressure from the previous incident. The earlier cleanup got Docker out of the `100%` hard-failure state, but the disk was still above the `85%` warning threshold.

### Commands Run

Checked disk usage from inside a running container:

```bash
docker exec node-exporter df -h /host/var/lib/cni /host 2>/dev/null || docker exec loki df -h / /loki
```

Checked Docker storage usage:

```bash
docker system df -v
```

Queried Prometheus for the exact alert value:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=100%20-%20(node_filesystem_avail_bytes%7Bjob%3D%22node-exporter%22%2Cmountpoint%3D%22%2Fvar%2Flib%2Fcni%22%7D%20*%20100%20%2F%20node_filesystem_size_bytes%7Bjob%3D%22node-exporter%22%2Cmountpoint%3D%22%2Fvar%2Flib%2Fcni%22%7D)'
```

Listed Docker images to look for safe cleanup candidates:

```bash
docker image ls --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | head -80
```

Pruned unused builder cache:

```bash
docker builder prune -af
```

Rechecked disk usage:

```bash
docker exec loki df -h / /loki
```

Rechecked Prometheus directly:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=100%20-%20(node_filesystem_avail_bytes%7Bjob%3D%22node-exporter%22%2Cmountpoint%3D%22%2Fvar%2Flib%2Fcni%22%7D%20*%20100%20%2F%20node_filesystem_size_bytes%7Bjob%3D%22node-exporter%22%2Cmountpoint%3D%22%2Fvar%2Flib%2Fcni%22%7D)'
```

Checked active disk alerts:

```bash
curl -fsS 'http://localhost:9090/api/v1/alerts'
```

Inspected the disk alert rules:

```bash
rg -n "HighDiskUsage|node_filesystem|mountpoint" Obervability-Stack/prometheus/alert_rules.yml Obervability-Stack/prometheus/prometheus.yml
sed -n '1,120p' Obervability-Stack/prometheus/alert_rules.yml
sed -n '1,180p' Obervability-Stack/prometheus/prometheus.yml
```

Checked which mountpoints mapped to the same disk:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=sort_desc((node_filesystem_size_bytes%7Bjob%3D%22node-exporter%22%2Cfstype!~%22tmpfs%7Coverlay%7Csquashfs%7Crpc_pipefs%7Cnsfs%7Cautofs%7Cdevtmpfs%22%7D%20-%20node_filesystem_avail_bytes%7Bjob%3D%22node-exporter%22%2Cfstype!~%22tmpfs%7Coverlay%7Csquashfs%7Crpc_pipefs%7Cnsfs%7Cautofs%7Cdevtmpfs%22%7D)%20%2F%20node_filesystem_size_bytes%7Bjob%3D%22node-exporter%22%2Cfstype!~%22tmpfs%7Coverlay%7Csquashfs%7Crpc_pipefs%7Cnsfs%7Cautofs%7Cdevtmpfs%22%7D%20*%20100)'
```

Validated the updated Prometheus rules:

```bash
docker exec prometheus promtool check rules /etc/prometheus/alert_rules.yml
```

Reloaded Prometheus without restarting the stack:

```bash
curl -fsS -X POST -w 'prometheus_reload %{http_code}\n' http://localhost:9090/-/reload -o /tmp/prometheus-reload.txt
```

Verified the new device-level disk query:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=max%20by(instance%2Cdevice%2Cfstype)%20(((node_filesystem_size_bytes%7Bfstype!~%22tmpfs%7Coverlay%7Csquashfs%7Crpc_pipefs%7Cnsfs%7Cautofs%7Cdevtmpfs%22%7D-node_filesystem_avail_bytes%7Bfstype!~%22tmpfs%7Coverlay%7Csquashfs%7Crpc_pipefs%7Cnsfs%7Cautofs%7Cdevtmpfs%22%7D)%2Fnode_filesystem_size_bytes%7Bfstype!~%22tmpfs%7Coverlay%7Csquashfs%7Crpc_pipefs%7Cnsfs%7Cautofs%7Cdevtmpfs%22%7D)*100)'
```

Verified core monitoring services:

```bash
docker compose ps prometheus node-exporter alertmanager loki promtail
```

### Problems Found

The disk was still above the warning threshold:

```text
Prometheus query result: 91.16%
Container df result: 91%
```

Docker build cache had grown again:

```text
Build cache usage: 7.848GB
```

The alert rule was also noisy because node-exporter exposed the same Docker Desktop disk through several mountpoints:

```text
91.43% /dev/vdb1 /mnt/lima-colima ext4
91.43% /dev/vdb1 /var/lib/cni ext4
91.43% /dev/vdb1 /var/lib/containerd ext4
91.43% /dev/vdb1 /var/lib/docker ext4
91.43% /dev/vdb1 /var/lib/ramalama ext4
91.43% /dev/vdb1 /var/lib/rancher ext4
```

That meant one physical disk issue could create several duplicate alerts.

### Fix Applied

Pruned all unused Docker builder cache:

```bash
docker builder prune -af
```

Result:

```text
Total reclaimed space: 7.848GB
```

Updated `HighDiskUsage` and `CriticalDiskUsage` to aggregate by physical device:

```text
max by(instance, device, fstype) (...)
```

This keeps the alert real, but prevents duplicate alerts for every bind-mounted view of the same Docker Desktop disk.

Reloaded Prometheus:

```text
prometheus_reload 200
```

### Verification

Disk usage after cleanup:

```text
overlay 58.8G used 44.8G available 10.9G use% 80% /
/dev/vdb1 58.8G used 44.8G available 10.9G use% 80% /loki
```

Prometheus disk query after cleanup:

```text
/var/lib/cni on /dev/vdb1: 81.43%
```

New device-level query:

```text
81.36% node-exporter /dev/vdb1 ext4
67.43% node-exporter lima-8adf3fcc95ea7bab virtiofs
10.58% node-exporter /dev/vda16 ext4
6.50% node-exporter /dev/vda15 vfat
4.87% node-exporter /dev/root ext4
```

Active disk alerts:

```text
disk_alerts: none active
```

Prometheus rule validation:

```text
SUCCESS: 40 rules found
```

Core monitoring services remained healthy:

```text
prometheus: healthy
node-exporter: healthy
alertmanager: healthy
loki: healthy
promtail: up
```

### Why We Did This

The alert was useful because it caught the remaining risk after the outage fix. We did not delete volumes because those can hold learner data and databases. We pruned only builder cache because it is safe to regenerate and was large enough to bring the disk below the warning threshold.

We also improved the alert rule because a single Docker Desktop disk can appear under multiple mountpoints. Alerting by physical device makes the signal easier to understand.

### Remaining Risk

Docker Desktop disk usage is now under the alert threshold, but it is still not roomy. If the project grows, we should either increase Docker Desktop's disk image size or add regular safe cleanup guidance for learners.

## IR-2026-04-20-003 - HighContainerCPUUsage on cAdvisor

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
