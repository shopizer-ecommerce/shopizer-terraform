# Shopizer Local Kubernetes Documentation

This folder documents the local Kubernetes deployment model for Shopizer.

## Read Order

1. [Local Kubernetes Deployment Process](local-k8s-deployment-process.md)
2. [Service Deployment Model](service-deployment-model.md)
3. [Platform Layout](platform-layout.md)
4. [Terraform Bootstrap](terraform-bootstrap.md)
5. [Argo CD Terraform Install](argocd-terraform-install.md)
6. [Operations Runbook](operations-runbook.md)
7. [Local Cleanup Commands](local-cleanup-commands.md)
8. [Bootstrap Contracts](bootstrap-contracts.md)

## Current Model

The local environment is split into three ownership areas:

```text
microservices/<service>/                 service-owned deployment input
shopizer-local/k8s/charts/               reusable app chart
shopizer-local/k8s/platform/             local platform components
```

Java services are rendered by Kustomize on top of a shared Helm chart:

```text
service values -> generic-java-service Helm chart -> Kustomize -> Kubernetes
```

Argo CD deploys the same services through an ApplicationSet that renders the
shared Helm chart with service-owned values from the microservices repository.
The Kustomize entrypoints remain the local/manual rendering path.

Terraform bootstraps the local Kind cluster and installs platform prerequisites,
including Argo CD. Argo CD is the intended owner of application deployment after
ApplicationSets are added.

## Important Paths

```text
shopizer-local/main.tf
shopizer-local/variables.tf
shopizer-local/k8s/apps/shared/
shopizer-local/k8s/charts/generic-java-service/
shopizer-local/k8s/platform/
shopizer-local/k8s/legacy/apps/
microservices/<service>/kustomization.yaml
microservices/<service>/values/
```
