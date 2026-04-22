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

## IR-2026-04-20-004 - FoodPulse UI API 502 Through Postgres HAProxy

### Situation

The user asked us to check the FoodPulse UI.

The first check showed the static UI was reachable, but the application was not fully healthy:

```text
http://localhost:8090 returned 200
http://localhost:8090/api/health returned 502
```

That meant Nginx could serve the frontend, but the UI could not load live restaurant/status data from the API.

### Commands Run

Checked the FoodPulse UI HTTP status:

```bash
curl -fsS -o /tmp/foodpulse-ui.html -w 'foodpulse_ui %{http_code}\n' http://localhost:8090
```

Checked the FoodPulse API health endpoint through the UI proxy:

```bash
curl -fsS http://localhost:8090/api/health
```

Tried to inspect FoodPulse Compose services, initially using the container-style Redis name instead of the Compose service name:

```bash
docker compose ps foodpulse-ui foodpulse-api foodpulse-db foodpulse-redis-master
```

Collected UI and API logs:

```bash
docker compose logs --tail=80 foodpulse-ui foodpulse-api
```

Checked the full FoodPulse Compose state:

```bash
docker compose ps
```

Checked Postgres and Postgres HAProxy logs:

```bash
docker compose logs --tail=120 foodpulse-db pg-haproxy
```

Verified the primary Postgres database was reachable directly:

```bash
docker compose exec -T foodpulse-db psql -U postgres -d foodpulse -c 'select 1 as db_ok;'
```

Checked FoodPulse API database environment variables:

```bash
docker compose exec -T foodpulse-api printenv | sort | grep FOODPULSE
```

Reviewed the FoodPulse API startup path:

```bash
sed -n '1,140p' api/src/index.js
```

Reviewed the Postgres HAProxy configuration from the repo:

```bash
sed -n '1,220p' haproxy/haproxy.cfg
```

Reviewed the active Postgres HAProxy configuration inside the running container:

```bash
docker compose exec -T pg-haproxy sh -lc 'cat /usr/local/etc/haproxy/haproxy.cfg'
```

Checked database roles:

```bash
docker compose exec -T foodpulse-db psql -U postgres -d foodpulse -c "\du"
```

Checked databases:

```bash
docker compose exec -T foodpulse-db psql -U postgres -d foodpulse -c "select datname from pg_database order by datname;"
```

Checked Postgres host-based auth rules:

```bash
docker compose exec -T foodpulse-db sh -lc 'grep -v "^[[:space:]]*#" "$PGDATA/pg_hba.conf" | sed "/^[[:space:]]*$/d"'
```

Checked current Postgres sessions:

```bash
docker compose exec -T foodpulse-db psql -U postgres -d foodpulse -c "select usename, client_addr, state, application_name from pg_stat_activity order by backend_start desc limit 20;"
```

Checked HAProxy binary availability:

```bash
docker compose exec -T pg-haproxy sh -lc 'haproxy -vv | head -80'
```

That command failed because `haproxy` was not on the default shell path in the container.

Checked whether the FoodPulse API image had Postgres client tools and confirmed its platform:

```bash
docker compose exec -T foodpulse-api sh -lc 'which pg_isready || true; which psql || true; node -e "console.log(process.arch, process.platform)"'
```

Checked whether the API could query Postgres through HAProxy:

```bash
docker compose exec -T foodpulse-api sh -lc 'node - <<"NODE"
const { Pool } = require("pg");
const pool = new Pool({host:"pg-haproxy", port:5432, database:"foodpulse", user:"foodpulse", password:"foodpulse"});
pool.query("select 1 as ok").then(r=>{console.log(r.rows); process.exit(0)}).catch(e=>{console.error(e.message); process.exit(1)});
NODE'
```

Checked whether the API could query Postgres directly:

```bash
docker compose exec -T foodpulse-api sh -lc 'node - <<"NODE"
const { Pool } = require("pg");
const pool = new Pool({host:"foodpulse-db", port:5432, database:"foodpulse", user:"foodpulse", password:"foodpulse"});
pool.query("select 1 as ok").then(r=>{console.log(r.rows); process.exit(0)}).catch(e=>{console.error(e.message); process.exit(1)});
NODE'
```

