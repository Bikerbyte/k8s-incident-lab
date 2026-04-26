#!/usr/bin/env python3
from __future__ import annotations

import json
import mimetypes
import os
import re
import socket
import subprocess
import threading
import time
import urllib.parse
from html import escape
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
STATIC_DIR = REPO_ROOT / "console" / "static"
SCREENSHOT_DIR = REPO_ROOT / "docs" / "screenshots"


@dataclass(frozen=True)
class Action:
    slug: str
    label: str
    description: str
    command: list[str]
    dangerous: bool = False


ACTIONS: dict[str, Action] = {
    "deploy-app": Action(
        slug="deploy-app",
        label="Deploy App",
        description="Apply the Podinfo manifests and wait for rollout.",
        command=["bash", "scripts/deploy-app.sh"],
    ),
    "install-monitoring": Action(
        slug="install-monitoring",
        label="Install Monitoring",
        description="Install Prometheus, Grafana, Loki, and Promtail.",
        command=["bash", "scripts/install-monitoring.sh"],
    ),
    "open-local-access": Action(
        slug="open-local-access",
        label="Open Local Access",
        description="Start Grafana, Prometheus, and Podinfo port-forwards.",
        command=["bash", "scripts/port-forward.sh"],
    ),
    "stop-local-access": Action(
        slug="stop-local-access",
        label="Stop Local Access",
        description="Stop Grafana, Prometheus, and Podinfo port-forwards.",
        command=["bash", "scripts/stop-port-forward.sh"],
    ),
    "check-lab-status": Action(
        slug="check-lab-status",
        label="Check Lab Status",
        description="Print tool, cluster, workload, and localhost access status.",
        command=["bash", "scripts/status.sh"],
    ),
    "show-alerts": Action(
        slug="show-alerts",
        label="Show Alerts",
        description="Query Prometheus for current incident lab alert states.",
        command=["bash", "scripts/show-alerts.sh"],
    ),
    "trigger-readiness-failure": Action(
        slug="trigger-readiness-failure",
        label="Trigger Readiness Failure",
        description="Patch Podinfo so a new pod stays Running but Not Ready.",
        command=["bash", "scripts/trigger-readiness-failure.sh"],
    ),
    "restore-readiness": Action(
        slug="restore-readiness",
        label="Restore Readiness",
        description="Restore the Podinfo readiness probe and wait for recovery.",
        command=["bash", "scripts/restore-readiness.sh"],
    ),
    "generate-errors": Action(
        slug="generate-errors",
        label="Generate Errors",
        description="Send repeated HTTP 500 requests to Podinfo.",
        command=["bash", "scripts/generate-errors.sh"],
    ),
    "trigger-self-healing": Action(
        slug="trigger-self-healing",
        label="Trigger Self-Healing",
        description="Delete one Podinfo pod and let the Deployment recreate it.",
        command=["bash", "scripts/trigger-pod-self-healing.sh"],
    ),
    "cleanup": Action(
        slug="cleanup",
        label="Cleanup Lab",
        description="Remove app and monitoring resources from the cluster.",
        command=["bash", "scripts/cleanup.sh"],
        dangerous=True,
    ),
    "capture-grafana": Action(
        slug="capture-grafana",
        label="Capture Grafana",
        description="Capture the current Grafana dashboard to docs/screenshots/grafana-normal.png.",
        command=["bash", "scripts/capture-grafana-screenshot.sh", "docs/screenshots/grafana-normal.png"],
    ),
}


JOB_LOCK = threading.Lock()
JOBS: dict[str, dict[str, Any]] = {}
JOB_ORDER: list[str] = []


