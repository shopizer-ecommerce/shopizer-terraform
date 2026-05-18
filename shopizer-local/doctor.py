from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Literal


Status = Literal["ok", "warn", "fail"]


@dataclass
class CheckResult:
    name: str
    status: Status
    message: str
    fix: str | None = None
    details: str | None = None


def run(
    cmd: list[str],
    *,
    cwd: str | None = None,
    check: bool = False,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=check,
    )


def ok(name: str, message: str, details: str | None = None) -> CheckResult:
    return CheckResult(name=name, status="ok", message=message, details=details)


def warn(
    name: str, message: str, fix: str | None = None, details: str | None = None
) -> CheckResult:
    return CheckResult(
        name=name, status="warn", message=message, fix=fix, details=details
    )


def fail(
    name: str, message: str, fix: str | None = None, details: str | None = None
) -> CheckResult:
    return CheckResult(
        name=name, status="fail", message=message, fix=fix, details=details
    )


def tool_version(cmd: list[str]) -> str | None:
    try:
        result = run(cmd)
    except Exception:
        return None
    if result.returncode != 0:
        return None
    text = (result.stdout or result.stderr).strip()
    first_line = text.splitlines()[0] if text else ""
    return first_line or None


def check_command_exists(name: str, version_cmd: list[str]) -> CheckResult:
    if shutil.which(name) is None:
        return fail(
            f"cmd:{name}",
            f"{name} is not installed",
            fix=f"Install {name} and ensure it is on PATH.",
        )
    version = tool_version(version_cmd)
    return ok(f"cmd:{name}", f"{name} is installed", details=version)


def check_version_is_higher(name: str, version_curr: list[str], version_required: int):
    if shutil.which(name) is None:
        return fail(
            f"cmd:{name}",
            f"{name} is not installed",
            fix=f"Install {name} and ensure it is on PATH.",
        )
    version = tool_version(version_curr)
    version_req = str(version_required)
    if version >= version_req:
        return ok(
            f"cmd:{name}",
            f"{name} is installed and is greater than the required version {version_required}",
            details=version,
        )


def check_directory(env_name: str) -> CheckResult:
    value = os.environ.get(env_name)
    if not value:
        return fail(
            f"dir:{env_name}",
            f"{env_name} is not set",
            fix=f"Export {env_name}=/absolute/path",
        )
    path = Path(value)
    if not path.exists():
        return fail(
            f"dir:{env_name}",
            f"{env_name} does not exist: {path}",
            fix="Fix the path in your environment or playbook vars.",
        )
    if not path.is_dir():
        return fail(
            f"dir:{env_name}",
            f"{env_name} is not a directory: {path}",
        )
    return ok(f"dir:{env_name}", f"{env_name} exists", details=str(path))


def check_env_var(name: str, *, secret: bool = False) -> CheckResult:
    value = os.environ.get(name)
    if not value:
        return fail(
            f"env:{name}",
            f"{name} is not set",
            fix=f"Export {name}=...",
        )
    shown = "<set>" if secret else value
    return ok(f"env:{name}", f"{name} is set", details=shown)


def check_host_resolution(hostname: str, expected_ip: str | None = None) -> CheckResult:
    try:
        resolved = socket.gethostbyname(hostname)
    except OSError as exc:
        return fail(
            f"dns:{hostname}",
            f"{hostname} does not resolve locally",
            fix=f'Add an entry like "127.0.0.1 {hostname}" to /etc/hosts if that is your intended setup.',
            details=str(exc),
        )

    if expected_ip and resolved != expected_ip:
        return warn(
            f"dns:{hostname}",
            f"{hostname} resolves, but not to {expected_ip}",
            fix=f"Check /etc/hosts or local DNS if {hostname} should resolve to {expected_ip}.",
            details=f"resolved_ip={resolved}",
        )

    return ok(
        f"dns:{hostname}", f"{hostname} resolves", details=f"resolved_ip={resolved}"
    )


def kubectl_json(args: list[str]) -> tuple[dict, str] | tuple[None, str]:
    result = run(["kubectl", *args, "-o", "json"])
    if result.returncode != 0:
        return None, result.stderr.strip()
    try:
        return json.loads(result.stdout), ""
    except json.JSONDecodeError as exc:
        return None, f"Failed to parse kubectl JSON: {exc}"


def check_kube_context() -> CheckResult:
    result = run(["kubectl", "config", "current-context"])
    if result.returncode != 0:
        return fail(
            "k8s:context",
            "Unable to read current kubectl context",
            fix="Check KUBECONFIG and kubectl configuration.",
            details=result.stderr.strip(),
        )
    ctx = result.stdout.strip()
    if not ctx:
        return fail("k8s:context", "kubectl current-context is empty")
    return ok("k8s:context", "kubectl context is set", details=ctx)


