# Platform Kubernetes Assets

This folder contains local cluster/platform resources. Application service deployment
configuration lives with each service under `microservices/<service>`.

## Layout

- `charts/`: vendored third-party Helm charts for platform components.
- `values/`: local values for the platform Helm chart releases.
- `manifests/`: plain Kubernetes manifests for local infrastructure dependencies.
- `docs/`: runbooks and notes for platform operations.

The reusable application chart remains in `../charts/generic-java-service` because it
is consumed by the service-owned Kustomize entrypoints.