Listed Compose services to confirm service names:

```bash
docker compose config --services
```

Checked HAProxy logs for backend failures:

```bash
docker logs --tail=160 foodpulse-pg-haproxy
```

Inspected the Postgres HAProxy container command:

```bash
docker inspect foodpulse-pg-haproxy --format '{{json .Config.Cmd}} {{json .Config.Entrypoint}} {{json .Config.Image}}'
```

Listed common binary paths inside the HAProxy container:

```bash
docker compose exec -T pg-haproxy sh -lc 'ls -la /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin 2>/dev/null | sed -n "1,220p"'
```

Searched for FoodPulse HAProxy/database references:

```bash
rg -n "pg-haproxy|FOODPULSE_DB_SERVER|haproxy|foodpulse-db" docker-compose.yml api -S
```

Confirmed the primary Postgres node was writable and not in recovery:

```bash
docker compose exec -T foodpulse-db psql -U postgres -d foodpulse -c "select pg_is_in_recovery() as in_recovery, current_setting('transaction_read_only') as tx_read_only;"
```

Validated the active HAProxy config:

```bash
docker compose exec -T pg-haproxy sh -lc '/usr/local/sbin/haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg'
```

Checked HAProxy DNS resolution for the primary and replicas:

```bash
docker compose exec -T pg-haproxy sh -lc 'getent hosts foodpulse-db foodpulse-db-replica1 foodpulse-db-replica2 foodpulse-db-replica3'
```

Checked TCP reachability from HAProxy to the primary and a replica:

```bash
docker compose exec -T pg-haproxy sh -lc 'timeout 2 bash -lc "</dev/tcp/foodpulse-db/5432"; echo primary_tcp_$?; timeout 2 bash -lc "</dev/tcp/foodpulse-db-replica1/5432"; echo replica1_tcp_$?'
```

Restarted only the Postgres HAProxy service to clear the bad backend state:

```bash
docker compose restart pg-haproxy
```

Retested API-to-Postgres through HAProxy:

```bash
sleep 3; docker compose exec -T foodpulse-api sh -lc 'node - <<"NODE"
const { Pool } = require("pg");
const pool = new Pool({host:"pg-haproxy", port:5432, database:"foodpulse", user:"foodpulse", password:"foodpulse"});
pool.query("select 1 as ok").then(r=>{console.log(r.rows); process.exit(0)}).catch(e=>{console.error(e.message); process.exit(1)});
NODE'
```

Checked recent Postgres HAProxy logs after restart:

```bash
sleep 3; docker logs --tail=40 foodpulse-pg-haproxy
```

Checked the recovered service state:

```bash
sleep 3; docker compose ps foodpulse-api pg-haproxy foodpulse-ui
```

Verified the UI and API endpoints after recovery:

```bash
curl -fsS -o /tmp/foodpulse-ui.html -w 'ui %{http_code}\n' http://localhost:8090
curl -fsS -w '\nhealth %{http_code}\n' http://localhost:8090/api/health
curl -fsS -w '\nvenues %{http_code}\n' http://localhost:8090/api/venues | head -c 2000
```

Checked that `npx` was available before using the local Playwright wrapper:

```bash
command -v npx >/dev/null 2>&1; echo npx_$?
```

Attempted to open the UI with Playwright using a one-line environment assignment:

```bash
mkdir -p output/playwright && CODEX_HOME="${CODEX_HOME:-$HOME/.codex}" PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh" "$PWCLI" open http://localhost:8090
```

That command failed because `PWCLI` expanded before the temporary `CODEX_HOME` assignment was available to the same command. We fixed it by assigning variables first, then running the wrapper.

Opened the FoodPulse UI in a real browser:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"; PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"; ls -l "$PWCLI"; "$PWCLI" open http://localhost:8090
```

Captured a browser accessibility snapshot:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"; PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"; "$PWCLI" snapshot
```