def check_cluster_info() -> CheckResult:
    result = run(["kubectl", "cluster-info"])
    if result.returncode != 0:
        return fail(
            "k8s:cluster-info",
            "Cluster is not reachable via kubectl",
            fix="Ensure the cluster is running and your context points to it.",
            details=result.stderr.strip(),
        )
    return ok("k8s:cluster-info", "Cluster is reachable")


def check_nodes_ready() -> CheckResult:
    obj, err = kubectl_json(["get", "nodes"])
    if obj is None:
        return fail(
            "k8s:nodes",
            "Could not query nodes",
            fix="Check cluster connectivity and RBAC.",
            details=err,
        )

    not_ready: list[str] = []
    items = obj.get("items", [])
    for item in items:
        name = item["metadata"]["name"]
        conditions = item.get("status", {}).get("conditions", [])
        ready = next((c for c in conditions if c.get("type") == "Ready"), None)
        if not ready or ready.get("status") != "True":
            not_ready.append(name)

    if not items:
        return warn("k8s:nodes", "No nodes found")

    if not_ready:
        return fail(
            "k8s:nodes",
            "Some nodes are not Ready",
            fix="Run: kubectl get nodes -o wide; kubectl describe nodes",
            details=", ".join(not_ready),
        )

    return ok("k8s:nodes", "All nodes are Ready", details=f"count={len(items)}")


def check_namespace_exists(namespace: str) -> CheckResult:
    result = run(["kubectl", "get", "ns", namespace])
    if result.returncode != 0:
        return fail(
            f"k8s:ns:{namespace}",
            f"Namespace {namespace} does not exist",
            fix=f"Create it or verify the configured namespace: {namespace}",
            details=result.stderr.strip(),
        )
    return ok(f"k8s:ns:{namespace}", f"Namespace {namespace} exists")


def check_deployment_available(namespace: str, name: str) -> CheckResult:
    obj, err = kubectl_json(["get", "deployment", "-n", namespace, name])
    if obj is None:
        return fail(
            f"k8s:deploy:{namespace}/{name}",
            f"Deployment {namespace}/{name} not found or unreadable",
            fix=f"Run: kubectl get deploy -n {namespace}",
            details=err,
        )

    desired = obj.get("spec", {}).get("replicas", 0)
    available = obj.get("status", {}).get("availableReplicas", 0)
    ready = obj.get("status", {}).get("readyReplicas", 0)

    if available < 1 or ready < desired:
        return fail(
            f"k8s:deploy:{namespace}/{name}",
            f"Deployment {namespace}/{name} is not fully available",
            fix=f"Run: kubectl rollout status deploy/{name} -n {namespace}; kubectl describe deploy/{name} -n {namespace}",
            details=f"desired={desired} ready={ready} available={available}",
        )

    return ok(
        f"k8s:deploy:{namespace}/{name}",
        f"Deployment {namespace}/{name} is available",
        details=f"desired={desired} ready={ready} available={available}",
    )


def check_endpoints(namespace: str, name: str) -> CheckResult:
    obj, err = kubectl_json(["get", "endpoints", "-n", namespace, name])
    if obj is None:
        return fail(
            f"k8s:endpoints:{namespace}/{name}",
            f"Endpoints {namespace}/{name} not found",
            fix=f"Run: kubectl get endpoints -n {namespace}",
            details=err,
        )

    subsets = obj.get("subsets", []) or []
    addresses: list[str] = []
    for subset in subsets:
        for addr in subset.get("addresses", []) or []:
            ip = addr.get("ip")
            if ip:
                addresses.append(ip)

    if not addresses:
        return fail(
            f"k8s:endpoints:{namespace}/{name}",
            f"Endpoints {namespace}/{name} have no ready addresses",
            fix=f"Check backing pods/services: kubectl describe endpoints {name} -n {namespace}",
        )

    return ok(
        f"k8s:endpoints:{namespace}/{name}",
        f"Endpoints {namespace}/{name} are ready",
        details=", ".join(addresses),
    )


def check_ingress_exists(name: str, namespace: str) -> CheckResult:
    result = run(["kubectl", "get", "ingress", "-n", namespace, name])
    if result.returncode != 0:
        return fail(
            f"k8s:ingress:{namespace}/{name}",
            f"Ingress {namespace}/{name} not found",
            fix=f"Run: kubectl get ingress -n {namespace}",
            details=result.stderr.strip(),
        )
    return ok(f"k8s:ingress:{namespace}/{name}", f"Ingress {namespace}/{name} exists")


def check_secret_exists(name: str, namespace: str) -> CheckResult:
    result = run(["kubectl", "get", "secret", "-n", namespace, name])
    if result.returncode != 0:
        return fail(
            f"k8s:secret:{namespace}/{name}",
            f"Secret {namespace}/{name} not found",
            fix=f"Render/apply the secret, then run: kubectl get secret {name} -n {namespace}",
            details=result.stderr.strip(),
        )
    return ok(f"k8s:secret:{namespace}/{name}", f"Secret {namespace}/{name} exists")


