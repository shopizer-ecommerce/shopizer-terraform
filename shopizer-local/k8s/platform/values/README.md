# Platform Values

Values are grouped by environment.

- `local/`: values used by the local Kind-based Shopizer environment.

When another environment is needed, add a sibling folder such as `dev/` or `prod/`.
Extract shared settings into `common/` only when there is real overlap across
environments.