Clicked the Naija Jollof vote button and captured the updated UI state:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"; PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"; "$PWCLI" click e84 && "$PWCLI" snapshot
```

Attempted to save a screenshot with the wrong Playwright CLI option:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"; PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"; "$PWCLI" screenshot --path output/playwright/foodpulse-ui-2026-04-20.png
```

That failed because this wrapper uses `--filename`, not `--path`.

Saved a full-page screenshot with the correct option:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"; PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"; "$PWCLI" screenshot --filename output/playwright/foodpulse-ui-2026-04-20.png --full-page
```

Checked recent API/UI logs after recovery:

```bash
docker compose logs --tail=60 foodpulse-api foodpulse-ui
```

Removed temporary Playwright artifacts created during the check so we did not commit generated browser output:

```bash
rm -rf .playwright-cli output
```

### Evidence

The UI served static content:

```text
foodpulse_ui 200
```

The API was initially failing through the UI proxy:

```text
GET /api/health HTTP/1.1" 502
```

FoodPulse API logs showed repeated startup dependency failures:

```text
foodpulse-api startup dependency check failed ... Connection terminated unexpectedly
foodpulse-api failed to start Error: Connection terminated unexpectedly
```

Nginx in the UI container could not connect to the API while the API was restarting:

```text
connect() failed (111: Connection refused) while connecting to upstream
```

Postgres itself was reachable:

```text
db_ok
-----
1
```

The API could query the primary database directly:

```text
[ { ok: 1 } ]
```

The API could not query the database through `pg-haproxy` before the fix:

```text
Connection terminated unexpectedly
```

HAProxy was returning no available server for write traffic:

```text
pg_rw pg_rw_backend/<NOSRV>
```

The primary Postgres node was not in recovery and was writable:

```text
in_recovery = f
tx_read_only = off
```

HAProxy could resolve and reach the Postgres containers over TCP:

```text
primary_tcp_0
replica1_tcp_0
```

After restarting `pg-haproxy`, API-to-Postgres through HAProxy succeeded:

```text
[ { ok: 1 } ]
```

The FoodPulse health endpoint recovered:

```json
{"status":"healthy","checks":{"database":true,"cache":true},"hostname":"0667777b05ca"}
```

The browser snapshot showed eight restaurant labels online and the live board healthy:

```text
Live board: Healthy
8 kitchens online
```

Voting worked for the selected label. Naija Jollof changed from 71 to 72 votes, while other restaurant labels kept their previous vote counts. The aggregate live pulse changed from 238 to 239 total votes.

### Root Cause

The FoodPulse UI was not broken at the static frontend layer. The outage was in the API dependency path.

The API depends on Postgres through `pg-haproxy`:

```text
FOODPULSE_DB_SERVER=pg-haproxy
```

The primary Postgres database had recovered from the earlier disk-space incident and was directly reachable, but the Postgres HAProxy service was still presenting the write backend as unavailable:

```text
pg_rw_backend/<NOSRV>
```

Because the API startup check uses the HAProxy path, the API repeatedly failed startup, and the UI's Nginx proxy returned 502 for `/api/*` routes.

### Fix

Restarted the Postgres HAProxy service only:

```bash
docker compose restart pg-haproxy
```

This cleared the stale backend state and allowed HAProxy to route write traffic to the recovered primary Postgres container again.

### Verification

Verified API-to-database through HAProxy:

```text
[ { ok: 1 } ]
```

Verified FoodPulse API health through the UI proxy:

```text
health 200
```

Verified venues load through the UI proxy:

```text
venues data returned restaurant records
```

Verified with a real browser that:

```text
FoodPulse page title is present.
Live board shows Healthy.
Eight restaurant labels render.
Vote buttons are present.
Naija Jollof vote increments only the selected restaurant label.
The live pulse total increments by one.
```

### Follow-Up

Add better operational visibility around the FoodPulse Postgres HAProxy layer before Kubernetes migration. Good next hardening options:

- Add an HAProxy stats socket or stats endpoint for backend state inspection.
- Add a FoodPulse precheck that verifies `pg-haproxy` can route to Postgres, not just that Postgres is reachable directly.
- Add a targeted runbook step for restarting only `pg-haproxy` after database recovery if HAProxy continues to report `<NOSRV>`.
- Revisit HAProxy health-check behavior if this repeats, because a healthy proxy should usually recover backend state without a manual restart.

## IR-2026-04-21-002 - HighContainerMemoryUsage Alert On cAdvisor

### Situation

The user reported a warning alert:

```text
HighContainerMemoryUsage
High container memory usage on cadvisor
Firing
Warning
Service: containers
Value: 80%
Duration: 7m
Description: Container memory usage is above 80% on cadvisor
Labels:
alertname=HighContainerMemoryUsage
cluster=devops-monitoring
component=memory
id=/
instance=cadvisor
job=cadvisor
service=containers
severity=warning
Started: 4/21/2026, 1:52:37 PM
Updated: 4/21/2026, 1:56:22 PM
Ends: 4/21/2026, 2:00:22 PM
```

We treated this as a real container-memory incident first, then validated whether it was a real container under pressure or a noisy alert rule.

### Commands Run

Checked live Docker container memory and CPU:

```bash
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}'
```

Checked cAdvisor memory working set from Prometheus:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=container_memory_working_set_bytes%7Bjob%3D%22cadvisor%22%7D' | jq '[.data.result[] | {container:(.metric.name // .metric.container_label_com_docker_compose_service // .metric.container // .metric.id), id:.metric.id, value:(.value[1]|tonumber)}] | sort_by(.value) | reverse | .[0:15]'
```

Checked the firing alert series:

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=ALERTS%7Balertname%3D%22HighContainerMemoryUsage%22%7D' | jq '.data.result[] | {state:.metric.alertstate, instance:.metric.instance, id:.metric.id, service:.metric.service, value:.value[1]}'
```

Searched the alert and recording rule definitions:

```bash
rg -n "HighContainerMemoryUsage|container_memory|cadvisor" Obervability-Stack/prometheus Obervability-Stack -S -g '!**/node_modules/**'
```

Checked the old expression directly:

```bash
curl -fsS 'http://localhost:9090/api/v1/query' --get --data-urlencode 'query=(container_memory_usage_bytes{job="cadvisor"} / container_spec_memory_limit_bytes{job="cadvisor"} * 100) > 80' | jq '.data.result[] | {name:(.metric.name // .metric.container_label_com_docker_compose_service // .metric.id), id:.metric.id, image:.metric.image, value:.value[1]}'
```

Checked the corrected real-container expression:

```bash
curl -fsS 'http://localhost:9090/api/v1/query' --get --data-urlencode 'query=(container_memory_working_set_bytes{job="cadvisor",id!="/",image!=""} / container_spec_memory_limit_bytes{job="cadvisor",id!="/",image!=""} * 100) > 80' | jq '.data.result[] | {name:(.metric.name // .metric.container_label_com_docker_compose_service // .metric.id), id:.metric.id, image:.metric.image, value:.value[1]}'
```

Checked the active Prometheus alert object:

```bash
curl -fsS 'http://localhost:9090/api/v1/alerts' | jq '.data.alerts[] | select(.labels.alertname=="HighContainerMemoryUsage") | {state:.state, activeAt:.activeAt, value:.value, labels:.labels, annotations:.annotations}'
```

Reviewed the rule file:

```bash
sed -n '190,230p' Obervability-Stack/prometheus/alert_rules.yml
sed -n '20,40p' Obervability-Stack/prometheus/recording_rules.yml
```

Edited:

```text
Obervability-Stack/prometheus/alert_rules.yml
Obervability-Stack/prometheus/recording_rules.yml
Obervability-Stack/docs/ALERTMANAGER_INTEGRATION.md
INCIDENT-RESPONSE.md
```

Validated Prometheus rules:

```bash
docker exec prometheus promtool check rules /etc/prometheus/alert_rules.yml /etc/prometheus/recording_rules.yml
```

Confirmed the updated rule was visible inside the container:

```bash
docker compose exec -T prometheus sh -lc 'ls -la /etc/prometheus && grep -n "HighContainerMemoryUsage" -A8 /etc/prometheus/alert_rules.yml'
```

Reloaded Prometheus without restarting it:

```bash
curl -sS -X POST -w '\nHTTP %{http_code}\n' http://localhost:9090/-/reload
```

Confirmed lifecycle reload support:

```bash
sed -n '20,50p' Obervability-Stack/docker-compose.yml
```

Verified the corrected query and active rule state:

```bash
sleep 5; curl -fsS 'http://localhost:9090/api/v1/query' --get --data-urlencode 'query=ALERTS{alertname="HighContainerMemoryUsage"}' | jq '.data.result[] | {state:.metric.alertstate, id:.metric.id, value:.value[1]}'
curl -fsS 'http://localhost:9090/api/v1/query' --get --data-urlencode 'query=(container_memory_working_set_bytes{job="cadvisor",id!="/",image!=""} / container_spec_memory_limit_bytes{job="cadvisor",id!="/",image!=""} * 100) > 80' | jq '.data.result'
curl -fsS 'http://localhost:9090/api/v1/rules' | jq '.data.groups[] | select(.name=="container_alerts") | .rules[] | select(.name=="HighContainerMemoryUsage") | {query:.query, state:.state, alerts:.alerts}'
```

### Evidence

No individual container was near 80% memory usage.

Examples from `docker stats`:

```text
devops-monitor-ui   133.3MiB / 1GiB     13.02%
cadvisor            52.72MiB / 512MiB   10.30%
promtail            119.4MiB / 512MiB   23.33%
grafana             148.5MiB / 1GiB     14.50%
prometheus          132.6MiB / 4GiB     3.24%
loki                142.8MiB / 2GiB     6.97%
```

The alert was firing only on the cAdvisor root cgroup:

```text
id="/"
instance="cadvisor"
job="cadvisor"
value="88.19"
```

The old expression returned only the root cgroup:

```json
{
  "name": "/",
  "id": "/",
  "image": null,
  "value": "88.35001908022471"
}
```

The corrected real-container expression returned no firing series:

```json
[]
```

After the rule reload, Prometheus reported the rule as inactive:

```json
{
  "query": "(container_memory_working_set_bytes{id!=\"/\",image!=\"\",job=\"cadvisor\"} / container_spec_memory_limit_bytes{id!=\"/\",image!=\"\",job=\"cadvisor\"} * 100) > 80",
  "state": "inactive",
  "alerts": []
}
```

### Root Cause

This was a false-positive alert caused by an overly broad Prometheus rule.

The old rule evaluated:

```promql
(container_memory_usage_bytes / container_spec_memory_limit_bytes * 100) > 80
```

That included the cAdvisor root cgroup:

```text
id="/"
image=null
```

The root cgroup represents broader Docker VM / host-level memory accounting, not a specific application container. On Docker Desktop, that root series can include memory cache and platform overhead, so it can look high even when no individual container is under pressure.

### Fix

Updated container memory alert rules to:

- exclude the root cgroup with `id!="/"`,
- exclude non-container series with `image!=""`,
- use `container_memory_working_set_bytes` instead of total usage bytes.

Updated warning expression:

```promql
(container_memory_working_set_bytes{job="cadvisor",id!="/",image!=""} / container_spec_memory_limit_bytes{job="cadvisor",id!="/",image!=""} * 100) > 80
```

Updated critical expression:

```promql
(container_memory_working_set_bytes{job="cadvisor",id!="/",image!=""} / container_spec_memory_limit_bytes{job="cadvisor",id!="/",image!=""} * 100) > 95
```

Updated the recording rule:

```promql
(container_memory_working_set_bytes{job="cadvisor",id!="/",image!=""} / container_spec_memory_limit_bytes{job="cadvisor",id!="/",image!=""}) * 100
```

Reloaded Prometheus:

```bash
curl -sS -X POST -w '\nHTTP %{http_code}\n' http://localhost:9090/-/reload
```

### Verification

Prometheus rule syntax passed:

```text
Checking /etc/prometheus/alert_rules.yml
  SUCCESS: 40 rules found

Checking /etc/prometheus/recording_rules.yml
  SUCCESS: 34 rules found
```

Prometheus reload succeeded:

```text
HTTP 200
```

The corrected alert rule is loaded:

```text
container_memory_working_set_bytes{id!="/",image!="",job="cadvisor"}
```

The alert is inactive:

```text
state: inactive
alerts: []
```

### Follow-Up

- Keep the rule scoped to real containers only.
- Avoid alerting on `id="/"` from cAdvisor unless the alert is explicitly named as host/Docker-VM memory pressure.
- If we want host memory alerts, use Node Exporter host memory rules instead of cAdvisor container rules.
- Consider adding a dedicated alert test or promtool unit test later so root-cgroup regressions are caught before reload.

## IR-2026-04-22-001 - OpenSIS Vault Synthetic Exporter And Required Secret Alerts

### Situation

On 2026-04-22, the user reported four active Observability Stack alerts centered on OpenSIS Vault:

```text
NodeDown
OpenSISVaultSyntheticExporterDown
OpenSISVaultUnhealthy
OpenSISVaultRequiredSecretReadFailed
```

The OpenSIS Operations Grafana dashboard was also visible under the `General` folder instead of `Application Monitoring`.

### Severity

Warning to critical, application-specific.

The affected service was OpenSIS Vault observability. The OpenSIS application itself remained reachable, but the Vault synthetic monitoring path was degraded and created misleading node-down and Vault-secret-read alerts.

### Commands Run

```bash
git status --short --branch
curl -fsS -u admin:admin http://localhost:3000/api/dashboards/uid/opensis-operations | jq '{title: .dashboard.title, uid: .dashboard.uid, folderTitle: .meta.folderTitle, folderId: .meta.folderId, provisioned: .meta.provisioned, provisionedExternalId: .meta.provisionedExternalId, canSave: .meta.canSave, url: .meta.url}'
curl -fsS 'http://localhost:9090/api/v1/alerts' | jq -r '.data.alerts[] | [.labels.alertname,.state,.labels.severity,.labels.service,.labels.component,.labels.instance,.annotations.description] | @tsv'
curl -fsS 'http://localhost:9093/api/v2/alerts' | jq -r '.[] | [.labels.alertname,.status.state,.labels.severity,.labels.service,.labels.component,.labels.instance,.annotations.description] | @tsv'
docker compose -f OpenSIS/docker-compose.yaml ps -a
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | rg 'opensis|vault|checker|mariadb|apache'
sed -n '235,285p' OpenSIS/docker-compose.yaml
sed -n '210,235p' Obervability-Stack/prometheus/prometheus.yml
docker inspect opensis-vault-synthetic-exporter | jq '.[] | {name:.Name, networks:.NetworkSettings.Networks | with_entries(.value |= {aliases:.Aliases, ip:.IPAddress})}'
docker exec prometheus sh -lc 'wget -qO- --timeout=3 http://opensis-vault-checker:9105/metrics | head -40'
docker logs --tail=120 opensis-vault-synthetic-exporter
sed -n '1,260p' OpenSIS/observability/vault-synthetic-exporter.py
docker exec opensis-vault-synthetic-exporter sh -lc 'ps aux; echo; ls -la /vault/approle-app /vault/approle-db; echo; wget -S -O- --timeout=5 http://127.0.0.1:9105/metrics | head -60'
curl -fsS 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22opensis-vault%22%7D' | jq '.data.result'
docker exec opensis-vault-synthetic-exporter sh -lc 'echo app; ls -la /vault/approle-app; echo db; ls -la /vault/approle-db'
docker run --rm -v devops-easy-learning_app_runtime_approle:/app -v devops-easy-learning_db_runtime_approle:/db alpine:3.20 sh -lc 'echo app volume; ls -la /app; echo db volume; ls -la /db'
sed -n '1,220p' OpenSIS/scripts/bootstrap.sh
docker logs --tail=160 vault-bootstrap
docker inspect opensis-vault-synthetic-exporter vault-bootstrap vault-agent-app vault-agent-db | jq '.[] | {name:.Name, mounts:[.Mounts[] | {type:.Type,name:.Name,destination:.Destination,source:.Source}]}'
docker volume ls | rg 'approle|opensis|devops|app_runtime|db_runtime'
docker run --rm -v app_runtime_approle:/app:ro -v db_runtime_approle:/db:ro alpine:3.20 sh -lc 'echo app volume; ls -la /app; echo db volume; ls -la /db'
docker logs --tail=80 vault-agent-app
docker logs --tail=80 vault-agent-db
sed -n '1,220p' OpenSIS/vault-agent/app-config/agent-app.hcl
sed -n '1,220p' OpenSIS/vault-agent/db-config/agent-db.hcl
rg -n "remove_secret_id_file_after_reading|secret_id_file_path|role_id_file_path" OpenSIS/vault-agent OpenSIS -g '*.hcl'
docker compose -f OpenSIS/docker-compose.yaml up --force-recreate vault-bootstrap
docker compose -f OpenSIS/docker-compose.yaml up -d --force-recreate vault-agent-app vault-agent-db vault-synthetic-exporter
docker exec opensis-vault-synthetic-exporter sh -lc 'echo app; ls -la /vault/approle-app; echo db; ls -la /vault/approle-db'
docker logs --tail=40 vault-agent-app
docker logs --tail=40 vault-agent-db
docker logs --tail=40 opensis-vault-synthetic-exporter
docker exec prometheus sh -lc 'wget -qO- --timeout=5 http://opensis-vault-checker:9105/metrics | head -80'
curl -fsS 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22opensis-vault%22%7D' | jq '.data.result'
curl -fsS 'http://localhost:9090/api/v1/query?query=opensis_vault_secret_read_success' | jq '.data.result'
curl -fsS 'http://localhost:9090/api/v1/query?query=opensis_vault_health_status' | jq '.data.result'
APP_FOLDER_UID=$(curl -fsS -u admin:admin http://localhost:3000/api/folders | jq -r '.[] | select(.title=="Application Monitoring") | .uid')
curl -fsS -u admin:admin http://localhost:3000/api/dashboards/uid/opensis-operations | jq --arg folderUid "$APP_FOLDER_UID" '{dashboard: .dashboard, folderUid: $folderUid, overwrite: true, message: "Move OpenSIS Operations to Application Monitoring"}' | curl -fsS -u admin:admin -H 'Content-Type: application/json' -X POST http://localhost:3000/api/dashboards/db -d @- | jq '{status, slug, uid, url, version}'
curl -fsS -u admin:admin http://localhost:3000/api/dashboards/uid/opensis-operations | jq '{title: .dashboard.title, uid: .dashboard.uid, folderTitle: .meta.folderTitle, folderId: .meta.folderId, provisioned: .meta.provisioned, canSave: .meta.canSave, url: .meta.url}'
curl -fsS -u admin:admin 'http://localhost:3000/api/search?query=OpenSIS%20Operations' | jq -r '.[] | [.title,.uid,.folderTitle,.url] | @tsv'
sleep 75; curl -fsS 'http://localhost:9090/api/v1/alerts' | jq -r '.data.alerts[] | select(.labels.alertname|test("NodeDown|OpenSISVaultSyntheticExporterDown|OpenSISVaultUnhealthy|OpenSISVaultRequiredSecretReadFailed")) | [.labels.alertname,.state,.labels.severity,.labels.service,.labels.component,.labels.instance,.annotations.description] | @tsv'
curl -fsS 'http://localhost:9093/api/v2/alerts' | jq -r '.[] | select(.labels.alertname|test("NodeDown|OpenSISVaultSyntheticExporterDown|OpenSISVaultUnhealthy|OpenSISVaultRequiredSecretReadFailed")) | [.labels.alertname,.status.state,.labels.severity,.labels.service,.labels.component,.labels.instance,.annotations.description] | @tsv'
./Obervability-Stack/scripts/devops-monitor.sh opensis-live
./Obervability-Stack/scripts/devops-monitor.sh operator
curl -fsS 'http://localhost:9090/api/v1/alerts' | jq -r '.data.alerts[] | [.labels.alertname,.state,.labels.severity,.labels.service,.labels.component,.labels.instance] | @tsv'
curl -fsS 'http://localhost:9093/api/v2/alerts' | jq -r '.[] | [.labels.alertname,.status.state,.labels.severity,.labels.service,.labels.component,.labels.instance] | @tsv'
date '+%Y-%m-%d %H:%M %Z'
```

The prefixed-volume command was a mistaken inspection of unrelated volumes. The correct live volumes are `app_runtime_approle` and `db_runtime_approle`.

### Evidence Found

Prometheus initially had the OpenSIS Vault synthetic scrape target down:

```text
up{job="opensis-vault",instance="opensis-vault-checker:9105"} = 0
```

The exporter was running and had the expected network alias, but every `/metrics` request crashed with:

```text
FileNotFoundError: [Errno 2] No such file or directory: '/vault/approle-app/secret_id'
```

The live AppRole credential directories contained `role_id` only. The `secret_id` files were missing from both the app and database AppRole volumes.

### Root Cause

There were two contributing root causes:

- The OpenSIS Vault synthetic exporter did not handle missing AppRole credential files safely. A missing `secret_id` raised an unhandled exception and broke the entire `/metrics` response.
- The Vault agents consumed the shared AppRole `secret_id` files from the live Docker volumes. Because the synthetic exporter also depended on those files, the exporter lost the credential material needed for its synthetic secret-read checks.

The Grafana dashboard folder issue had a separate root cause: the OpenSIS dashboard had stale live Grafana database metadata from an earlier provisioning state and remained in `General` even though the intended folder is `Application Monitoring`.

### Fix Applied

Updated the synthetic exporter so missing AppRole files are emitted as failed secret-read metrics instead of crashing the scrape endpoint.

Updated both Vault agent configurations to preserve the AppRole secret-id file:

```hcl
remove_secret_id_file_after_reading = false
```

Re-ran `vault-bootstrap` to regenerate `role_id` and `secret_id` into the correct live volumes.

Recreated `vault-agent-app`, `vault-agent-db`, and `vault-synthetic-exporter` so they loaded the corrected configuration and exporter code.

Moved the live OpenSIS Grafana dashboard from `General` to `Application Monitoring` through the Grafana API.

### Validation

The exporter now returns metrics from inside Prometheus:

```text
opensis_vault_health_status 1
opensis_vault_api_up 1
opensis_vault_sealed 0
opensis_vault_secret_read_success{secret="opensis-app",path="kv/data/dev/opensis-app"} 1
opensis_vault_secret_read_status_code{secret="opensis-app",path="kv/data/dev/opensis-app"} 200
opensis_vault_secret_read_success{secret="opensis-db",path="kv/data/dev/opensis-db"} 1
opensis_vault_secret_read_status_code{secret="opensis-db",path="kv/data/dev/opensis-db"} 200
```

Prometheus and Alertmanager returned no active alerts for:

```text
NodeDown
OpenSISVaultSyntheticExporterDown
OpenSISVaultUnhealthy
OpenSISVaultRequiredSecretReadFailed
```

The OpenSIS live integration audit passed:

```text
Checks passed: 39/39
OpenSIS live integration audit passed
```

The operator check passed:

```text
Checks passed: 28/28
Apps: 4 total | 4 healthy | 0 degraded | 0 down | 0 unknown
```

Grafana confirmed the OpenSIS dashboard is now in the correct folder:

```text
OpenSIS Operations    opensis-operations    Application Monitoring    /d/opensis-operations/opensis-operations
```

### Follow-Up

For production hardening, OpenSIS should eventually use a dedicated AppRole for the synthetic exporter instead of sharing the app and database agents' AppRole files. This will reduce credential coupling and make future Kubernetes Secret or Vault Agent Injector migration cleaner.

When moving to Kubernetes, model these credentials as separate Vault roles and Kubernetes-auth bindings rather than shared writable volumes.
