# Terraform Bootstrap

This document describes what Terraform owns in the local Shopizer environment.

## Files

```text
shopizer-local/main.tf
shopizer-local/variables.tf
shopizer-local/.terraform.lock.hcl
shopizer-local/kind-config.tftpl
shopizer-local/build.sh
```

## Responsibilities

Terraform currently handles:

- local Docker registry container
- local service image build/push flow
- Kind cluster creation
- loading local images into Kind
- shared app manifest application
- Postgres, PgAdmin, Keycloak, and Redis manifests
- ingress-nginx bootstrap
- Argo CD Helm install
- cleanup on destroy

Terraform does not yet own service Applications/ApplicationSets. That is the next
GitOps step.

Bootstrap readiness checks are documented in
[Bootstrap Contracts](bootstrap-contracts.md).

## Main Flow

The local flow is:

```text
ensure Postgres data path
generate Kind config
start local registry
build and push service images
install required local tools
create Kind cluster
connect registry to Kind network
load images into Kind
apply shared app manifests
apply platform manifests
install ingress-nginx
install Argo CD
```

## Active Kubernetes Apply Targets

Terraform applies only specific paths. It does not apply the whole `k8s/`
directory.

```text
k8s/apps/shared
k8s/platform/manifests/postgres
k8s/platform/manifests/pgadmin
k8s/platform/manifests/keycloak
k8s/platform/manifests/redis
```

This prevents Terraform from accidentally applying docs, charts, platform values,
or legacy app manifests.

## Argo CD

Argo CD is installed by Terraform using Helm:

```text
k8s/platform/charts/argo-cd
k8s/platform/values/local/argocd-values.yaml
```

See [Argo CD Terraform Install](argocd-terraform-install.md) for details.

## Variables

Important variables:

```text
microservices
app_path
postgres_data_host_path
enable_argocd
argocd_namespace
argocd_release_name
```

Disable Argo CD:

```bash
terraform apply -var='enable_argocd=false'
```

## Commands

Initialize providers:

```bash
terraform -chdir=/Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local init
```

Validate:

```bash
terraform -chdir=/Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local validate
```

Apply:

```bash
terraform -chdir=/Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local apply
```

Destroy:

```bash
terraform -chdir=/Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local destroy
```

## Provider Lock File

`.terraform.lock.hcl` should be committed when provider selections intentionally
change. It changed when providers were refreshed to validate the current
configuration.