def run_command(command: list[str], timeout: int = 20) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode(errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode(errors="replace")
        stderr = f"{stderr}\nCommand timed out after {timeout} seconds.".strip()
        return subprocess.CompletedProcess(command, 124, stdout, stderr)
    except OSError as exc:
        return subprocess.CompletedProcess(command, 127, "", str(exc))


def command_output(command: list[str], timeout: int = 20) -> str:
    result = run_command(command, timeout=timeout)
    return (result.stdout + result.stderr).strip()


def bool_tool(name: str) -> bool:
    return bool(command_output(["bash", "-lc", f"command -v {name} || true"]))


def is_port_listening(port: int) -> bool:
    result = run_command(["bash", "-lc", f"ss -ltn 'sport = :{port}' | grep -q LISTEN"])
    return result.returncode == 0


def minikube_status() -> dict[str, Any]:
    raw = command_output(["bash", "-lc", "minikube status || true"])
    data: dict[str, str] = {}
    for line in raw.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if key in {"host", "kubelet", "apiserver", "kubeconfig", "type"}:
            data[key] = value
    return {"raw": raw, **data}


def cluster_reachable() -> bool:
    return run_command(["kubectl", "cluster-info"], timeout=15).returncode == 0


def kubectl_json(args: list[str], timeout: int = 20) -> dict[str, Any] | None:
    result = run_command(["kubectl", *args], timeout=timeout)
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def summarize_deployments(namespace: str) -> list[dict[str, Any]]:
    payload = kubectl_json(["-n", namespace, "get", "deployments", "-o", "json"])
    items = payload.get("items", []) if payload else []
    deployments = []
    for item in items:
        status = item.get("status", {})
        deployments.append(
            {
                "name": item["metadata"]["name"],
                "ready": f"{status.get('readyReplicas', 0)}/{status.get('replicas', 0)}",
                "available": status.get("availableReplicas", 0),
                "updated": status.get("updatedReplicas", 0),
            }
        )
    return deployments


def summarize_pods(namespace: str) -> list[dict[str, Any]]:
    payload = kubectl_json(["-n", namespace, "get", "pods", "-o", "json"])
    items = payload.get("items", []) if payload else []
    pods = []
    for item in items:
        statuses = item.get("status", {}).get("containerStatuses", [])
        ready_count = sum(1 for status in statuses if status.get("ready"))
        pods.append(
            {
                "name": item["metadata"]["name"],
                "ready": f"{ready_count}/{len(statuses)}",
                "phase": item.get("status", {}).get("phase", "Unknown"),
                "restarts": sum(status.get("restartCount", 0) for status in statuses),
            }
        )
    return pods


def summarize_services(namespace: str) -> list[dict[str, Any]]:
    payload = kubectl_json(["-n", namespace, "get", "services", "-o", "json"])
    items = payload.get("items", []) if payload else []
    services = []
    for item in items:
        ports = item.get("spec", {}).get("ports", [])
        services.append(
            {
                "name": item["metadata"]["name"],
                "type": item.get("spec", {}).get("type", "ClusterIP"),
                "ports": ", ".join(str(port.get("port")) for port in ports) or "-",
            }
        )
    return services


def summarize_nodes() -> list[dict[str, Any]]:
    payload = kubectl_json(["get", "nodes", "-o", "json"])
    items = payload.get("items", []) if payload else []
    nodes = []
    for item in items:
        conditions = item.get("status", {}).get("conditions", [])
        ready = next((cond.get("status") for cond in conditions if cond.get("type") == "Ready"), "Unknown")
        nodes.append(
            {
                "name": item["metadata"]["name"],
                "ready": "Ready" if ready == "True" else str(ready),
                "version": item.get("status", {}).get("nodeInfo", {}).get("kubeletVersion", ""),
                "roles": ",".join(item.get("metadata", {}).get("labels", {}).keys()),
            }
        )
    return nodes


def screenshot_entries() -> list[dict[str, str]]:
    entries = []
    for path in sorted(SCREENSHOT_DIR.glob("*.png")):
        entries.append(
            {
                "name": path.name,
                "title": path.stem.replace("-", " ").title(),
                "url": f"/screenshots/{path.name}",
            }
        )
    return entries


def status_payload() -> dict[str, Any]:
    reachable = cluster_reachable()
    return {
        "generatedAt": int(time.time()),
        "tools": {
            "kubectl": bool_tool("kubectl"),
            "helm": bool_tool("helm"),
            "minikube": bool_tool("minikube"),
            "curl": bool_tool("curl"),
        },
        "minikube": minikube_status(),
        "cluster": {
            "reachable": reachable,
            "nodes": summarize_nodes() if reachable else [],
        },
        "workloads": {
            "app": {
                "namespace": "incident-lab",
                "deployments": summarize_deployments("incident-lab") if reachable else [],
                "pods": summarize_pods("incident-lab") if reachable else [],
                "services": summarize_services("incident-lab") if reachable else [],
            },
            "monitoring": {
                "namespace": "monitoring",
                "deployments": summarize_deployments("monitoring") if reachable else [],
                "pods": summarize_pods("monitoring") if reachable else [],
                "services": summarize_services("monitoring") if reachable else [],
            },
        },
        "localAccess": {
            "grafana": {"listening": is_port_listening(3000), "url": "http://localhost:3000"},
            "podinfo": {"listening": is_port_listening(9898), "url": "http://localhost:9898"},
            "prometheus": {"listening": is_port_listening(9090), "url": "http://localhost:9090"},
        },
        "actions": [
            {
                "slug": action.slug,
                "label": action.label,
                "description": action.description,
                "command": " ".join(action.command),
                "dangerous": action.dangerous,
            }
            for action in ACTIONS.values()
        ],
        "screenshots": screenshot_entries(),
    }


def trim_jobs() -> None:
    while len(JOB_ORDER) > 20:
        job_id = JOB_ORDER.pop(0)
        JOBS.pop(job_id, None)


def create_job(action: Action) -> dict[str, Any]:
    job_id = f"job-{int(time.time() * 1000)}"
    job = {
        "id": job_id,
        "action": action.slug,
        "label": action.label,
        "command": action.command,
        "status": "running",
        "output": "",
        "createdAt": int(time.time()),
        "returncode": None,
    }
    with JOB_LOCK:
        JOBS[job_id] = job
        JOB_ORDER.append(job_id)
        trim_jobs()
    return job


def append_job_output(job_id: str, chunk: str) -> None:
    with JOB_LOCK:
        job = JOBS.get(job_id)
        if not job:
            return
        job["output"] += chunk


def finish_job(job_id: str, status: str, returncode: int | None) -> None:
    with JOB_LOCK:
        job = JOBS.get(job_id)
        if not job:
            return
        job["status"] = status
        job["returncode"] = returncode
        job["finishedAt"] = int(time.time())


def run_job(job_id: str, action: Action) -> None:
    process = subprocess.Popen(
        action.command,
        cwd=REPO_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    assert process.stdout is not None
    for line in process.stdout:
        append_job_output(job_id, line)
    process.wait()
    status = "succeeded" if process.returncode == 0 else "failed"
    finish_job(job_id, status, process.returncode)


def start_job(action: Action) -> dict[str, Any]:
    job = create_job(action)
    thread = threading.Thread(target=run_job, args=(job["id"], action), daemon=True)
    thread.start()
    return job


def latest_jobs() -> list[dict[str, Any]]:
    with JOB_LOCK:
        return [JOBS[job_id].copy() for job_id in reversed(JOB_ORDER[-8:])]


def inline_markdown(text: str) -> str:
    escaped = escape(text)
    escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
    escaped = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', escaped)
    return escaped


def table_html(lines: list[str]) -> str:
    rows = [[cell.strip() for cell in line.strip().strip("|").split("|")] for line in lines]
    if len(rows) < 2:
        return ""
    header = rows[0]
    body = rows[2:]
    thead = "<thead><tr>" + "".join(f"<th>{inline_markdown(cell)}</th>" for cell in header) + "</tr></thead>"
    tbody_rows = []
    for row in body:
        padded = row + [""] * max(0, len(header) - len(row))
        cells = "".join(f"<td>{inline_markdown(cell)}</td>" for cell in padded[: len(header)])
        tbody_rows.append(f"<tr>{cells}</tr>")
    return f"<table>{thead}<tbody>{''.join(tbody_rows)}</tbody></table>"


def render_markdown(markdown: str) -> str:
    lines = markdown.splitlines()
    output: list[str] = []
    paragraph: list[str] = []
    list_items: list[str] = []
    code_lines: list[str] = []
    table_lines: list[str] = []
    in_code = False

    def flush_paragraph() -> None:
        if paragraph:
            output.append(f"<p>{inline_markdown(' '.join(paragraph))}</p>")
            paragraph.clear()

    def flush_list() -> None:
        if list_items:
            output.append("<ul>" + "".join(f"<li>{item}</li>" for item in list_items) + "</ul>")
            list_items.clear()

    def flush_table() -> None:
        if table_lines:
            html = table_html(table_lines)
            if html:
                output.append(html)
            table_lines.clear()

    for raw_line in lines:
        line = raw_line.rstrip()
        stripped = line.strip()

        if stripped.startswith("```"):
            if in_code:
                output.append(f"<pre><code>{escape(chr(10).join(code_lines))}</code></pre>")
                code_lines.clear()
                in_code = False
            else:
                flush_paragraph()
                flush_list()
                flush_table()
                in_code = True
            continue

        if in_code:
            code_lines.append(line)
            continue

        if not stripped:
            flush_paragraph()
            flush_list()
            flush_table()
            continue

        if stripped.startswith("|") and stripped.endswith("|"):
            flush_paragraph()
            flush_list()
            table_lines.append(stripped)
            continue

        flush_table()

        heading = re.match(r"^(#{1,6})\s+(.+)$", stripped)
        if heading:
            flush_paragraph()
            flush_list()
            level = len(heading.group(1))
            output.append(f"<h{level}>{inline_markdown(heading.group(2))}</h{level}>")
            continue

        unordered = re.match(r"^[-*]\s+(.+)$", stripped)
        if unordered:
            flush_paragraph()
            list_items.append(inline_markdown(unordered.group(1)))
            continue

        ordered = re.match(r"^\d+\.\s+(.+)$", stripped)
        if ordered:
            flush_paragraph()
            list_items.append(inline_markdown(ordered.group(1)))
            continue

        flush_list()
        paragraph.append(stripped)

    flush_paragraph()
    flush_list()
    flush_table()
    if in_code:
        output.append(f"<pre><code>{escape(chr(10).join(code_lines))}</code></pre>")
    return "\n".join(output)


def markdown_page(path: Path) -> bytes:
    markdown = path.read_text(encoding="utf-8")
    title = path.stem.replace("-", " ").title()
    body = render_markdown(markdown)
    html = f"""<!doctype html>
<html lang="en" data-theme="night">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{escape(title)} | K8s Incident Lab</title>
    <link rel="stylesheet" href="/static/styles.css">
  </head>
  <body>
    <main class="markdown-page">
      <nav class="markdown-nav">
        <a class="button" href="/">Back to Console</a>
        <a class="button" href="{escape('/' + path.relative_to(REPO_ROOT).as_posix())}?raw=1">Raw Markdown</a>
      </nav>
      <article class="markdown-body">
        {body}
      </article>
    </main>
  </body>
</html>
"""
    return html.encode("utf-8")


class ConsoleHandler(BaseHTTPRequestHandler):
    server_version = "LabConsole/0.1"

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        if path == "/":
            self.serve_file(STATIC_DIR / "index.html", "text/html; charset=utf-8")
            return
        if path.startswith("/static/"):
            target = STATIC_DIR / path.removeprefix("/static/")
            self.serve_file(target)
            return
        if path.startswith("/screenshots/"):
            target = SCREENSHOT_DIR / path.removeprefix("/screenshots/")
            self.serve_file(target)
            return
        if path.startswith("/docs/") or path.startswith("/runbooks/"):
            target = REPO_ROOT / path.removeprefix("/")
            if parsed.query == "raw=1":
                self.serve_file(target, "text/markdown; charset=utf-8")
            else:
                self.serve_markdown(target)
            return
        if path == "/api/status":
            self.send_json(status_payload())
            return
        if path == "/api/jobs":
            self.send_json({"jobs": latest_jobs()})
            return
        if path.startswith("/api/jobs/"):
            job_id = path.removeprefix("/api/jobs/")
            with JOB_LOCK:
                job = JOBS.get(job_id)
            if job is None:
                self.send_error(HTTPStatus.NOT_FOUND, "Unknown job")
                return
            self.send_json(job)
            return
        self.send_error(HTTPStatus.NOT_FOUND, "Not found")

    def do_POST(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        if not parsed.path.startswith("/api/actions/"):
            self.send_error(HTTPStatus.NOT_FOUND, "Not found")
            return
        slug = parsed.path.removeprefix("/api/actions/")
        action = ACTIONS.get(slug)
        if action is None:
            self.send_error(HTTPStatus.NOT_FOUND, "Unknown action")
            return
        job = start_job(action)
        self.send_json({"job": job}, status=HTTPStatus.ACCEPTED)

    def log_message(self, fmt: str, *args: Any) -> None:
        return

    def serve_file(self, path: Path, content_type: str | None = None) -> None:
        try:
            path.resolve().relative_to(REPO_ROOT)
        except ValueError:
            self.send_error(HTTPStatus.NOT_FOUND, "Missing file")
            return
        if not path.exists() or not path.is_file():
            self.send_error(HTTPStatus.NOT_FOUND, "Missing file")
            return
        guessed_type = content_type or mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        data = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", guessed_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            return

    def serve_markdown(self, path: Path) -> None:
        try:
            path.resolve().relative_to(REPO_ROOT)
        except ValueError:
            self.send_error(HTTPStatus.NOT_FOUND, "Missing file")
            return
        if not path.exists() or not path.is_file() or path.suffix != ".md":
            self.send_error(HTTPStatus.NOT_FOUND, "Missing file")
            return
        data = markdown_page(path)
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            return

    def send_json(self, payload: Any, status: HTTPStatus = HTTPStatus.OK) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            return


def pick_port(preferred: int = 8787) -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        if sock.connect_ex(("127.0.0.1", preferred)) != 0:
            return preferred
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def main() -> None:
    port = int(os.environ.get("LAB_CONSOLE_PORT", pick_port()))
    server = ThreadingHTTPServer(("127.0.0.1", port), ConsoleHandler)
    print(f"Lab Console running at http://127.0.0.1:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nLab Console stopped.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
