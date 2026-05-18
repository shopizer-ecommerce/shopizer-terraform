# Service Deployment Model

This document describes how Shopizer Java services are built and rendered for
local Kubernetes.

## Services

The current Java services are:

```text
shop
users
orders
merchants
references
```

The `common` module is a shared library and is not deployed as a service.

## Per-Service Files

Each deployable service owns these files:

```text
microservices/<service>/
├── Dockerfile
├── .dockerignore
├── kustomization.yaml
├── kustomize/
│   └── overlays/local/
│       └── patch-deployment-local.yaml
└── values/
    ├── common.yaml
    └── local.yaml
```

The service folder is the deployment entrypoint. This is intentional: Kustomize
does not allow a kustomization to read values files from arbitrary parent paths.
Keeping `kustomization.yaml` at the service root lets it consume `values/`
without security errors.

## Shared Chart

All Java services use the same reusable Helm chart:

```text
shopizer-local/k8s/charts/generic-java-service
```

The chart templates:

```text
deployment.yaml
service.yaml
ingress.yaml
hpa.yaml
configmap.yaml
servicemonitor.yaml
```

The chart is intentionally generic. Service identity, image, ports, environment,
resources, and OTEL settings come from each service's values files.

## Values

Use `values/common.yaml` for service-level defaults that should be stable across
environments:

- service name
- ports
- resources
- stable environment variables
- service monitor settings
- OTEL enablement

Use `values/local.yaml` for local Kind-specific overrides:

- `localhost:5001/...` image repository
- local image tag
- local debug settings
- local-only environment overrides

Future environments should be added as sibling files:

```text
values/dev.yaml
values/prod.yaml
```

## Kustomize

Each service renders Helm through Kustomize:

```yaml
helmGlobals:
  chartHome: ../../shopizer-terraform/shopizer-local/k8s/charts

helmCharts:
- name: generic-java-service
  releaseName: <service>
  valuesFile: values/common.yaml
  additionalValuesFiles:
  - values/local.yaml

patches:
- path: kustomize/overlays/local/patch-deployment-local.yaml
```

The local patch currently marks pod templates with:

```text
app.kubernetes.io/environment: local
```

## Docker And OTEL

Each service image includes:

```text
/app/app.jar
/opt/otel/opentelemetry-javaagent.jar
```

The chart enables the agent through `JAVA_TOOL_OPTIONS`:

```text
-javaagent:/opt/otel/opentelemetry-javaagent.jar
```

Runtime OTEL settings come from:

```text
shopizer-local/k8s/apps/shared/otel-config-map.yaml
```

## Build

`shopizer-local/build.sh` builds services and pushes local images to the local
registry. If a service has a Dockerfile, the script uses Docker directly. If not,
it falls back to the Maven build-image path.

Expected local image shape:

```text
localhost:5001/shopizer-<service>:<tag>
```

## Render And Apply

Render a service:

```bash
kustomize build --enable-helm /Users/ioannislafiotis/Desktop/playground/microservices/shop
```

Apply a service manually:

```bash
kustomize build --enable-helm /Users/ioannislafiotis/Desktop/playground/microservices/shop | kubectl apply -f -
```

## Argo CD ApplicationSet

Argo CD deploys the Java services with:

```text
shopizer-local/k8s/argocd/applicationsets/java-services.yaml
```

The ApplicationSet renders the shared Helm chart from the terraform repository
and pulls service values from the microservices repository:

```text
shopizer-local/k8s/charts/generic-java-service
microservices/<service>/values/common.yaml
microservices/<service>/values/local.yaml
```

The service-owned Kustomize entrypoints are still useful for local rendering and
manual apply. They are not used by Argo CD in this shape because the Kustomize
entrypoints reference a chart in a sibling repository path, and Argo CD renders a
single source checkout in isolation. The ApplicationSet uses Argo CD multi-source
Helm instead, which supports chart and values from different repositories.

The service ApplicationSet currently reads:

```text
shopizer-terraform branch: platform4.0
microservices branch: platform
```

Both branches must be pushed for Argo CD to sync the service applications.

Validate all Java services:

```bash
for service in shop users orders merchants references; do
  kustomize build --enable-helm "/Users/ioannislafiotis/Desktop/playground/microservices/$service" >/tmp/$service.yaml
done
```
