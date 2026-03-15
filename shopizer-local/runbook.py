import os
import re
import sys
import json
import yaml
import time
import shlex
import subprocess
from pathlib import Path

# --- Optional: talk to Ollama for failure summaries ---
import requests

os.environ["TF_INPUT"] = "false"
#OLLAMA is not required, not tested, future plan
OLLAMA_URL = "http://localhost:11434/api/chat"
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llama3.1")

# Allowlist binaries (tighten as you like)
ALLOWED_CMDS = {
    "docker", "kubectl", "terraform", "kind", "curl", "mkdir", "sh", "rm"
}

# Simple hard blocks
BLOCKED_TOKENS = {"sudo"}
BLOCKED_SUBSTRINGS = ["mkfs", ":(){", "dd if="]

VAR_PATTERN = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")

def expand_vars(obj, vars_map):
    if isinstance(obj, str):
        def repl(m):
            key = m.group(1)
            return str(vars_map.get(key, m.group(0)))
        return VAR_PATTERN.sub(repl, obj)
    if isinstance(obj, list):
        return [expand_vars(x, vars_map) for x in obj]
    if isinstance(obj, dict):
        return {k: expand_vars(v, vars_map) for k, v in obj.items()}
    return obj

def _is_safe_rm(cmd_list, cwd):
    if cwd is None:
        return False
    # Only allow rm of .terraform and *tfstate* under cwd (no globs)
    allowed_flags = {"-f", "-r", "-rf", "-fr"}
    args = cmd_list[1:]
    for a in args:
        if a.startswith("-"):
            if a not in allowed_flags:
                return False
            continue
        if any(ch in a for ch in ["*", "?", "["]):
            return False
        p = Path(a)
        if not p.is_absolute():
            p = (Path(cwd) / p).resolve()
        try:
            p.relative_to(Path(cwd).resolve())
        except Exception:
            return False
        name = p.name
        if name == ".terraform" or ".terraform" in p.parts:
            continue
        if ".tfstate" in name:
            continue
        return False
    return True


def ensure_safe_cmd(cmd_list, cwd=None):
    if not cmd_list:
        raise ValueError("Empty command")

    exe = cmd_list[0]
    if exe not in ALLOWED_CMDS:
        raise ValueError(f"Command not allowed: {exe}")

    joined = " ".join(cmd_list)
    if exe == "rm":
        if not _is_safe_rm(cmd_list, cwd):
            raise ValueError("Blocked rm: only .terraform and *tfstate* under cwd are allowed")
    for t in BLOCKED_TOKENS:
        if t == exe:
            raise ValueError(f"Blocked executable: {exe}")
    for s in BLOCKED_SUBSTRINGS:
        if s in joined:
            raise ValueError(f"Blocked pattern detected: {s}")

def run_cmd(cmd_list, cwd=None):
    ensure_safe_cmd(cmd_list, cwd=cwd)

    use_shell = False
    if cmd_list[0] == "sh":
        if len(cmd_list) != 3 or cmd_list[1] != "-lc":
            raise ValueError("Only 'sh -lc <cmd>' is permitted")
        use_shell = True
        cmd = cmd_list[2]
    else:
        cmd = cmd_list

    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        shell=use_shell,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=1
    )

    output = []
    for line in proc.stdout:
        print(line, end="", flush=True)   # live output
        output.append(line)

    proc.wait()
    return proc.returncode, "".join(output), ""

def ask_ollama_failure(step_name, cmd, code, out, err):
    # Keep it short & safe: do NOT send secrets (best effort)
    payload = {
        "model": OLLAMA_MODEL,
        "messages": [
            {"role": "system", "content": "You are a DevOps assistant. Provide concise diagnosis and next command suggestions."},
            {"role": "user", "content": f"""Step failed: {step_name}
Command: {cmd}
Exit code: {code}

STDOUT:
{out[-2000:]}

STDERR:
{err[-2000:]}

Respond with:
1) likely cause (1-3 bullets)
2) next 3 diagnostic commands (kubectl/terraform only)
"""}
        ],
        "stream": False
    }
    try:
        r = requests.post(OLLAMA_URL, json=payload, timeout=60)
        r.raise_for_status()
        return r.json()["message"]["content"]
    except Exception as e:
        return f"(Ollama unavailable: {e})"

def main():
    if len(sys.argv) < 2:
        print("Usage: python runbook_agent.py /path/to/runbook.yaml")
        sys.exit(2)

    runbook_path = Path(sys.argv[1]).expanduser().resolve()
    if not runbook_path.exists():
        print(f"Runbook not found: {runbook_path}")
        sys.exit(2)

    with open(runbook_path, "r") as f:
        data = yaml.safe_load(f)

    vars_map = data.get("vars", {})
    steps = data.get("steps", [])

    # Expand variables globally
    data = expand_vars(data, vars_map)
    vars_map = data.get("vars", {})

    out_dir = vars_map.get("out_dir", ".out")

    # If out_dir is relative, anchor it next to the runbook YAML
    if not os.path.isabs(out_dir):
        log_dir = (runbook_path.parent / out_dir).expanduser()
    else:
        log_dir = Path(out_dir).expanduser()

    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"run-{int(time.time())}.log"

    def log(s):
        print(s)
        with open(log_file, "a") as lf:
            lf.write(s + "\n")

    log(f"Runbook: {data.get('name','(unnamed)')}")
    log(f"Log: {log_file}")

    for i, step in enumerate(steps, start=1):
        step = expand_vars(step, vars_map)
        name = step.get("name", f"step-{i}")
        cwd = step.get("cwd")
        if cwd:
            cwd = str(Path(cwd).expanduser())

        log(f"\n== [{i}/{len(steps)}] {name} ==")

        if "run" in step:
            for cmd_list in step["run"]:
                cmd_list = expand_vars(cmd_list, vars_map)
                log(f"$ {cmd_list} (cwd={cwd or os.getcwd()})")
                code, out, err = run_cmd(cmd_list, cwd=cwd)
                if out.strip():
                    log(out.rstrip())
                if err.strip():
                    log(err.rstrip())

                if code != 0:
                    log(f"!! FAILED: exit={code}")
                    # Optional: ask Ollama for diagnosis
                    advice = ask_ollama_failure(name, cmd_list, code, out, err)
                    log("\n--- Ollama diagnosis ---\n" + advice + "\n------------------------")
                    sys.exit(code)
        else:
            log("No supported action in this step (expected 'run').")

    log("\n✅ Runbook completed successfully")

if __name__ == "__main__":
    main()
