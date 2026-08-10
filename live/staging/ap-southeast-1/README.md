# staging / ap-southeast-1 region

Region root for the staging environment in AWS `ap-southeast-1`. **No
service-unit subdirectories are populated yet** — this region currently
contains only the region-root `terragrunt.hcl` and this README.

## Region-root file

`terragrunt.hcl` here is a **terminal config** — no `include` blocks. It
defines `region` / `aws_region` and a `generate "provider"` block that
writes `provider.tf` with the AWS provider pinned to:

- `hashicorp/aws` `5.94.1`
- `hashicorp/tls` `4.0.6`
- Terraform `>= 1.12.0`

Terragrunt auto-loads this file when a unit runs in this directory.

## Populating this region

See [`../README.md`](../README.md) for the bootstrap recipe (copy dev's
unit directories, then edit `inputs` and `dependency.config_path` to
match the staging sibling layout).

## See also

- [`../../README.md`](../../README.md) — top-level pattern.
- [`../README.md`](../README.md) — staging env overview, pre-flight.
