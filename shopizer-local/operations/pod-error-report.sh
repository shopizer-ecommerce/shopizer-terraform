#!/usr/bin/env bash
set -euo pipefail

# Collect error lines from pod logs in selected namespaces and generate a report.

if command -v rg >/dev/null 2>&1; then
  filter_logs() {
    rg -i "$1"
  }
else
  filter_logs() {
    grep -Ei "$1"
  }
fi

usage() {
  cat <<'USAGE'
Usage:
  pod-error-report.sh [options]

Options:
  -n, --namespaces   Comma-separated namespaces (default: default)
  -s, --since        Kubectl --since value, e.g. 30m, 2h (default: 1h)
  -t, --tail         Number of log lines per container (default: 500)
  -o, --output-dir   Directory for generated reports (default: ./operations/reports)
  -h, --help         Show this help

Example:
  ./operations/pod-error-report.sh -n default,ingress-nginx -s 2h -t 1000
USAGE
}

NAMESPACES="default"
SINCE="1h"
TAIL="500"
OUTPUT_DIR="./operations/reports"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespaces)
      NAMESPACES="$2"
      shift 2
      ;;
    -s|--since)
      SINCE="$2"
      shift 2
      ;;
    -t|--tail)
      TAIL="$2"
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but not found in PATH" >&2
  exit 1
fi

if ! [[ "$TAIL" =~ ^[0-9]+$ ]]; then
  echo "--tail must be an integer" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_FILE="$OUTPUT_DIR/pod-error-report-$TIMESTAMP.md"
TMP_ERRORS="$(mktemp)"

cleanup() {
  rm -f "$TMP_ERRORS"
}
trap cleanup EXIT

encode_line() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

decode_line() {
  if base64 --help >/dev/null 2>&1; then
    printf '%s' "$1" | base64 --decode 2>/dev/null || true
  else
    printf '%s' "$1" | base64 -D 2>/dev/null || true
  fi
}

sanitize_line() {
  # Remove carriage returns and ANSI escape sequences so markdown shows readable text.
  printf '%s' "$1" | sed -E $'s/\r//g; s/\x1B\\[[0-9;]*[A-Za-z]//g'
}

cat > "$REPORT_FILE" <<EOF_HEADER
# Pod Error Report

- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- Namespaces: $NAMESPACES
- Log window: since $SINCE
- Tail per container: $TAIL

## Summary

EOF_HEADER

TOTAL_MATCHES=0
TOTAL_PODS=0
TOTAL_PODS_WITH_ERRORS=0

ERROR_REGEX='error|exception|fail(ed|ure)?|panic|fatal|timeout|connection refused|outofmemory|oomkilled|crashloopbackoff|back-off'

IFS=',' read -r -a NS_ARRAY <<< "$NAMESPACES"

for namespace in "${NS_ARRAY[@]}"; do
  namespace="$(echo "$namespace" | xargs)"
  [[ -z "$namespace" ]] && continue

  if ! kubectl get ns "$namespace" >/dev/null 2>&1; then
    echo "Namespace '$namespace' not found, skipping" >&2
    continue
  fi

  echo "Scanning namespace: $namespace"

  PODS_RAW="$(kubectl get pods -n "$namespace" --no-headers -o custom-columns=':metadata.name' 2>/dev/null || true)"
  if [[ -z "$PODS_RAW" ]]; then
    continue
  fi

  while IFS= read -r pod; do
    [[ -z "$pod" ]] && continue
    TOTAL_PODS=$((TOTAL_PODS + 1))

    CONTAINERS="$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)"
    [[ -z "$CONTAINERS" ]] && continue

    POD_HAS_ERRORS=0

    for container in $CONTAINERS; do
      LOGS="$(kubectl logs "$pod" -n "$namespace" -c "$container" --since="$SINCE" --tail="$TAIL" 2>&1 || true)"

      MATCHES="$(echo "$LOGS" | filter_logs "$ERROR_REGEX" || true)"
      if [[ -n "$MATCHES" ]]; then
        POD_HAS_ERRORS=1
        while IFS= read -r line; do
          [[ -z "$line" ]] && continue
          TOTAL_MATCHES=$((TOTAL_MATCHES + 1))
          line_b64="$(encode_line "$line")"
          printf '%s\t%s\t%s\t%s\n' "$namespace" "$pod" "$container" "$line_b64" >> "$TMP_ERRORS"
        done <<< "$MATCHES"
      fi
    done

    if [[ $POD_HAS_ERRORS -eq 1 ]]; then
      TOTAL_PODS_WITH_ERRORS=$((TOTAL_PODS_WITH_ERRORS + 1))
    fi
  done <<< "$PODS_RAW"
