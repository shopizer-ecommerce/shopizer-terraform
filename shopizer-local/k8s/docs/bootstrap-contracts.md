# Bootstrap Contracts

This document defines the local bootstrap contracts Terraform checks before the
cluster is considered ready for higher-level deployment.

## Shared App Manifest Contract

Terraform applies:

```text
k8s/apps/shared
```

The contract is satisfied when these objects exist in the `default` namespace:

```text
secret/app-secret
configmap/otel-common-env
```

The Terraform resources are:

```text
null_resource.deploy_manifests
null_resource.verify_shared_app_manifests
```

`deploy_manifests` has file hash triggers for:

```text
k8s/apps/shared/app-secret.yaml
k8s/apps/shared/otel-config-map.yaml
```

That means Terraform will re-apply the shared manifests when either file changes.

Manual check:

```bash
kubectl get secret app-secret -n default
kubectl get configmap otel-common-env -n default
```

## Ingress Admission Contract

Terraform installs ingress-nginx from the Kind ingress manifest:

```text
https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
```

The contract is satisfied when:

```text
deployment/ingress-nginx-controller is available
job/ingress-nginx-admission-create is complete
job/ingress-nginx-admission-patch is complete
secret/ingress-nginx-admission exists
validatingwebhookconfiguration/ingress-nginx-admission exists
service/ingress-nginx-controller-admission has endpoints
```

The Terraform resources are:

```text
null_resource.deploy_ingress_nginx
null_resource.verify_ingress_admission
```

Manual checks:

```bash
kubectl rollout status deployment/ingress-nginx-controller \
  -n ingress-nginx \
  --timeout 180s

kubectl wait job/ingress-nginx-admission-create \
  -n ingress-nginx \
  --for=condition=complete \
  --timeout 180s

kubectl wait job/ingress-nginx-admission-patch \
  -n ingress-nginx \
  --for=condition=complete \
  --timeout 180s

kubectl get secret ingress-nginx-admission -n ingress-nginx
kubectl get validatingwebhookconfiguration ingress-nginx-admission
kubectl get endpoints ingress-nginx-controller-admission -n ingress-nginx
```

## Current Boundary

These contracts only cover local bootstrap prerequisites. They do not deploy
Shopizer services or monitoring components.

Shopizer services still need Argo CD Applications/ApplicationSets that can render
the service-owned Kustomize entrypoints.

Monitoring is deployed by:

```text
k8s/argocd/applicationsets/observability.yaml
```

It creates Argo CD Applications for Jaeger, kube-prometheus-stack,
OpenTelemetry Collector, Loki, and Alloy in the `monitoring` namespace.
