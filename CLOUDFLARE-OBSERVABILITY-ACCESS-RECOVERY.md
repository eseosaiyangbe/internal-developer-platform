# Cloudflare Observability Access Recovery

This procedure recovers the observability service URLs when:

- Cloudflare Access login succeeds
- the browser still lands on `404` or `502`
- the Kubernetes service is healthy through Traefik locally
- the public Cloudflare hostname is still broken

Use this runbook for:

- `prometheus.eseosadevbox.com`
- `grafana.eseosadevbox.com`
- `alertmanager.eseosadevbox.com`
- `loki.eseosadevbox.com`
- `node-exporter.eseosadevbox.com`
- `blackbox-exporter.eseosadevbox.com`
- `cadvisor.eseosadevbox.com`
- `promtail.eseosadevbox.com`

## Core lesson

The public hostname routes for `eseosadevbox-k8s` are controlled by the remote Cloudflare tunnel configuration when the tunnel config API reports:

- `source: cloudflare`

In that mode:

- local `~/.cloudflared/config.yml` is not authoritative for public hostname routing
- Cloudflare Access can authenticate correctly while the tunnel still forwards with the wrong host behavior
- Traefik will return `404` if the origin request does not preserve the correct hostname

## Symptoms

Typical browser symptoms:

- `prometheus.eseosadevbox.com` authenticates and then shows `HTTP ERROR 404`
- `grafana.eseosadevbox.com` shows `502 Bad gateway`
- other protected observability services redirect to Access but do not land correctly after sign-in

Typical local evidence:

- direct Traefik check with the correct `Host:` header works
- public hostname through Cloudflare fails after login

## Step 1 - Confirm the service itself works through Traefik

Check the service directly against Traefik with the correct host header.

Example for Prometheus:

```bash
curl -sk -o /dev/null -D - -H 'Host: prometheus.eseosadevbox.com' http://192.168.64.2/graph
```

Expected result:

- `HTTP/1.1 200 OK`

If this fails, stop here and fix Kubernetes, Traefik, or the ingress first.

## Step 2 - Reproduce the public failure in a real browser

Use Playwright so the failure is verified after Cloudflare Access login, not just with curl.

Open the service:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"

"$PWCLI" open https://prometheus.eseosadevbox.com/graph --headed
```

If Access prompts for email and code:

1. enter `e_raywhite@yahoo.com`
2. submit the one-time code
3. observe the post-login landing page

If the browser lands on `chrome-error://chromewebdata/` with a `404` or a Cloudflare `502`, continue.

## Step 3 - Confirm the tunnel is remotely managed

Inspect the live remote tunnel configuration from the Cloudflare dashboard session or Cloudflare API tooling.

Expected indicator:

- tunnel configuration result includes `source: cloudflare`

If the config is remote:

- do not assume edits to local `~/.cloudflared/config.yml` will fix public routing

## Step 4 - Inspect the current remote tunnel config

Check the tunnel route inventory for:

- missing observability hostnames
- duplicate hostnames
- empty `originRequest` blocks

The broken pattern looked like this:

- only app hostnames plus Grafana were present
- observability hostnames like `prometheus.eseosadevbox.com` were missing
- `originRequest` had no `httpHostHeader`
- Grafana had a duplicate route

## Step 5 - Apply the corrected remote tunnel config

The safe target shape is:

- one route per public hostname
- all observability hostnames included
- explicit `httpHostHeader` matching each hostname
- one final catch-all `http_status:404`

Target hostname set:

```text
memflip.eseosadevbox.com
swiftpay.eseosadevbox.com
swiftpay-api.eseosadevbox.com
opensis.eseosadevbox.com
foodpulse.eseosadevbox.com
portfolio.eseosadevbox.com
grafana.eseosadevbox.com
prometheus.eseosadevbox.com
alertmanager.eseosadevbox.com
loki.eseosadevbox.com
node-exporter.eseosadevbox.com
blackbox-exporter.eseosadevbox.com
cadvisor.eseosadevbox.com
promtail.eseosadevbox.com
```

