# Local Cleanup Commands

This file documents the local cleanup commands used by the Shopizer Terraform
Kind environment.

## Destroy Terraform Resources

Run from:

```bash
cd /Users/ioannislafiotis/Desktop/playground/shopizer-terraform/shopizer-local
```

Destroy the local stack:

```bash
terraform destroy
```

Terraform destroy should remove:

- the Kind cluster named `terraform-kind`
- the local Docker registry container named `kind-registry`
- local Shopizer images pushed to `localhost:5001`

## Check Kind Clusters

List Kind clusters:

```bash
kind get clusters
```

After destroy, `terraform-kind` should not be listed.

## Check Local Registry Container

Check whether the local registry container still exists:

```bash
docker ps -a | grep kind-registry
```

If nothing is printed, the container is gone.

## Check Local Shopizer Images

List only local Shopizer images:

```bash
docker images --format '{{.Repository}}:{{.Tag}}' | grep '^localhost:5001/shopizer-'
```

The first command lists all local images as `repository:tag`:

```bash
docker images --format '{{.Repository}}:{{.Tag}}'
```

The `grep` part keeps only images that start with the local registry and
Shopizer prefix:

```bash
grep '^localhost:5001/shopizer-'
```

This avoids matching unrelated images such as:

```text
postgres:15
registry:2
kindest/node:<version>
```

## Remove Local Shopizer Images Manually

Remove only local Shopizer images:

```bash
docker images --format '{{.Repository}}:{{.Tag}}' \
  | grep '^localhost:5001/shopizer-' \
  | xargs -r docker rmi
```

`xargs -r` means Docker remove is not called when there are no matching images.

## Remove Registry Container Manually

If the registry container remains:

```bash
docker rm -f kind-registry
```

## Remove Kind Cluster Manually

If the Kind cluster remains:

```bash
kind delete cluster --name terraform-kind
```

## Remove Kind Docker Network Manually

If needed:

```bash
docker network rm kind
```

Only run this if no Kind clusters still need the `kind` network.

