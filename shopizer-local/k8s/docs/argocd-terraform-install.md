# Argo CD Terraform Install

This document describes how Argo CD is installed in the local Shopizer Kind
cluster by Terraform.

## Purpose

Terraform is responsible for bootstrapping the local cluster and installing the
GitOps control plane. Argo CD will then become the owner of application
deployment in the next step.

The current Terraform step installs Argo CD only. It does not yet create
Application or ApplicationSet resources for the services.

## Source Files

Terraform resource:

```text
shopizer-local/main.tf
```

Terraform variables:

```text
shopizer-local/variables.tf
```

Vendored Argo CD chart:

```text
shopizer-local/k8s/platform/charts/argo-cd
```

Local Argo CD values:

```text
shopizer-local/k8s/platform/values/local/argocd-values.yaml
```

## Terraform Variables

Argo CD installation is controlled by these variables:

```hcl
variable "enable_argocd" {
  description = "Install Argo CD into the local Kind cluster"
  type        = bool
  default     = true
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD is installed"
  type        = string
  default     = "argocd"
}

variable "argocd_release_name" {
  description = "Helm release name for Argo CD"
  type        = string
  default     = "argocd"
}
```

To disable Argo CD temporarily:

```bash
terraform apply -var='enable_argocd=false'
```

## Install Flow

Terraform installs Argo CD with a `null_resource` that shells out to Helm:

```bash
helm upgrade --install argocd ./k8s/platform/charts/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values ./k8s/platform/values/local/argocd-values.yaml \
  --wait \
  --timeout 10m
```

After Helm completes, Terraform waits for the Argo CD server rollout:

```bash
kubectl rollout status deployment/argocd-server \
  --namespace argocd \
  --timeout 5m
```

## Why Helm Is Called From Terraform

The local Terraform stack already uses `null_resource` and `local-exec` for Kind
and Kubernetes bootstrap work. Keeping Argo CD installation in the same pattern
avoids introducing the Terraform Helm provider before the platform structure is
settled.

This is a pragmatic bootstrap layer. Once the cluster has Argo CD installed,
service deployments should move to Argo CD Applications/ApplicationSets instead
of being applied by Terraform.

## Re-Run Behavior

The Argo CD install resource re-runs when these trigger values change:

```text
argocd_release_name
argocd_namespace
k8s/platform/values/local/argocd-values.yaml
k8s/platform/charts/argo-cd/Chart.yaml
```

The command uses `helm upgrade --install`, so repeated Terraform applies update
the existing release instead of failing when the release already exists.

## Validate Locally

Validate Terraform formatting:

```bash
terraform fmt -check main.tf variables.tf
```

Validate Terraform configuration:

```bash
terraform validate
```

Validate the Argo CD chart and local values:

```bash
helm lint k8s/platform/charts/argo-cd \
  -f k8s/platform/values/local/argocd-values.yaml
```

Render the chart without applying it:

```bash
helm template argocd k8s/platform/charts/argo-cd \
  -n argocd \
  -f k8s/platform/values/local/argocd-values.yaml
```

## Apply

From `shopizer-local`:

```bash
terraform init
terraform apply
```

Terraform will:

1. Build and push local service images.
2. Create or reuse the Kind cluster.
3. Apply shared app manifests.
4. Apply local platform manifests such as Postgres, Redis, PgAdmin, and Keycloak.
5. Install Argo CD in the `argocd` namespace.

## Check The Installation

Check Argo CD pods:

```bash
kubectl get pods -n argocd
```

Check the Argo CD server:

```bash
kubectl rollout status deployment/argocd-server -n argocd
```

Port-forward the UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open:

```text
https://localhost:8080
```

Get the initial admin password:

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

## Next Step

The next step is to create Argo CD ApplicationSet definitions for the Java
services.

The ApplicationSet should point at each service-owned Kustomize entrypoint:

```text
microservices/shop
microservices/users
microservices/orders
microservices/merchants
microservices/references
```

Each service entrypoint renders the shared chart from:

```text
shopizer-local/k8s/charts/generic-java-service
```
