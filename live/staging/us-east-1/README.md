# staging / us-east-1 region

Region root for the staging environment in AWS `us-east-1`. **No
service-unit subdirectories are populated yet** — this region currently
contains only the region-root `terragrunt.hcl` and this README.

This is the future home of `08-waf-cloudfront` (CloudFront-scope WAF must
live in `us-east-1` regardless of where the distributions themselves
sit).

## Region-root file

`terragrunt.hcl` here is a **terminal config** — no `include` blocks. It
defines `region` / `aws_region` and a `generate "provider"` block that
writes `provider.tf` with the AWS provider pinned to:

- `hashicorp/aws` `5.94.1`
- `hashicorp/tls` `4.0.6`
- Terraform `>= 1.12.0`

## Populating this region

See [`../README.md`](../README.md) for the bootstrap recipe.

## See also

- [`../../README.md`](../../README.md) — top-level pattern.
- [`../README.md`](../README.md) — staging env overview.
- [`../ap-southeast-1/README.md`](../ap-southeast-1/README.md) — main staging region.
