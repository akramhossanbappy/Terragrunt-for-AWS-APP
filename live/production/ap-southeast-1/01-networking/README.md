# 01-networking — VPC

Provisions the production VPC and its three subnet tiers:

| Tier     | Purpose                                                |
|----------|--------------------------------------------------------|
| public   | ALB, NAT gateways, internet gateway                    |
| private  | EKS nodes + Fargate                                    |
| secure   | Databases, caches, OpenSearch (no internet route)      |

This unit points straight at `projects/modules/vpc` — no composer module
in front of it. Foundational and highest blast-radius, kept standalone
so it's never lockstepped with less-risky changes.

## Inputs

Every input in `terragrunt.hcl`'s `inputs = {}` block corresponds to a
required variable in `modules/vpc/variable.tf`:

- `project`, `environment`, `tier` — naming/tagging labels.
- `vpc_cidr` — VPC CIDR block (`10.0.0.0/16` for production).
- `public_subnets_cidr`, `private_subnets_cidr`, `secure_subnets_cidr`
  — one CIDR per AZ.
- `availability_zones_public`, `availability_zones_private`,
  `availability_zones_secure` — AZ names matching the CIDRs above.
- `cidr_block-internet_gw`, `cidr_block-nat_gw` — destination CIDR for
  the IGW/NAT route tables.

## Known issues

- `modules/vpc/variable.tf` declares `cidr_block-nat_gw` and
  `cidr_block-internet_gw` but `modules/vpc/main.tf` never references
  them — the route tables hardcode `0.0.0.0/0`. Either remove the
  variables or wire them up. Tracked separately, out of scope here.

## Run

```bash
cd projects/live/production/ap-southeast-1/01-networking
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

This unit is depended on by `02-cluster` and `03-data`. Apply it first
(or use the dependency's `mock_outputs` fallback, which is already
configured).

## See also

- [`../README.md`](../README.md) — production/ap-southeast-1 region overview.
- [`../../../README.md`](../../../README.md) — top-level pattern.
- [`../../../CLAUDE.md`](../../../CLAUDE.md) — repo-wide conventions.