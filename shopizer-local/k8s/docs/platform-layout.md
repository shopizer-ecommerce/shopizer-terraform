# Platform Layout

This document describes the local platform structure under `shopizer-local/k8s`.

## Top-Level Layout

```text
k8s/
├── apps/
│   └── shared/
├── argocd/
│   └── applicationsets/
├── charts/
│   └── generic-java-service/
├── docs/
├── legacy/
│   └── apps/
└── platform/
    ├── charts/
    ├── docs/
    ├── manifests/
    └── values/
```

## Apps

`k8s/apps/shared` contains active shared app manifests:

```text
app-secret.yaml
otel-config-map.yaml
```

Terraform applies this folder directly:

```bash
kubectl apply -f ./k8s/apps/shared
```

## Charts

`k8s/charts/generic-java-service` is the reusable application chart consumed by
service-owned Kustomize entrypoints.

This chart is not a platform chart. It stays outside `platform/` because it is
part of the application deployment model.

## Platform

`k8s/platform` owns local cluster/platform dependencies.

### Platform Charts

Vendored third-party charts live in:

```text
k8s/platform/charts/
```

Current chart folders:

```text
alloy
argo-cd
cilium
jaeger
kube-prometheus-stack
loki
opentelemetry-collector
```

### Platform Manifests

Plain Kubernetes manifests live in:

```text
k8s/platform/manifests/
```

Current local infrastructure:

```text
ingress
keycloak
pgadmin
postgres
redis
```

Terraform applies Postgres, PgAdmin, Keycloak, and Redis directly from these
folders. Ingress is handled separately by the runbook/ingress step.

### Platform Values

Platform Helm values are environment-scoped:

```text
k8s/platform/values/
├── README.md
└── local/
```

Current values are local Kind values:

```text
local/alloy-values.yaml
local/argocd-values.yaml
local/jaeger-values.yaml
local/kube-prometheus-stack-values.yaml
local/loki-values.yaml
local/otel-collector-values.yaml
local/values-cilium.yaml
```

Add future environments as sibling folders:

```text
values/dev/
values/prod/
```

Only add `values/common/` when there is real overlap across environments.

## Legacy

Old raw app Deployment and Service manifests live in:

```text
k8s/legacy/apps/
```

These are reference files only. Do not use them as the active service deployment
source. New service changes should go through:

```text
microservices/<service>/values/
k8s/charts/generic-java-service/
microservices/<service>/kustomization.yaml
```

