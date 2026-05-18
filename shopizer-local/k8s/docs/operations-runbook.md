# Operations Runbook

Useful commands for the local Shopizer Kubernetes setup.

## Validate Configuration

Terraform formatting:

```bash
terraform fmt -check \
  /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/main.tf \
  /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/variables.tf
```

Terraform validation:

```bash
terraform -chdir=/Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local validate
```

Generic service chart:

```bash
helm lint /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/k8s/charts/generic-java-service
```

Argo CD chart:

```bash
helm lint /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/k8s/platform/charts/argo-cd \
  -f /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/k8s/platform/values/local/argocd-values.yaml
```

Render one service:

```bash
kustomize build --enable-helm /Users/ioannislafiotis/Desktop/playground/microservices/shop
```

Render all Java services:

```bash
for service in shop users orders merchants references; do
  kustomize build --enable-helm "/Users/ioannislafiotis/Desktop/playground/microservices/$service" >/tmp/$service.yaml
done
```

## Build Images

From `shopizer-local`:

```bash
./build.sh /Users/ioannislafiotis/Desktop/playground/microservices references merchants users shop orders
```

List local images:

```bash
docker images --format '{{.Repository}}:{{.Tag}}' | grep '^localhost:5001/shopizer-'
```

## Cluster Checks

List Kind clusters:

```bash
kind get clusters
```

Check pods:

```bash
kubectl get pods -A
```

Check services:

```bash
kubectl get svc -A
```

Check ingress:

```bash
kubectl get ingress -A -o wide
```

## Argo CD

Check Argo CD:

```bash
kubectl get pods -n argocd
kubectl rollout status deployment/argocd-server -n argocd
```

Port-forward UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Initial admin password:

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

## Cilium

Check the Argo CD application:

```bash
kubectl get application cilium -n argocd -o wide
kubectl describe application cilium -n argocd
```

Check Cilium pods:

```bash
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
kubectl get pods -n kube-system -l io.cilium/app=operator -o wide
kubectl describe pods -n kube-system -l io.cilium/app=operator
```

For the local single-node kind cluster, Cilium operator must run with one
replica:

```yaml
operator:
  replicas: 1
```

The upstream Cilium docs describe `operator.replicas` as the Helm setting for
operator high availability. In this local cluster there is only one Kubernetes
node, and the operator pods request host ports `9234` and `9963`. If
`operator.replicas` is greater than `1`, the first operator pod starts and the
extra operator pod stays `Pending` with a scheduler event like:

```text
0/1 nodes are available: 1 node(s) didn't have free ports for the requested pod ports
```

That pending extra replica can make Argo CD show Cilium as `Progressing` or
`Degraded`, even though one operator pod is running.

## App Secret

Shared app secret:

```text
k8s/apps/shared/app-secret.yaml
```

Apply manually:

```bash
kubectl apply -f /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local/k8s/apps/shared/app-secret.yaml
```

Restart a service after secret changes:

```bash
kubectl rollout restart deployment/users
```

## Debug Ports

Port-forward service debug ports as needed:

```bash
kubectl port-forward deployment/references 5004:5004
kubectl port-forward deployment/merchants 5005:5005
kubectl port-forward deployment/users 5007:5007
kubectl port-forward deployment/shop 5008:5008
```

## Common Failure Checks

If service pods cannot pull images, check:

```bash
docker ps | grep kind-registry
docker network inspect kind
docker images --format '{{.Repository}}:{{.Tag}}' | grep '^localhost:5001'
```

If Kustomize cannot read values files, confirm the service `kustomization.yaml`
is at the service root and values are under that same root.

If Terraform validation fails because providers cannot execute in a restricted
environment, run validation outside the sandbox:

```bash
terraform -chdir=/Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local validate
```
