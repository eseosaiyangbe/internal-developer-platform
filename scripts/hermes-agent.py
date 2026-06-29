#!/usr/bin/env python3
"""Hermes Agent: read-only home-lab assistant for platform operators."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parent.parent
OUTPUT_DIR = REPO_ROOT / "output" / "hermes"
DEFAULT_NAMESPACE_ALLOWLIST = [
    "argocd",
    "vault",
    "traefik",
    "platform-observability-dev",
    "platform-observability-prod",
    "swiftpay-dev",
    "foodpulse-dev",
    "memflip-dev",
    "opensis-dev",
]
APP_NAMESPACE_HINTS = {
    "observability-dev": "platform-observability-dev",
    "observability-prod": "platform-observability-prod",
    "swiftpay-dev": "swiftpay-dev",
    "swiftpay-prod": "swiftpay-prod",
    "foodpulse-dev": "foodpulse-dev",
    "foodpulse-prod": "foodpulse-prod",
    "memflip-dev": "memflip-dev",
    "memflip-prod": "memflip-prod",
    "opensis-dev": "opensis-dev",
    "opensis-prod": "opensis-prod",
}


@dataclass
class CommandResult:
    command: list[str]
    returncode: int
    stdout: str
    stderr: str


class HermesError(RuntimeError):
    """Raised when Hermes cannot safely complete a request."""


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def require_command(name: str) -> None:
    if not shutil_which(name):
        raise HermesError(f"required command not found: {name}")


def shutil_which(name: str) -> str | None:
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(directory) / name
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def run_command(command: list[str], check: bool = True) -> CommandResult:
    completed = subprocess.run(
        command,
        text=True,
        capture_output=True,
        cwd=str(REPO_ROOT),
    )
    result = CommandResult(
        command=command,
        returncode=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )
    if check and completed.returncode != 0:
        rendered = " ".join(shlex.quote(part) for part in command)
        stderr = completed.stderr.strip() or completed.stdout.strip() or "unknown error"
        raise HermesError(f"command failed: {rendered}\n{stderr}")
    return result


def run_json(command: list[str]) -> Any:
    result = run_command(command)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        rendered = " ".join(shlex.quote(part) for part in command)
        raise HermesError(f"invalid JSON from command: {rendered}") from exc


def safe_get(mapping: dict[str, Any], *path: str, default: Any = None) -> Any:
    current: Any = mapping
    for key in path:
        if not isinstance(current, dict) or key not in current:
            return default
        current = current[key]
    return current


def truthy_condition(item: dict[str, Any], condition_type: str) -> bool:
    conditions = safe_get(item, "status", "conditions", default=[]) or []
    for condition in conditions:
        if condition.get("type") == condition_type and condition.get("status") == "True":
            return True
    return False


def summarize_nodes() -> list[dict[str, Any]]:
    payload = run_json(["kubectl", "get", "nodes", "-o", "json"])
    summary: list[dict[str, Any]] = []
    for item in payload.get("items", []):
        conditions = {
            condition.get("type"): {
                "status": condition.get("status"),
                "reason": condition.get("reason"),
                "message": condition.get("message"),
            }
            for condition in safe_get(item, "status", "conditions", default=[]) or []
        }
        ready = conditions.get("Ready", {})
        summary.append(
            {
                "name": safe_get(item, "metadata", "name", default="unknown"),
                "ready": ready.get("status") == "True",
                "ready_reason": ready.get("reason", "unknown"),
                "version": safe_get(item, "status", "nodeInfo", "kubeletVersion", default="unknown"),
                "os_image": safe_get(item, "status", "nodeInfo", "osImage", default="unknown"),
            }
        )
    return summary


def summarize_pods(namespaces: list[str] | None = None) -> dict[str, Any]:
    command = ["kubectl", "get", "pods", "-A", "-o", "json"]
    payload = run_json(command)
    items = payload.get("items", [])
    if namespaces:
        items = [item for item in items if safe_get(item, "metadata", "namespace") in namespaces]
    pods: list[dict[str, Any]] = []
    unhealthy: list[dict[str, Any]] = []
    for item in items:
        namespace = safe_get(item, "metadata", "namespace", default="unknown")
        name = safe_get(item, "metadata", "name", default="unknown")
        phase = safe_get(item, "status", "phase", default="Unknown")
        restarts = sum(
            int(container.get("restartCount", 0))
            for container in safe_get(item, "status", "containerStatuses", default=[]) or []
        )
        ready = all(
            container.get("ready", False)
            for container in safe_get(item, "status", "containerStatuses", default=[]) or []
        )
        pod = {
            "namespace": namespace,
            "name": name,
            "phase": phase,
            "ready": ready,
            "restarts": restarts,
        }
        pods.append(pod)
        if phase == "Succeeded":
            continue
        if phase != "Running" or not ready or restarts > 0:
            unhealthy.append(pod)
    return {"pods": pods, "unhealthy": unhealthy}


def summarize_argocd() -> dict[str, Any]:
    payload = run_json(["kubectl", "get", "applications.argoproj.io", "-A", "-o", "json"])
    applications: list[dict[str, Any]] = []
    degraded: list[dict[str, Any]] = []
    for item in payload.get("items", []):
        app = {
            "namespace": safe_get(item, "metadata", "namespace", default="unknown"),
            "name": safe_get(item, "metadata", "name", default="unknown"),
            "sync": safe_get(item, "status", "sync", "status", default="Unknown"),
            "health": safe_get(item, "status", "health", "status", default="Unknown"),
            "revision": safe_get(item, "status", "sync", "revision", default="unknown"),
        }
        applications.append(app)
        if app["sync"] != "Synced" or app["health"] != "Healthy":
            degraded.append(app)
    return {"applications": applications, "degraded": degraded}


def summarize_events(limit: int) -> list[dict[str, Any]]:
    payload = run_json(["kubectl", "get", "events", "-A", "-o", "json"])
    items = payload.get("items", [])

    def sort_key(item: dict[str, Any]) -> str:
        return (
            item.get("eventTime")
            or safe_get(item, "series", "lastObservedTime", default="")
            or item.get("lastTimestamp")
            or safe_get(item, "metadata", "creationTimestamp", default="")
        )

    items = sorted(items, key=sort_key, reverse=True)
    summary: list[dict[str, Any]] = []
    for item in items[:limit]:
        summary.append(
            {
                "namespace": safe_get(item, "metadata", "namespace", default="unknown"),
                "reason": item.get("reason", "unknown"),
                "type": item.get("type", "Normal"),
                "message": item.get("message", "").strip(),
                "object": safe_get(item, "involvedObject", "name", default="unknown"),
                "timestamp": sort_key(item),
            }
        )
    return summary


def summarize_cluster_health(event_limit: int, namespaces: list[str] | None) -> dict[str, Any]:
    context = run_command(["kubectl", "config", "current-context"]).stdout.strip() or "unknown"
    nodes = summarize_nodes()
    pod_summary = summarize_pods(namespaces)
    argocd = summarize_argocd()
    events = summarize_events(event_limit)
    severity = "healthy"
    findings: list[str] = []
    if any(not node["ready"] for node in nodes):
        severity = "critical"
        findings.append("At least one Kubernetes node is not Ready.")
    if pod_summary["unhealthy"] and severity != "critical":
        severity = "warning"
        findings.append("One or more pods are not fully healthy or have restarts.")
    if argocd["degraded"] and severity == "healthy":
        severity = "warning"
        findings.append("ArgoCD reports at least one application as out of sync or not healthy.")
    if not findings:
        findings.append("No immediate cluster-wide health regressions were detected in the inspected surfaces.")
    return {
        "timestamp": now_utc(),
        "context": context,
        "severity": severity,
        "nodes": nodes,
        "pods": pod_summary["pods"],
        "unhealthy_pods": pod_summary["unhealthy"],
        "argocd": argocd,
        "recent_events": events,
        "findings": findings,
    }


def read_logs(
    namespace: str,
    resource: str | None,
    selector: str | None,
    container: str | None,
    tail: int,
) -> dict[str, Any]:
    if bool(resource) == bool(selector):
        raise HermesError("provide exactly one of --resource or --selector")

    target_description: str
    command: list[str]
    if resource:
        target_description = resource
        command = ["kubectl", "logs", "-n", namespace, resource, "--tail", str(tail)]
        if container:
            command.extend(["-c", container])
    else:
        pods_payload = run_json(["kubectl", "get", "pods", "-n", namespace, "-l", selector or "", "-o", "json"])
        items = pods_payload.get("items", [])
        if not items:
            raise HermesError(f"no pods found for selector in namespace {namespace}: {selector}")
        pod_name = safe_get(items[0], "metadata", "name", default="")
        if not pod_name:
            raise HermesError("failed to resolve pod name from selector")
        target_description = f"pod/{pod_name}"
        command = ["kubectl", "logs", "-n", namespace, pod_name, "--tail", str(tail)]
        if container:
            command.extend(["-c", container])

    result = run_command(command)
    lines = result.stdout.splitlines()
    warnings = [line for line in lines if any(token in line.lower() for token in ["error", "fail", "exception", "panic", "timeout"])]
    return {
        "timestamp": now_utc(),
        "namespace": namespace,
        "target": target_description,
        "tail": tail,
        "line_count": len(lines),
        "warning_line_count": len(warnings),
        "sample": lines[-tail:] if tail < len(lines) else lines,
    }


def proposed_remediations(health: dict[str, Any], incident_title: str | None = None) -> list[dict[str, Any]]:
    actions: list[dict[str, Any]] = []
    for node in health["nodes"]:
        if not node["ready"]:
            actions.append(
                {
                    "severity": "critical",
                    "finding": f"Node {node['name']} is not Ready.",
                    "recommendation": "Inspect node conditions and kube-system controllers before touching workloads.",
                    "manual_commands": [
                        f"kubectl describe node {node['name']}",
                        "kubectl get pods -n kube-system -o wide",
                        "kubectl get events -A --sort-by=.lastTimestamp | tail -n 50",
                    ],
                }
            )

    for pod in health["unhealthy_pods"][:8]:
        actions.append(
            {
                "severity": "warning" if pod["phase"] == "Running" else "critical",
                "finding": f"Pod {pod['namespace']}/{pod['name']} is phase={pod['phase']} ready={pod['ready']} restarts={pod['restarts']}.",
                "recommendation": "Inspect pod events and recent logs before deciding on any restart or rollback.",
                "manual_commands": [
                    f"kubectl describe pod {pod['name']} -n {pod['namespace']}",
                    f"kubectl logs -n {pod['namespace']} {pod['name']} --tail=120",
                ],
            }
        )

    for app in health["argocd"]["degraded"]:
        actions.append(
            {
                "severity": "warning",
                "finding": f"ArgoCD application {app['name']} is sync={app['sync']} health={app['health']}.",
                "recommendation": "Verify whether the issue is Git drift, controller comparison noise, or live workload health.",
                "manual_commands": [
                    f"kubectl get application {app['name']} -n {app['namespace']} -o yaml",
                    f"kubectl describe application {app['name']} -n {app['namespace']}",
                ],
            }
        )

    if not actions:
        actions.append(
            {
                "severity": "info",
                "finding": incident_title or "No acute regressions detected.",
                "recommendation": "Continue routine observation. No remediation proposal is warranted from the current signals.",
                "manual_commands": [],
            }
        )
    return actions


def build_incident_note(
    title: str,
    summary: str | None,
    health: dict[str, Any],
    remediation: list[dict[str, Any]],
) -> str:
    lines = [
        f"# Incident Note: {title}",
        "",
        f"- Generated: `{health['timestamp']}`",
        f"- Kubernetes context: `{health['context']}`",
        f"- Assessed severity: `{health['severity']}`",
        "",
        "## Summary",
        "",
        summary or "Hermes generated this note from the current cluster and ArgoCD read-only status surfaces.",
        "",
        "## Current Findings",
        "",
    ]
    for finding in health["findings"]:
        lines.append(f"- {finding}")
    lines.extend(["", "## Node Status", ""])
    for node in health["nodes"]:
        lines.append(
            f"- `{node['name']}`: ready=`{node['ready']}` reason=`{node['ready_reason']}` version=`{node['version']}`"
        )
    lines.extend(["", "## ArgoCD Status", ""])
    for app in health["argocd"]["applications"]:
        lines.append(
            f"- `{app['name']}`: sync=`{app['sync']}` health=`{app['health']}` revision=`{app['revision']}`"
        )
    lines.extend(["", "## Unhealthy Pods", ""])
    if health["unhealthy_pods"]:
        for pod in health["unhealthy_pods"]:
            lines.append(
                f"- `{pod['namespace']}/{pod['name']}`: phase=`{pod['phase']}` ready=`{pod['ready']}` restarts=`{pod['restarts']}`"
            )
    else:
        lines.append("- None detected in the inspected namespaces.")
    lines.extend(["", "## Proposed Manual Remediation Steps", ""])
    for action in remediation:
        lines.append(f"- Finding: {action['finding']}")
        lines.append(f"  Recommendation: {action['recommendation']}")
        if action["manual_commands"]:
            lines.append("  Manual commands:")
            for command in action["manual_commands"]:
                lines.append(f"  - `{command}`")
    lines.extend(
        [
            "",
            "## Control Guardrail",
            "",
            "Hermes Agent is intentionally read-only.",
            "No changes were applied to Kubernetes, ArgoCD, or the underlying hosts.",
            "Any remediation command above requires explicit manual operator approval and execution.",
            "",
        ]
    )
    return "\n".join(lines)


def write_output_file(prefix: str, content: str) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    path = OUTPUT_DIR / f"{prefix}-{timestamp}.md"
    path.write_text(content, encoding="utf-8")
    return path


def print_json(data: Any) -> None:
    json.dump(data, sys.stdout, indent=2)
    sys.stdout.write("\n")


def print_text_health(summary: dict[str, Any]) -> None:
    print(f"Hermes cluster health summary at {summary['timestamp']}")
    print(f"Context: {summary['context']}")
    print(f"Severity: {summary['severity']}")
    print("Findings:")
    for finding in summary["findings"]:
        print(f"- {finding}")
    print("Nodes:")
    for node in summary["nodes"]:
        print(f"- {node['name']}: ready={node['ready']} reason={node['ready_reason']} version={node['version']}")
    print("ArgoCD:")
    for app in summary["argocd"]["applications"]:
        print(f"- {app['name']}: sync={app['sync']} health={app['health']}")
    print("Unhealthy pods:")
    if summary["unhealthy_pods"]:
        for pod in summary["unhealthy_pods"]:
            print(f"- {pod['namespace']}/{pod['name']}: phase={pod['phase']} ready={pod['ready']} restarts={pod['restarts']}")
    else:
        print("- none")


def print_text_argocd(summary: dict[str, Any]) -> None:
    print("Hermes ArgoCD sync summary")
    for app in summary["applications"]:
        print(f"- {app['name']} ({app['namespace']}): sync={app['sync']} health={app['health']} revision={app['revision']}")
    if summary["degraded"]:
        print("Degraded applications:")
        for app in summary["degraded"]:
            print(f"- {app['name']}: sync={app['sync']} health={app['health']}")


def print_text_logs(summary: dict[str, Any]) -> None:
    print(f"Hermes log snapshot for {summary['target']} in {summary['namespace']}")
    print(f"Tail lines: {summary['tail']}")
    print(f"Warning lines detected: {summary['warning_line_count']}")
    print("---")
    for line in summary["sample"]:
        print(line)


def print_text_remediation(actions: list[dict[str, Any]]) -> None:
    print("Hermes proposed manual remediation steps")
    for action in actions:
        print(f"- Severity: {action['severity']}")
        print(f"  Finding: {action['finding']}")
        print(f"  Recommendation: {action['recommendation']}")
        if action["manual_commands"]:
            print("  Manual commands:")
            for command in action["manual_commands"]:
                print(f"  - {command}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Hermes Agent is a read-only home-lab assistant for Kubernetes, ArgoCD, "
            "logs, incident notes, and remediation proposals."
        )
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    health_parser = subparsers.add_parser("health", help="Inspect Kubernetes health surfaces")
    health_parser.add_argument("--event-limit", type=int, default=15, help="Number of recent events to include")
    health_parser.add_argument(
        "--namespace",
        action="append",
        dest="namespaces",
        help="Restrict pod inspection to one or more namespaces",
    )
    health_parser.add_argument("--format", choices=["text", "json"], default="text")

    argocd_parser = subparsers.add_parser("argocd", help="Summarize ArgoCD application sync and health")
    argocd_parser.add_argument("--format", choices=["text", "json"], default="text")

    logs_parser = subparsers.add_parser("logs", help="Read recent Kubernetes logs without mutating state")
    logs_parser.add_argument("--namespace", required=True)
    logs_group = logs_parser.add_mutually_exclusive_group(required=True)
    logs_group.add_argument("--resource", help="Resource reference such as deployment/foo or pod/bar")
    logs_group.add_argument("--selector", help="Pod label selector")
    logs_parser.add_argument("--container", help="Container name for multi-container pods")
    logs_parser.add_argument("--tail", type=int, default=80)
    logs_parser.add_argument("--format", choices=["text", "json"], default="text")

    note_parser = subparsers.add_parser("incident-note", help="Generate a markdown incident note from live status")
    note_parser.add_argument("--title", required=True)
    note_parser.add_argument("--summary", help="Optional operator summary override")
    note_parser.add_argument("--write", action="store_true", help="Write the note to output/hermes")
    note_parser.add_argument(
        "--namespace",
        action="append",
        dest="namespaces",
        help="Restrict pod inspection to one or more namespaces",
    )

    remediation_parser = subparsers.add_parser("remediate", help="Propose manual remediation steps")
    remediation_parser.add_argument("--incident-title", help="Optional incident title to carry into the proposal")
    remediation_parser.add_argument(
        "--namespace",
        action="append",
        dest="namespaces",
        help="Restrict pod inspection to one or more namespaces",
    )
    remediation_parser.add_argument("--format", choices=["text", "json"], default="text")

    approve_parser = subparsers.add_parser(
        "approve",
        help="Guardrail placeholder that refuses automatic mutation and requires manual operator execution",
    )
    approve_parser.add_argument("requested_action", nargs="?", help="Optional action description")
    return parser.parse_args()


def handle_health(args: argparse.Namespace) -> int:
    namespaces = args.namespaces or DEFAULT_NAMESPACE_ALLOWLIST
    summary = summarize_cluster_health(args.event_limit, namespaces)
    if args.format == "json":
        print_json(summary)
    else:
        print_text_health(summary)
    return 0


def handle_argocd(args: argparse.Namespace) -> int:
    summary = summarize_argocd()
    if args.format == "json":
        print_json(summary)
    else:
        print_text_argocd(summary)
    return 0


def handle_logs(args: argparse.Namespace) -> int:
    summary = read_logs(args.namespace, args.resource, args.selector, args.container, args.tail)
    if args.format == "json":
        print_json(summary)
    else:
        print_text_logs(summary)
    return 0


def handle_incident_note(args: argparse.Namespace) -> int:
    namespaces = args.namespaces or DEFAULT_NAMESPACE_ALLOWLIST
    health = summarize_cluster_health(15, namespaces)
    remediation = proposed_remediations(health, args.title)
    note = build_incident_note(args.title, args.summary, health, remediation)
    print(note)
    if args.write:
        path = write_output_file("incident-note", note)
        print(f"\nWrote incident note to {path}", file=sys.stderr)
    return 0


def handle_remediate(args: argparse.Namespace) -> int:
    namespaces = args.namespaces or DEFAULT_NAMESPACE_ALLOWLIST
    health = summarize_cluster_health(15, namespaces)
    actions = proposed_remediations(health, args.incident_title)
    payload = {
        "timestamp": health["timestamp"],
        "severity": health["severity"],
        "actions": actions,
        "guardrail": "Hermes Agent does not apply changes. Manual operator approval is required.",
    }
    if args.format == "json":
        print_json(payload)
    else:
        print_text_remediation(actions)
        print("Guardrail: Hermes Agent did not execute any change. Manual approval is required.")
    return 0


def handle_approve(args: argparse.Namespace) -> int:
    requested = args.requested_action or "unspecified action"
    print("Hermes Agent refused automatic execution.")
    print(f"Requested action: {requested}")
    print("Reason: this assistant is intentionally read-only.")
    print("Next step: copy the proposed manual command, review it, and run it yourself after approval.")
    return 2


def main() -> int:
    try:
        require_command("kubectl")
        args = parse_args()
        if args.command == "health":
            return handle_health(args)
        if args.command == "argocd":
            return handle_argocd(args)
        if args.command == "logs":
            return handle_logs(args)
        if args.command == "incident-note":
            return handle_incident_note(args)
        if args.command == "remediate":
            return handle_remediate(args)
        if args.command == "approve":
            return handle_approve(args)
        raise HermesError(f"unsupported command: {args.command}")
    except HermesError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
