# Local Kubernetes Deployment Process

This document describes the current Shopizer local Kubernetes structure after the
move from raw app manifests toward a shared Helm chart with service-owned values
and Kustomize entrypoints.

For the complete documentation index, start with [README](README.md).

## Goals

- Keep reusable application templates in one shared chart.
- Keep service-specific configuration inside each service repository folder.
- Keep platform components separate from application deployment concerns.
- Keep old raw manifests available as reference, but out of the active deploy path.
- Make environment-specific values explicit instead of mixing local settings with
  generic configuration.

## Repository Responsibilities

The local Kubernetes assets are split across two sibling folders:

```text
microservices/
shopizer-terraform/shopizer-local/k8s/
```

`microservices/` owns service-specific deployment input:

```text
microservices/<service>/
├── Dockerfile
├── kustomization.yaml
├── kustomize/
│   └── overlays/local/
│       └── patch-deployment-local.yaml
└── values/
    ├── common.yaml
    └── local.yaml
```

`shopizer-local/k8s/` owns shared local cluster assets:

```text
k8s/
├── apps/
│   └── shared/
├── charts/
│   └── generic-java-service/
├── legacy/
│   └── apps/
└── platform/
```

## Application Service Flow

Each Java service uses the same deployment flow:

```text
Dockerfile -> image -> service values -> generic Helm chart -> Kustomize -> Kubernetes
```

The services currently following this pattern are:

```text
shop
users
orders
merchants
references
```

The shared chart lives at:

```text
shopizer-local/k8s/charts/generic-java-service
```

Each service has a root `kustomization.yaml` because Kustomize restricts access to
values files outside the kustomization root. Keeping the entrypoint at the service
root allows it to read:

```text
values/common.yaml
values/local.yaml
```

The service kustomization points back to the shared chart:

```yaml
helmGlobals:
  chartHome: ../../shopizer-terraform/shopizer-local/k8s/charts

helmCharts:
- name: generic-java-service
  releaseName: shop
  valuesFile: values/common.yaml
  additionalValuesFiles:
  - values/local.yaml
```

Render a service locally with:

```bash
kustomize build --enable-helm /Users/ioannislafiotis/Desktop/playground/microservices/shop
```

Apply a service manually with:

```bash
kustomize build --enable-helm /Users/ioannislafiotis/Desktop/playground/microservices/shop | kubectl apply -f -
```

## Service Values

Service values are service-owned:

```text
microservices/<service>/values/common.yaml
microservices/<service>/values/local.yaml
```

Use `common.yaml` for values that are part of the service contract, such as:

- service name
- service port
- resource requests and limits
- environment variables that are stable across environments
- service monitor configuration

Use `local.yaml` for local Kind-specific values, such as:

- local registry image repository
- local image tag
- local debug port settings
- local-only environment overrides

Add future environments as sibling files:

```text
values/dev.yaml
values/prod.yaml
```

## Docker And OpenTelemetry

Each Java service has a Dockerfile that builds an application image and includes
the OpenTelemetry Java agent in the image.

The image contains:

```text
/opt/otel/opentelemetry-javaagent.jar
/app/app.jar
```

The Helm values enable the Java agent through `JAVA_TOOL_OPTIONS`:

```text
-javaagent:/opt/otel/opentelemetry-javaagent.jar
```

OpenTelemetry runtime configuration is provided by a shared ConfigMap:

```text
k8s/apps/shared/otel-config-map.yaml
```

The shared chart wires this ConfigMap into services when OTEL is enabled in
values.

## Shared App Manifests

Shared application support manifests live under:

```text
k8s/apps/shared/
├── app-secret.yaml
└── otel-config-map.yaml
```

These are active local manifests. Terraform applies this folder directly:

```bash
kubectl apply -f ./k8s/apps/shared
```

`app-secret.yaml` contains local app secrets and shared database/Keycloak/Redis
connection values. `otel-config-map.yaml` contains common OTEL exporter settings.

## Platform Structure

Platform resources are isolated under:

```text
k8s/platform/
├── charts/
├── docs/
├── manifests/
└── values/
```

`platform/charts/` contains vendored third-party Helm charts, such as:

```text
alloy
argo-cd
cilium
jaeger
kube-prometheus-stack
loki
opentelemetry-collector
```

Argo CD is installed by Terraform from:

```text
k8s/platform/charts/argo-cd
k8s/platform/values/local/argocd-values.yaml
```

Detailed Argo CD bootstrap documentation lives in:

```text
k8s/docs/argocd-terraform-install.md
```

`platform/manifests/` contains plain local infrastructure manifests:

```text
ingress
keycloak
pgadmin
postgres
redis
```

Terraform applies these directly from their platform paths, for example:

```bash
kubectl apply -f ./k8s/platform/manifests/postgres
kubectl apply -f ./k8s/platform/manifests/keycloak
kubectl apply -f ./k8s/platform/manifests/redis
```

## Platform Values By Environment

Platform Helm values are environment-scoped:

```text
k8s/platform/values/
├── README.md
└── local/
    ├── alloy-values.yaml
    ├── argocd-values.yaml
    ├── jaeger-values.yaml
    ├── kube-prometheus-stack-values.yaml
    ├── loki-values.yaml
    ├── otel-collector-values.yaml
    └── values-cilium.yaml
```

The current values are local Kind values, so they live under `local/`.

Add future environments as siblings:

```text
k8s/platform/values/dev/
k8s/platform/values/prod/
```

Only introduce `common/` when there is real shared platform configuration across
multiple environments.

## Legacy App Manifests

The old raw service Deployment and Service manifests were moved to:

```text
k8s/legacy/apps/
```

They are kept as reference only. They should not be applied as part of the active
deployment path. New app deployment changes should go through:

```text
microservices/<service>/values/*.yaml
shopizer-local/k8s/charts/generic-java-service
microservices/<service>/kustomization.yaml
```

## Terraform Behavior

Terraform no longer applies the entire `k8s/` directory. This is important because
`k8s/` now contains Helm charts, docs, platform assets, and legacy manifests.

The active Terraform flow applies specific folders:

```text
k8s/apps/shared
k8s/platform/manifests/postgres
k8s/platform/manifests/pgadmin
k8s/platform/manifests/keycloak
k8s/platform/manifests/redis
```

Terraform also installs Argo CD with Helm when `enable_argocd` is true:

```bash
helm upgrade --install argocd ./k8s/platform/charts/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values ./k8s/platform/values/local/argocd-values.yaml \
  --wait \
  --timeout 10m
```

The local Terraform variables are:

```text
enable_argocd
argocd_namespace
argocd_release_name
```

Ingress is still handled separately by the local runbook and platform manifest:

```text
k8s/platform/manifests/ingress/ingress.yaml
```

## Validation Commands

Validate the reusable app chart:

```bash
helm lint /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/k8s/charts/generic-java-service
```

Validate the Argo CD platform chart:

```bash
helm lint /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/k8s/platform/charts/argo-cd \
  -f /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/k8s/platform/values/local/argocd-values.yaml
```

Render one service through Kustomize and Helm:

```bash
kustomize build --enable-helm /Users/ioannislafiotis/Desktop/playground/microservices/shop
```

Validate Terraform formatting:

```bash
terraform fmt -check /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/main.tf
```

Check for stale references after moving files:

```bash
rg "k8s/(app-secret|otel-config-map|ingress|postgres|pgadmin|keycloak|redis)" \
  /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local
```

## Next Step: Argo CD

The intended next step is to let Argo CD own application deployment.

The likely Argo CD shape is an ApplicationSet that points each service at its
service-owned Kustomize entrypoint:

```text
microservices/shop
microservices/users
microservices/orders
microservices/merchants
microservices/references
```

Platform components can be handled separately as platform Applications or
ApplicationSets, using:

```text
k8s/platform/charts/<chart>
k8s/platform/values/<env>/<values-file>.yaml
```