done

cat >> "$REPORT_FILE" <<EOF_SUMMARY
- Pods scanned: $TOTAL_PODS
- Pods with matching errors: $TOTAL_PODS_WITH_ERRORS
- Total matching log lines: $TOTAL_MATCHES

## Error Details

EOF_SUMMARY

if [[ ! -s "$TMP_ERRORS" ]]; then
  echo "No matching error lines found in the selected time window." >> "$REPORT_FILE"
else
  while IFS=$'\t' read -r ns pod container line_b64; do
    line="$(decode_line "$line_b64")"
    line="$(sanitize_line "$line")"
    if [[ -z "$line" ]]; then
      line="[empty or non-printable log line after sanitization]"
    fi

    {
      printf '### %s / %s / %s\n\n' "$ns" "$pod" "$container"
      printf '%s\n\n' '- Log:'
      printf '```text\n%s\n```\n\n' "$line"
      printf '%s\n' '- Possible root cause:'
    } >> "$REPORT_FILE"

    shopt -s nocasematch
    if [[ "$line" =~ (connection[[:space:]]+refused|dial[[:space:]]+tcp|no[[:space:]]+route[[:space:]]+to[[:space:]]+host) ]]; then
      cat >> "$REPORT_FILE" <<'EOF_RC'
  Service endpoint, DNS, or network path issue.

- Suggested fixes:
  1. Verify referenced service name/port and endpoint readiness.
  2. Check `kubectl get svc,endpoints -n <namespace>`.
  3. Validate NetworkPolicies and dependency pod health.
EOF_RC
    elif [[ "$line" =~ (timeout|timed[[:space:]]+out|deadline[[:space:]]+exceeded) ]]; then
      cat >> "$REPORT_FILE" <<'EOF_RC'
  Dependency latency, unreachable service, or overloaded pod.

- Suggested fixes:
  1. Check upstream dependency health and latency.
  2. Inspect pod CPU/memory pressure and restart history.
  3. Increase timeout only after dependency checks.
EOF_RC
    elif [[ "$line" =~ (oomkilled|outofmemory|cannot[[:space:]]+allocate[[:space:]]+memory|java.lang.OutOfMemoryError) ]]; then
      cat >> "$REPORT_FILE" <<'EOF_RC'
  Container memory exhaustion.

- Suggested fixes:
  1. Increase memory limit/request for the workload.
  2. Check heap sizing or memory leak indicators.
  3. Review node pressure and eviction events.
EOF_RC
    elif [[ "$line" =~ (crashloopbackoff|back-off|panic|fatal) ]]; then
      cat >> "$REPORT_FILE" <<'EOF_RC'
  Startup/runtime crash causing repeated restarts.

- Suggested fixes:
  1. Inspect full container logs and previous logs (`kubectl logs --previous`).
  2. Verify required env vars, secrets, and mounted config.
  3. Validate image version and startup command.
EOF_RC
    elif [[ "$line" =~ (unauthorized|forbidden|permission[[:space:]]+denied|access[[:space:]]+denied) ]]; then
      cat >> "$REPORT_FILE" <<'EOF_RC'
  Authentication/authorization or secret mismatch.

- Suggested fixes:
  1. Verify credentials/secrets and token validity.
  2. Check service account RBAC bindings.
  3. Confirm expected realm/client configuration for auth providers.
EOF_RC
    else
      cat >> "$REPORT_FILE" <<'EOF_RC'
  Generic application or dependency error.

- Suggested fixes:
  1. Inspect full pod logs around this timestamp.
  2. Correlate with recent deploy/config changes.
  3. Reproduce in a lower environment with debug logging enabled.
EOF_RC
    fi
    shopt -u nocasematch

    echo >> "$REPORT_FILE"
  done < "$TMP_ERRORS"
fi

cat >> "$REPORT_FILE" <<'EOF_NEXT'
## Next Step (Pipeline/Slack)

You can post this markdown report to Slack in a follow-up automation step:
- Convert to Slack message blocks, or
- Upload the file via Slack API (`files.upload` / external upload flow).

EOF_NEXT

echo "Report generated: $REPORT_FILE"
