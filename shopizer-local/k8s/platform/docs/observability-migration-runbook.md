# Local Observability Runbook

This runbook documents the local Kind observability setup for Shopizer, including the Jaeger/OpenTelemetry trace fix and the migration from the deprecated `loki-stack`/Promtail setup to Loki 3.x plus Grafana Alloy.

## Current Target Architecture

```text
Shopizer services -> OpenTelemetry Collector -> Jaeger
Alloy             -> Loki
Prometheus stack  -> metrics
Grafana           -> dashboards and Explore
```

Recommended ownership:

- OpenTelemetry Collector handles traces from apps and forwards them to Jaeger.
- Alloy collects Kubernetes container logs and forwards them to Loki.
- Prometheus stack handles metrics.
- Jaeger stores and queries traces.
- Loki stores and queries logs.

## Local Chart Versions

Charts live under:

```text
k8s/platform/charts/
```

Current downloaded versions:

```text
jaeger                  chart 4.7.0    app 2.17.0
kube-prometheus-stack   chart 82.14.1  app v0.89.0
opentelemetry-collector chart 0.153.0  app 0.151.0
loki                    chart 7.0.0    app 3.6.7
alloy                   chart 1.8.0    app v1.16.0
```

The old chart is deprecated and should not be used:

```text
k8s/platform/charts/loki-stack   chart 2.10.3   app v2.9.3
```

## Values Files

Values live under:

```text
k8s/platform/values/local/
```

Important files:

```text
k8s/platform/values/local/otel-collector-values.yaml
k8s/platform/values/local/loki-values.yaml
k8s/platform/values/local/alloy-values.yaml
k8s/platform/values/local/jaeger-values.yaml
k8s/platform/values/local/kube-prometheus-stack-values.yaml
```

Avoid using raw `helm get values --all` output directly if it contains this first line:

```yaml
COMPUTED VALUES:
```

That line is not accepted by Helm chart schemas and causes errors such as:

```text
additional properties 'COMPUTED VALUES' not allowed
```

If you export values from a live release, use:

```bash
helm get values <release> -n monitoring --all -o yaml > k8s/platform/values/local/<release>-values.yaml
```

## OpenTelemetry Collector

The collector should send traces to Jaeger.

Trace exporter:

```yaml
config:
  exporters:
    otlp/jaeger:
      endpoint: jaeger.monitoring.svc.cluster.local:4317
      tls:
        insecure: true
```

Trace pipeline:

```yaml
config:
  service:
    pipelines:
      traces:
        receivers:
          - otlp
          - jaeger
          - zipkin
        processors:
          - memory_limiter
          - batch
        exporters:
          - debug
          - otlp/jaeger
```

### Should `otlphttp/loki` stay in the collector?

Usually no, if Alloy is collecting Kubernetes logs.

Use this split:

```text
apps -> otel-collector -> jaeger
alloy -> loki
prometheus -> metrics
```

Keep `otlphttp/loki` only if applications emit OTLP logs directly to the collector and you intentionally want this path:

```text
app OTLP logs -> otel-collector -> loki
```

Risks of keeping both Alloy and `otlphttp/loki`:

- duplicate logs if apps both print to stdout and emit OTLP logs
- more moving parts while debugging
- Loki OTLP ingestion requires Loki 3.x and structured metadata configuration

Do not send logs or metrics to Jaeger:

```yaml
# Wrong
logs:
  exporters:
    - otlp/jaeger

metrics:
  exporters:
    - otlp/jaeger
```

Jaeger is a traces backend.

## Loki 3.x

Use the new `grafana/loki` chart, not `loki-stack`.

Install from local chart:

```bash
helm upgrade --install loki k8s/platform/charts/loki \
  -n monitoring \
  -f k8s/platform/values/local/loki-values.yaml
```

Recommended local Kind values:

