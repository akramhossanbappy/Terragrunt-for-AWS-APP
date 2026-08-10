# Migrating existing state into the Terragrunt units

This repo has been restructured from one monolithic root Terraform module
into `projects/modules/` (reusable code) + `projects/live/production/` (8
independent Terragrunt units, each with its own state file). See
`CLAUDE.md` (in this same `projects/` directory) for the architecture.
**This document is a runbook, not something already executed.**
The old root config (`main.tf`, `variable.tf`, `output.tf`, `provider.tf`,
`imports.tf`, `production.tfvars`) is left in place at the true repo root
(one level up from `projects/`) specifically so this migration can be done
safely and rolled back if needed — do not delete those files until step 5
below.

The existing state lives at:

```
s3://tfdemo-fifa-terraform-state-bucket-production/terraform.tfstate
```

Every resource currently in AWS is tracked there under one root. Simply
running `terragrunt apply` against the new units **without doing this
migration first** will make Terraform try to recreate every resource under
new, empty per-unit states — do not do that.

## 1. Pull the old state and list resource addresses

```bash
cd /path/to/tf_to_tg    # the true repo root — where the old main.tf/provider.tf still live, not projects/
terraform init                       # uses the backend block in provider.tf, key = terraform.tfstate
terraform state pull > /tmp/old-root.tfstate
terraform state list                 # full inventory, grouped by module.* prefix
```

## 2. Address mapping (old root → new unit)

Most modules kept their child-module name, so most resource addresses are
**unchanged** other than moving to a new state file. Two exceptions to
watch for:

| Old root address prefix | New unit | New address prefix | Note |
|---|---|---|---|
| `module.vpc.*` | `networking` | *(no prefix — root-level)* | `vpc` is not wrapped in a composer; `projects/modules/vpc` **is** the unit's root module, so `module.vpc.aws_vpc.my_vpc` → `aws_vpc.my_vpc` |
| `module.eks.*` | `cluster` | `module.eks.*` | unchanged |
| `module.kubernetes.*` | `cluster` | `module.kubernetes.*` | unchanged |
| `module.ecr.*` | `delivery` | `module.ecr.*` | unchanged |
| `module.cicd.*` | `delivery` | `module.cicd.*` | unchanged |
| `module.elasticache-cluster-01.*` | `data` | `module.elasticache-cluster-01.*` | unchanged |
| `module.efs.*` | `data` | `module.efs.*` | unchanged |
| `module.opensearch.*` | `data` | `module.opensearch.*` | unchanged |
| `module.kibana-alb.*` | `data` | `module.kibana-alb.*` | unchanged |
| `module.s3-static.*` | `static-sites` | `module.s3-static.*` | unchanged |
| `module.s3-cloudfront-static.*` | `static-sites` | `module.s3-cloudfront-static.*` | unchanged |
| `module.s3-cloudfront-deeplink.*` | `static-sites` | `module.s3-cloudfront-deeplink.*` | unchanged |
| `module.waf-alb.*` | `waf-regional` | `module.waf-alb.*` | unchanged (composer kept the original name) |
| `module.waf-alb-monitoring.*` | `waf-regional` | `module.waf-alb-monitoring.*` | unchanged |
| `module.waf-cloudfront.*` | `waf-cloudfront` | `module.waf-cloudfront.*` | unchanged |
| `module.waf-cloudfront-monitoring.*` | `waf-cloudfront` | `module.waf-cloudfront-monitoring.*` | unchanged |
| `module.elasticache-monitoring.*` | `monitoring` | `module.elasticache-monitoring.*` | unchanged |
| `module.opensearch-monitoring.*` | `monitoring` | `module.opensearch-monitoring.*` | unchanged |

Only `vpc` needs an actual address rewrite (dropping the `module.vpc.`
prefix). Everything else is a pure state-file split with identical
addresses.

## 3. Per-unit migration

Do this **one unit at a time**, in dependency order
(`networking` → `cluster`/`data` → `static-sites`/`monitoring`, `delivery`
and `waf-regional`/`waf-cloudfront` have no dependencies so can go anytime
before `static-sites`):

```bash
UNIT=networking   # repeat per unit

# 3a. Initialize the new unit's (currently empty) backend
cd projects/live/production/$UNIT
terragrunt init

# 3b. Move each resource for this unit from the old state into the new one.
#     For vpc, drop the "module.vpc." prefix on the destination address.
#     For every other unit, source and destination addresses are identical.
terraform state mv \
  -state=/tmp/old-root.tfstate \
  -state-out=<pulled new unit state, or use `terragrunt state mv` directly against both backends> \
  'module.vpc.aws_vpc.my_vpc' 'aws_vpc.my_vpc'
# ... repeat for every resource address belonging to this unit
# (terraform state list -state=/tmp/old-root.tfstate | grep '^module.vpc\.' gives the full list)

# 3c. Verify — must show NO changes. A diff here means an address or input
#     mismatch, not real infrastructure drift. Stop and fix before continuing.
terragrunt plan
```

`terraform state mv` normally operates on a single state file. Since the
source (old root) and destination (new per-unit) states live in different S3
keys, the practical approach is either:
- pull both states locally, `terraform state mv -state=old.tfstate -state-out=new.tfstate <addr> <addr>`, then `terraform state push -state-out=new.tfstate` (or `terragrunt state push`) the result into the new unit's backend, **or**
- use `terragrunt state mv` per resource directly against the two live backends, if your Terraform/Terragrunt version supports cross-backend moves.

Either way, work from a copy of the old state (`/tmp/old-root.tfstate`) —
never mutate the live old-root state file in place until every unit has
been verified clean, in case you need to re-derive a mapping.

## 4. Full verification

Once all 8 units have been migrated:

```bash
cd projects/live/production
terragrunt run-all plan --terragrunt-non-interactive
```

This must show **zero changes** across all 8 units. That's the proof the
grouped units reproduce today's applied infrastructure exactly — not just
`validate`, which only checks config syntax, not real state.

Also diff each unit's `terragrunt.hcl` `inputs` block against the relevant
slice of the old `production.tfvars` by hand, to confirm no value was
dropped or mistyped during the split (`grep`-diffing is fine — there's no
automated check for this since the values live in two different file
formats/shapes now).

## 5. Decommission the old root

Only after step 4 passes clean:

- Confirm the old root's state (`terraform.tfstate` at the bucket root key)
  is not referenced by anything else (double-check no other pipeline or
  script points at it).
- Archive or delete `main.tf`, `variable.tf`, `output.tf`, `provider.tf`,
  `imports.tf`, `production.tfvars` at the true repo root (not `projects/`).
- Optionally empty the old state (`terraform state rm` everything, or just
  leave the now-empty/orphaned state object in S3 — it no longer manages
  anything once every resource has been moved out via step 3).

## Rollback

If a `terragrunt plan` in step 3c shows unexpected changes, do **not**
apply. The old root state (`/tmp/old-root.tfstate` and the live S3 object)
is untouched by `state mv -state=... -state-out=...` against a local copy,
so nothing is lost — fix the address/input mismatch and re-run the move for
that resource. The old root config at the true repo root remains fully
functional (`terraform plan -var-file=production.tfvars` from the true repo
root) until you delete it in step 5, so it's always available as a fallback
during the migration window.