def check_crashloop_pods(namespace: str) -> CheckResult:
    obj, err = kubectl_json(["get", "pods", "-n", namespace])
    if obj is None:
        return fail(
            f"k8s:pods:{namespace}",
            f"Could not query pods in {namespace}",
            details=err,
        )

    crashlooping: list[str] = []
    items = obj.get("items", [])
    for item in items:
        pod_name = item["metadata"]["name"]
        statuses = item.get("status", {}).get("containerStatuses", []) or []
        for status in statuses:
            waiting = status.get("state", {}).get("waiting")
            if waiting and waiting.get("reason") == "CrashLoopBackOff":
                crashlooping.append(pod_name)
                break

    if crashlooping:
        return fail(
            f"k8s:crashloop:{namespace}",
            "CrashLoopBackOff pods detected",
            fix=f"Run: kubectl get pods -n {namespace}; kubectl logs -n {namespace} <pod> --all-containers",
            details=", ".join(crashlooping),
        )

    return ok(f"k8s:crashloop:{namespace}", "No CrashLoopBackOff pods detected")


def check_url_reachable(url: str) -> CheckResult:
    try:
        import urllib.request

        with urllib.request.urlopen(url, timeout=5) as resp:
            status = getattr(resp, "status", None)
            if status is None or 200 <= status < 400:
                return ok(
                    "http:keycloak", "Keycloak front URL is reachable", details=url
                )
            return fail(
                "http:keycloak",
                f"Unexpected HTTP status from {url}: {status}",
                fix=f"Run: curl -v {url}",
            )
    except Exception as exc:
        return fail(
            "http:keycloak",
            f"Keycloak front URL is not reachable: {url}",
            fix=f"Check ingress, local hostname resolution, and service readiness. Try: curl -v {url}",
            details=str(exc),
        )


def print_human(results: list[CheckResult]) -> None:
    icon = {"ok": "[OK] ✅", "warn": "[WARN]", "fail": "[FAIL] ❌"}
    for r in results:
        print(f"{icon[r.status]} {r.name}: {r.message}")
        if r.details:
            print(f"       details: {r.details}")
        if r.fix and r.status != "ok":
            print(f"       fix: {r.fix}")

    total = len(results)
    failed = sum(1 for r in results if r.status == "fail")
    warned = sum(1 for r in results if r.status == "warn")
    passed = sum(1 for r in results if r.status == "ok")

    print()
    print(f"Summary: {passed} ok, {warned} warn, {failed} fail, {total} total")


def main() -> int:
    namespace = os.environ.get("NAMESPACE", "default")
    keycloak_front_url = os.environ.get(
        "KEYCLOAK_FRONT_URL", "http://keycloak:8080/keycloak"
    )
    output_json = "--json" in sys.argv
    print(os.environ.get("KEYCLOAK_FRONT_URL"))
    results: list[CheckResult] = []

    # Local toolchain
    results.append(check_command_exists("docker", ["docker", "--version"]))
    results.append(check_command_exists("kubectl", ["kubectl", "version", "--client"]))
    results.append(check_command_exists("terraform", ["terraform", "version"]))
    results.append(check_command_exists("python3", ["python3", "--version"]))
    results.append(check_command_exists("java", ["java", "--version"]))
    results.append(check_version_is_higher("java", ["java", "--version"], 21))
    # Directories / env
    results.append(check_directory("SHOPIZER_DIR"))
    results.append(check_directory("KEYCLOAK_DIR"))
    results.append(check_env_var("OPENAI_API_KEY", secret=True))
    results.append(check_host_resolution("keycloak", expected_ip="127.0.0.1"))

    # Cluster
    results.append(check_kube_context())
    results.append(check_cluster_info())
    results.append(check_nodes_ready())
    results.append(check_namespace_exists(namespace))
    results.append(check_namespace_exists("ingress-nginx"))
    results.append(
        check_deployment_available("ingress-nginx", "ingress-nginx-controller")
    )
    results.append(
        check_endpoints("ingress-nginx", "ingress-nginx-controller-admission")
    )

    # App
    results.append(check_ingress_exists("terraform-ingress", namespace))
    results.append(check_secret_exists("app-secret", namespace))
    results.append(check_deployment_available(namespace, "users"))
    results.append(check_crashloop_pods(namespace))
    results.append(check_url_reachable(keycloak_front_url))

    if output_json:
        print(json.dumps([asdict(r) for r in results], indent=2))
    else:
        print_human(results)

    has_fail = any(r.status == "fail" for r in results)
    return 1 if has_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