```yaml
deploymentMode: SingleBinary

loki:
  auth_enabled: false

  commonConfig:
    replication_factor: 1

  storage:
    type: filesystem

  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h

  limits_config:
    allow_structured_metadata: true
    volume_enabled: true

singleBinary:
  replicas: 1
  persistence:
    enabled: true
    size: 5Gi

read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0

gateway:
  enabled: false

chunksCache:
  enabled: false
resultsCache:
  enabled: false

test:
  enabled: false

lokiCanary:
  enabled: false
```

### Bug: read-only `/var/loki`

Observed error:

```text
mkdir /var/loki: read-only file system
error initialising module: ruler-storage
```

Cause:

```yaml
singleBinary:
  persistence:
    enabled: false
```

The Loki chart mounts writable storage at `/var/loki` only when single-binary persistence is enabled. The container root filesystem is read-only.

Fix:

```yaml
singleBinary:
  persistence:
    enabled: true
    size: 5Gi
```

For local reset, reinstall Loki:

```bash
helm uninstall loki -n monitoring

helm upgrade --install loki k8s/platform/charts/loki \
  -n monitoring \
  -f k8s/platform/values/local/loki-values.yaml
```

Check PVC:

```bash
kubectl get pvc -n monitoring | grep loki
```

## Alloy

Alloy replaces Promtail for Kubernetes logs.

Install from local chart:

```bash
helm upgrade --install alloy k8s/platform/charts/alloy \
  -n monitoring \
  -f k8s/platform/values/local/alloy-values.yaml
```

Recommended local values:

```yaml
controller:
  type: daemonset

alloy:
  mounts:
    varlog: true

  configMap:
    content: |-
      logging {
        level  = "info"
        format = "logfmt"
      }

      discovery.kubernetes "pods" {
        role = "pod"
      }

      loki.source.kubernetes "pods" {
        targets    = discovery.kubernetes.pods.targets
        forward_to = [loki.process.pods.receiver]
      }

      loki.process "pods" {
        stage.static_labels {
          values = {
            cluster = "kind-local",
          }
        }

        forward_to = [loki.write.default.receiver]
      }

      loki.write "default" {
        endpoint {
          url = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
        }
      }
```

Alloy renders successfully with this shape and deploys as a DaemonSet.

## Removing Old Loki Stack

The old release was:

```text
loki chart loki-stack-2.10.3 app v2.9.3
```

Remove it:

```bash
helm uninstall loki -n monitoring
```

Then install the new Loki release from:

```text
k8s/platform/charts/loki
```

If you are certain old logs are disposable, clean old PVCs:

```bash
kubectl get pvc -n monitoring
kubectl delete pvc -n monitoring -l app=loki
```

Only delete PVCs when losing local log data is acceptable.

## Install Commands

From `shopizer-local`:

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install jaeger k8s/platform/charts/jaeger \
  -n monitoring \
  -f k8s/platform/values/local/jaeger-values.yaml

helm upgrade --install monitoring k8s/platform/charts/kube-prometheus-stack \
  -n monitoring \
  -f k8s/platform/values/local/kube-prometheus-stack-values.yaml

helm upgrade --install otel-collector k8s/platform/charts/opentelemetry-collector \
  -n monitoring \
  -f k8s/platform/values/local/otel-collector-values.yaml

helm upgrade --install loki k8s/platform/charts/loki \
  -n monitoring \
  -f k8s/platform/values/local/loki-values.yaml

helm upgrade --install alloy k8s/platform/charts/alloy \
  -n monitoring \
  -f k8s/platform/values/local/alloy-values.yaml