Target tunnel config shape:

```json
{
  "config": {
    "ingress": [
      {
        "hostname": "prometheus.eseosadevbox.com",
        "service": "http://192.168.64.2",
        "originRequest": {
          "httpHostHeader": "prometheus.eseosadevbox.com"
        }
      },
      {
        "hostname": "grafana.eseosadevbox.com",
        "service": "http://192.168.64.2",
        "originRequest": {
          "httpHostHeader": "grafana.eseosadevbox.com"
        }
      },
      {
        "hostname": "alertmanager.eseosadevbox.com",
        "service": "http://192.168.64.2",
        "originRequest": {
          "httpHostHeader": "alertmanager.eseosadevbox.com"
        }
      },
      {
        "hostname": "loki.eseosadevbox.com",
        "service": "http://192.168.64.2",
        "originRequest": {
          "httpHostHeader": "loki.eseosadevbox.com"
        }
      },
      {
        "hostname": "node-exporter.eseosadevbox.com",
        "service": "http://192.168.64.2",
        "originRequest": {
          "httpHostHeader": "node-exporter.eseosadevbox.com"
        }
      },
      {
        "hostname": "blackbox-exporter.eseosadevbox.com",
        "service": "http://192.168.64.2",
        "originRequest": {
          "httpHostHeader": "blackbox-exporter.eseosadevbox.com"
        }
      },
      {
        "hostname": "cadvisor.eseosadevbox.com",
        "service": "http://192.168.64.2",
        "originRequest": {
          "httpHostHeader": "cadvisor.eseosadevbox.com"
        }
      },
      {
        "hostname": "promtail.eseosadevbox.com",
        "service": "http://192.168.64.2",
        "originRequest": {
          "httpHostHeader": "promtail.eseosadevbox.com"
        }
      },
      {
        "service": "http_status:404",
        "originRequest": {}
      }
    ],
    "warp-routing": {
      "enabled": false
    }
  }
}
```

Operational rule:

- if Cloudflare is managing the tunnel remotely, update the remote tunnel config in Cloudflare
- do not rely on the local config file alone

## Step 6 - Re-test in Playwright

Re-open the previously failing hostname.

Example:

```bash
"$PWCLI" goto https://prometheus.eseosadevbox.com/graph
"$PWCLI" snapshot
```

Expected result for Prometheus:

- page title becomes `Prometheus Time Series Collection and Processing Server`
- URL remains under `https://prometheus.eseosadevbox.com/graph...`

Expected result for Grafana:

- page lands on `https://grafana.eseosadevbox.com/login`
- page title becomes `Grafana`

## Step 7 - Confirm public URL inventory still matches the control plane

Check the control-plane platform services API:

```bash
curl -s https://portfolio.eseosadevbox.com/api/services/platform | jq '.services[] | {id, publicUrl}'
```

Expected URLs:

- `prometheus` -> `https://prometheus.eseosadevbox.com/graph`
- `grafana` -> `https://grafana.eseosadevbox.com`
- `alertmanager` -> `https://alertmanager.eseosadevbox.com/#/alerts`
- `loki` -> `https://loki.eseosadevbox.com/metrics`
- `node-exporter` -> `https://node-exporter.eseosadevbox.com`
- `blackbox-exporter` -> `https://blackbox-exporter.eseosadevbox.com`
- `cadvisor` -> `https://cadvisor.eseosadevbox.com/containers/`
- `promtail` -> `https://promtail.eseosadevbox.com/targets`

## Decision rule for future incidents

If a protected observability hostname behaves like this:

- Access login succeeds
- the browser still lands on `404` or `502`
- local Traefik checks work

Then assume this order:

1. verify the Kubernetes service through Traefik locally
2. verify the failure in a real browser with Playwright
3. inspect the remote Cloudflare tunnel config
4. correct hostname coverage and `httpHostHeader`
5. re-test in Playwright

Do not start by weakening Cloudflare Access and do not start by changing the app UI.
