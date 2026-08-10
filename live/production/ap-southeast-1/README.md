# production / ap-southeast-1 region

Region root for the production environment in AWS `ap-southeast-1`. Seven
service units are deployed here:

| Unit            | Module              | Wraps                                                   |
|-----------------|---------------------|---------------------------------------------------------|
| `01-networking` | `modules/vpc`       | VPC + public/private/secure subnets + NAT/IGW + SGs     |
| `02-cluster`    | `modules/cluster`   | `eks` + `kubernetes` add-ons                            |
| `03-data`       | `modules/data`      | `elasticache-cluster-01` + `efs` + `opensearch` + `kibana-alb` |
| `04-delivery`   | `modules/delivery`  | `ecr` + per-microservice `cicd`                         |
| `05-monitoring` | `modules/monitoring`| `elasticache-monitoring` + `opensearch-monitoring`       |
| `06-static-sites` | `modules/static-sites` | `s3-static` + 2× `s3-cloudfront-static` (static + deeplink) |
| `07-waf-regional` | `modules/waf-regional` | `waf` (REGIONAL) + `waf-alb-monitoring`               |

## Region-root file

`terragrunt.hcl` here is a **terminal config** — no `include` blocks. It
defines `region` / `aws_region` and a `generate "provider"` block that
writes `provider.tf` with the AWS provider pinned to:

- `hashicorp/aws` `5.94.1`
- `hashicorp/tls` `4.0.6`
- Terraform `>= 1.12.0`

Terragrunt auto-loads this file when a unit runs in this directory,
merging its `locals` and `generate` blocks into the unit's effective
configuration.

## Cross-unit dependency edges

Only three units in this region have real `dependency` blocks:

- `02-cluster/terragrunt.hcl` ← `01-networking`
- `03-data/terragrunt.hcl` ← `01-networking`
- `06-static-sites/terragrunt.hcl` ← `08-waf-cloudfront` (in `us-east-1/`)

Each unit's `dependency` block carries `mock_outputs` for `validate` /
`plan`, so you can `terragrunt plan` a downstream unit before its
dependency has been applied.

`modules/data/main.tf` also adds an internal `depends_on = [module.opensearch]`
on its `kibana-alb` module to close a latent first-apply race against the
OpenSearch ENI lookup. See `../../CLAUDE.md` for the full story.

## See also

- [`../../CLAUDE.md`](../../CLAUDE.md) — repo-wide conventions.
- [`../../README.md`](../../README.md) — top-level pattern.
- [`../README.md`](../README.md) — production env overview, per-unit state paths, WAF notes.