```

## Verification

Check Helm releases:

```bash
helm list -n monitoring
```

Expected:

```text
jaeger
monitoring
otel-collector
loki
alloy
```

Check pods:

```bash
kubectl get pods -n monitoring
```

Check rollouts:

```bash
kubectl rollout status statefulset/loki -n monitoring --timeout=120s
kubectl rollout status daemonset/alloy -n monitoring --timeout=120s
kubectl rollout status deployment/otel-collector-opentelemetry-collector -n monitoring --timeout=120s
```

Depending on chart naming, Loki may be:

```bash
kubectl get statefulset -n monitoring | grep loki
```

Check Loki readiness:

```bash
kubectl port-forward -n monitoring svc/loki 3100:3100
curl http://127.0.0.1:3100/ready
```

Expected:

```text
ready
```

Check Loki labels:

```bash
curl -s http://127.0.0.1:3100/loki/api/v1/labels
```

Query Alloy-pushed logs:

```bash
curl -G -s "http://127.0.0.1:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={cluster="kind-local"}' \
  --data-urlencode 'limit=10'
```

Check Alloy logs:

```bash
kubectl logs -n monitoring daemonset/alloy --tail=100
```

Look for errors pushing to Loki.

## Shop Trace Test

The `shop` service uses context path:

```text
/shop
```

Generate traffic:

```bash
kubectl port-forward -n default svc/shop 18080:80

for i in {1..50}; do
  curl -s -o /tmp/shop-products.out -w "%{http_code}\n" \
    "http://127.0.0.1:18080/shop/api/v2/public/stores/DEFAULT/products?count=10&page=0"
done
```

Expected HTTP code:

```text
200
```

Check Jaeger services:

```bash
curl http://127.0.0.1:16686/api/services
```

Expected includes:

```text
shop
```

## Common Edge Cases

### `404` from shop traffic

Cause: missing `/shop` context path.

Wrong:

```text
/api/v2/public/stores/DEFAULT/products
```

Correct:

```text
/shop/api/v2/public/stores/DEFAULT/products
```

### Jaeger only lists `jaeger`

Cause: collector trace pipeline exports only to `debug`.

Fix: add `otlp/jaeger` exporter and include it in the traces pipeline.

### `otlphttp/loki` used as receiver

Wrong:

```yaml
logs:
  receivers:
    - otlphttp/loki
```

Correct:

```yaml
logs:
  receivers:
    - otlp
  exporters:
    - otlphttp/loki
```

Only use this if you intentionally send OTLP logs from apps through the collector.

### Logs or metrics exported to Jaeger

Wrong:

```yaml
logs:
  exporters:
    - otlp/jaeger
metrics:
  exporters:
    - otlp/jaeger
```

Jaeger is for traces only.

### New Loki chart fails with old `loki-stack` values

Observed error:

```text
wrong type for value; expected string; got map[string]interface {}
```

Cause: using old `loki-stack` values against the new `grafana/loki` chart.

Fix: replace the values file with a clean Loki 7.x values file.

### `COMPUTED VALUES:` in values files

Cause: values were copied from command output instead of exported as YAML.

Fix: remove the first line, or regenerate with:

```bash
helm get values <release> -n monitoring --all -o yaml
```

### Alloy is installed but no logs appear

Check:

```bash
kubectl logs -n monitoring daemonset/alloy --tail=100
kubectl get svc -n monitoring | grep loki
curl http://127.0.0.1:3100/ready
```

Likely causes:

- Loki not ready
- wrong Loki service URL in `loki.write`
- Alloy cannot read `/var/log`
- labels in LogQL query do not match what Alloy writes

## Useful Commands

Render before applying:

```bash
helm template loki k8s/platform/charts/loki \
  -n monitoring \
  -f k8s/platform/values/local/loki-values.yaml

helm template alloy k8s/platform/charts/alloy \
  -n monitoring \
  -f k8s/platform/values/local/alloy-values.yaml

helm template otel-collector k8s/platform/charts/opentelemetry-collector \
  -n monitoring \
  -f k8s/platform/values/local/otel-collector-values.yaml
```

Inspect installed values:

```bash
helm get values loki -n monitoring --all -o yaml
helm get values alloy -n monitoring --all -o yaml
helm get values otel-collector -n monitoring --all -o yaml
```

Inspect live collector config:

```bash
kubectl get configmap otel-collector-opentelemetry-collector \
  -n monitoring \
  -o yaml
```

Inspect services:

```bash
kubectl get svc -n monitoring
```
