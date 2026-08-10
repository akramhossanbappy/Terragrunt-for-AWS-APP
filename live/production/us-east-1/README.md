# production / us-east-1 region

Region root for the production environment in AWS `us-east-1`. This region
only hosts the CloudFront-scope WAF unit — CloudFront WAFs must live in
`us-east-1` regardless of where the distributions themselves do.

| Unit                 | Module                 | Wraps                                       |
|----------------------|------------------------|---------------------------------------------|
| `08-waf-cloudfront`  | `modules/waf-cloudfront` | `waf` (CLOUDFRONT) + `waf-cloudfront-monitoring` |

## Region-root file

`terragrunt.hcl` here is a **terminal config** — no `include` blocks. It
defines `region` / `aws_region` and a `generate "provider"` block that
writes `provider.tf` with the AWS provider pinned to:

- `hashicorp/aws` `5.94.1`
- `hashicorp/tls` `4.0.6`
- Terraform `>= 1.12.0`

Terragrunt auto-loads this file when a unit runs in this directory.

## Why `us-east-1`

AWS only allows `AWS WAF` associations on CloudFront distributions from
WAF ACLs created in `us-east-1`. Even when the underlying distributions
sit in `ap-southeast-1` (see `../ap-southeast-1/06-static-sites/`), the
WAF ACL must be created here. The `06-static-sites` unit's
`dependency "waf-cloudfront"` block pulls `web_acl_arn` from this region's
unit.

## WAF

`08-waf-cloudfront` runs with `waf_count_mode_only = true` (observe, don't
block) and is mirrored by `../ap-southeast-1/07-waf-regional`. Keep both
units' `inputs` in sync by hand when changing IP allow/block lists,
managed-rule-group toggles, or logging config — they intentionally
duplicate those values.

## See also

- [`../../CLAUDE.md`](../../CLAUDE.md) — repo-wide conventions.
- [`../../README.md`](../../README.md) — top-level pattern.
- [`../README.md`](../README.md) — production env overview.
- [`../ap-southeast-1/README.md`](../ap-southeast-1/README.md) — main production region.
