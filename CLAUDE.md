# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Terragrunt + Terraform IaC for the **tfdemo / FIFA** AWS environment (project `tfdemo`, tier `production`, region `ap-southeast-1`, account `487542879553`). It provisions the full stack for one environment: networking, EKS, ECR, CI/CD pipelines for microservices, caches, search, static hosting, WAF, and monitoring. There is no application code here — only Terraform/Terragrunt, two CodeBuild buildspecs, and a couple of Lambda handlers embedded in modules.

The repo was migrated from a single monolithic Terraform root module to Terragrunt in mid-2026: reusable Terraform code now lives under `projects/modules/`, and environment-specific config lives under `projects/live/` as a nested environment/region/service hierarchy. Production is currently populated under `projects/live/production/` as 8 independent Terragrunt units, each with its own state file. Both live under `projects/` alongside this file and `MIGRATION.md`. If you're looking at old commits or documentation from before that migration, the module directory layout (`vpc/`, `eks/`, ... at repo root) has moved under `projects/modules/`. See `MIGRATION.md` for the state-migration runbook if the old root state hasn't been fully cut over yet.

## Commands

Run from `projects/live/production/` (each region subdirectory there — `ap-southeast-1/`, `us-east-1/` — contains independent Terragrunt units such as `networking/`, `cluster/`, `delivery/`, `data/`, `static-sites/`, `waf-regional/`, `waf-cloudfront/`, and `monitoring/`):

```bash
cd projects/live/production
terragrunt run-all init
terragrunt run-all validate
terragrunt run-all plan
terragrunt run-all apply
```

To work on a single unit instead of all 8: `cd projects/live/production/<region>/<unit> && terragrunt plan` / `terragrunt apply`. Terragrunt resolves cross-unit `dependency` blocks automatically — `terragrunt plan` inside a unit that depends on another will use that other unit's real outputs if it's been applied, or you'll need `--terragrunt-non-interactive` and the dependency's `mock_outputs` fallback (already configured) if it hasn't yet.

- Each unit's static config values live directly in its `terragrunt.hcl`, in a single top-level `inputs = {}` block — there's no dev/staging config yet, only `production`. There are no `terraform.tfvars` files anywhere under `projects/live/production/` and no `extra_arguments`/`-var-file` wiring; Terragrunt passes every key in `inputs` to Terraform as a `TF_VAR_*` env var natively, so nothing extra is needed to get values into a unit's plan/apply. (This is a change from the repo's initial Terragrunt migration, which used per-unit `terraform.tfvars` loaded via `extra_arguments` — those were converted into native `inputs` blocks afterward, see git history.)
- Cross-unit values (e.g. the `networking` unit's VPC/subnet/SG outputs feeding `cluster` and `data`) are wired via `dependency` blocks and merged into that same `inputs = {}` block, sitting alongside the unit's own static values — never hardcoded as a literal duplicate of another unit's value. Don't hardcode a value that's available from another unit's `dependency` output; reference `dependency.<name>.outputs.<output>` instead so it stays live if the upstream value ever changes.
- The root `projects/live/production/terragrunt.hcl` generates the S3 backend (per-unit state key `production/<region>/<unit>/terraform.tfstate` in `tfdemo-fifa-terraform-state-bucket-production`). Each region root then generates the correct AWS provider for services under that region. `waf-cloudfront` is deployed from `us-east-1`.
- The required Terraform version floor (`>= 1.12.0`, set in the root `terragrunt.hcl`'s `generate "provider"` block) and the Terragrunt version installed in the buildspecs (`projects/plan-buildspec.yaml`, `projects/apply-buildspec.yaml`) must be bumped together.
- There are no unit/integration tests, no linter config, and no CI status to check locally beyond `terragrunt run-all validate` / `plan`. Treat a clean `terragrunt run-all plan` (no unexpected diff) as the correctness bar for a change.
- `terraform fmt -recursive` works fine on the `.tf` files under `projects/modules/` (plain Terraform); `terragrunt hclfmt` is the equivalent for `.hcl` files (including each unit's `terragrunt.hcl` and its `inputs` block) under `projects/live/`.

### The `cicd-terraform (apply-from-local)` directory is a separate, self-contained Terraform config

It lives at the true repo root (not under `projects/`). It has its own backend (key `terraform-pipeline/terraform-pipeline.tfstate` in the same S3 bucket), its own provider/version pins, and its own variables — it is **not** part of the Terragrunt tree and is never run from `projects/live/production/`. It exists to bootstrap the CodePipeline (Source → Plan → Approval → Apply, using `projects/plan-buildspec.yaml` / `projects/apply-buildspec.yaml`, referenced by that relative path from each `aws_codebuild_project`'s `source.buildspec`) that subsequently manages the *Terragrunt units* on every push. It's applied manually/locally once per account, hence the directory name. It stayed plain Terraform (not converted, not moved into `projects/`) during the Terragrunt migration — it's rarely touched and converting it added risk for no benefit. The buildspecs themselves *were* moved into `projects/` (alongside `CLAUDE.md`/`MIGRATION.md`/`install.md`) since they're Terragrunt-specific; only this directory and its own `main.tf`/`variable.tf`/`output.tf`/`provider.tf`/`terraform.tfvars` stayed at the true repo root. When editing pipeline IAM permissions for this repo's own deploy pipeline, this is the directory to change (and its `buildspec` attributes if the buildspecs move again) — not `projects/modules/cicd`/`projects/modules/delivery`, which is the per-microservice pipeline instead (see below).

## Architecture

### Terragrunt units and their composition

`projects/live/production/` has 8 units, each pointing at a `projects/modules/` directory via `terraform { source = "../../../../modules/<x>" }` because services are nested under region directories. Most units are thin "composer" modules that call 2-4 of the underlying leaf modules together (mirroring what used to be one big root `main.tf`), grouped by what's naturally applied/changed together:

| Unit | Composer module | Wraps | Why grouped |
|---|---|---|---|
| `01-networking` | *(none — points straight at `modules/vpc`)* | `vpc` | Foundational, highest blast-radius; kept standalone so it's never lockstepped with less risky changes |
| `02-cluster` | `modules/cluster` | `eks`, `kubernetes` | `kubernetes` directly consumes `eks`'s cluster outputs (ALB ingress controller IAM, FluxCD, IRSA, EKS access entries) — always changed together |
| `04-delivery` | `modules/delivery` | `ecr`, `cicd` | Per-microservice image repos + build/deploy pipelines, same `ms_name`/`github_repository` lifecycle |
| `03-data` | `modules/data` | `elasticache-cluster-01`, `efs`, `opensearch`, `kibana-alb` | VPC-secure-subnet backing/data services; `kibana-alb` has an explicit `depends_on` on `opensearch` here (see below) |
| `06-static-sites` | `modules/static-sites` | `s3-static`, `s3-cloudfront-static` (×2 instances: static + deeplink) | All static-content hosting |
| `07-waf-regional` | `modules/waf-regional` | `waf` (REGIONAL, ap-southeast-1), `waf-alb-monitoring` | Same WAF ACL; alarm rule-name suffixes are hand-coupled to that WAF's rule config |
| `08-waf-cloudfront` | `modules/waf-cloudfront` | `waf` (CLOUDFRONT, us-east-1), `waf-cloudfront-monitoring` | Same as above, different region/scope |
| `05-monitoring` | `modules/monitoring` | `elasticache-monitoring`, `opensearch-monitoring` | No Terraform-level dependency on the resources they monitor (see below) |

(Table paths are relative to `projects/modules/` throughout this file — e.g. `modules/cluster` means `projects/modules/cluster`.)

The `waf` leaf module is instantiated twice (once per WAF unit) with the composer's `module` block named `waf-alb` / `waf-cloudfront` respectively — matching the names used in the pre-Terragrunt root `main.tf` — so that resource addresses stayed stable across the state-migration cutover. Same for `s3-cloudfront-static`, instantiated twice inside `modules/static-sites` as `s3-cloudfront-static` (static) and `s3-cloudfront-deeplink` (deeplink).

### Cross-unit dependencies

Only three units have real `dependency` blocks, matching exactly what the old root `main.tf` wired via `module.x.output` (nothing new was invented):

- `cluster` ← `networking` (`vpc_id`, private subnets, secure/alb/cms SG IDs)
- `data` ← `networking` (secure/private/public subnets, secure/efs/kibana-alb SG IDs)
- `static-sites` ← `waf-cloudfront` (`web_acl_arn` → `web_acl_id` on both CDN instances)

One deliberate improvement over the old design: `monitoring`'s `elasticache_replication_group_id` input is wired via a `dependency "data"` block to `data`'s `elasticache_replication_group_id` output, instead of the old root's manually-copied `var.monitoring_redis_replication_group_id`. Everything else in `monitoring` (per-node primary/replica cluster IDs, the OpenSearch domain name) is still a plain literal value in that unit's `inputs` block, same as before — no matching module output exists for those without further module changes, which was kept out of scope for the Terragrunt migration.

`delivery`, `waf-regional`, `waf-cloudfront`, and the non-Redis-replication-group half of `monitoring` have **no** cross-unit Terraform dependencies — their `monitoring_*` values (WAF ACL name, ALB ARN, OpenSearch domain name) are plain vars today, same as pre-migration, because the underlying modules don't expose matching outputs and/or the resource (e.g. the API ALB) isn't managed by any Terraform module in this repo (it's created by the EKS ingress controller).

### One ordering fix made possible by the regrouping

`kibana-alb`'s `data.aws_network_interfaces` lookup filters by `requester-id = "amazon-elasticsearch"` to find OpenSearch's ENIs — a string-matched, non-Terraform-native reference with no explicit dependency edge on the `opensearch` module. In the old single-root config this was a latent race condition on first-ever apply. Now that both live in the same `data` composer module, `modules/data/main.tf` adds an explicit `depends_on = [module.opensearch]` on the `kibana-alb` module call to close that gap.

### State

Each unit gets its own state file at `s3://tfdemo-fifa-terraform-state-bucket-production/production/<region>/<unit>/terraform.tfstate` (native S3 locking via `use_lockfile`, generated by the root `projects/live/production/terragrunt.hcl`). This replaced the old single shared `terraform.tfstate` key — see `MIGRATION.md` for the cutover runbook if that hasn't been completed yet in this environment.

`modules/delivery/main.tf` has an `import` block adopting the pre-existing CI/CD pipeline log S3 bucket into `module.cicd.aws_s3_bucket.s3-bucket-backend` (moved here from the old root `imports.tf`) — check this before touching that resource, the fix for an `AlreadyExists` error is usually adjusting this block, not `-replace`.

### Two independent WAF stacks + matching monitoring

WAF is deployed twice from the same `modules/waf` leaf module, in different scopes/regions/Terragrunt units, because CloudFront WAF must live in `us-east-1`:

- `waf-regional` unit — `REGIONAL` scope, `ap-southeast-1`, associated with the API ALB (`waf_alb_arn`).
- `waf-cloudfront` unit — `CLOUDFRONT` scope, `us-east-1` (via that unit's `generate "provider"` override), feeds `web_acl_id` into the `static-sites` unit's CloudFront distributions via a `dependency` block.

Each has a paired `cloudwatch-monitoring/*-monitoring` leaf module in the same unit, alarming on the WAF's own CloudWatch metrics **and** delivering to Google Chat via a Lambda (`lambda_gchat.py` in each monitoring submodule, already using `${path.module}`-relative paths so it survived the move into `modules/` unchanged). The monitoring modules take resource identifiers (WAF ACL name, log group name, ALB ARN, Redis cluster IDs, OpenSearch domain name) as plain vars rather than dependency outputs (with the one `monitoring` exception noted above) — if a monitored resource is renamed/recreated, the corresponding value in that unit's `terragrunt.hcl` `inputs` block must be updated by hand.

Both WAF instances currently run with `waf_count_mode_only = true` (observe, don't block) — flipping to enforcing mode is a deliberate, separate change after 48–72h of watching CloudWatch metrics, not something to bundle into an unrelated change. `waf-regional` and `waf-cloudfront`'s `inputs` blocks intentionally duplicate several values (IP allow/block lists, managed-rule-group toggles, logging config) that used to be a single shared root variable — now that they're independent units/state files, keep both units' `inputs` in sync by hand when changing these.

Redis monitoring uses CloudWatch metric-math to aggregate primary/replica nodes into one alarm per signal because of the 10-query-per-alarm CloudWatch limit — see the comments in `projects/live/production/ap-southeast-1/monitoring/terragrunt.hcl` around `monitoring_redis_primary_cluster_ids` for how the 6-shard cluster is split, and verify node IDs from the AWS Console before changing them (the `-001`/`-002` suffix convention for primary/replica is not guaranteed elsewhere).

### CI/CD for microservices (`modules/delivery`) vs. this repo's own deploy pipeline

The `delivery` unit (`modules/cicd` inside `modules/delivery`) is **not** what deploys this Terraform/Terragrunt repo — it provisions per-microservice CodePipelines (one pipeline per entry in `github_repository`, paired 1:1 with `ms_name` for ECR repo naming) that build and push Docker images to ECR. It creates parallel pipeline stages for both `environment` ("prod") and `cls_environment` ("preprod") from one `inputs` block. It also wires a Lambda + SNS + EventBridge notification path (build failures, ECR pushes) to Google Chat via `modules/cicd/index.js`.

This repo's *own* infra pipeline (the one that runs `terragrunt run-all plan`/`apply` against `projects/live/production/` on every push) is bootstrapped by `cicd-terraform (apply-from-local)/` at the true repo root — see above. `projects/plan-buildspec.yaml` / `projects/apply-buildspec.yaml` install both `terraform` and `terragrunt`, then `cd projects/live/production` and run `terragrunt run-all init/plan/apply` from there. CodeBuild's working directory is still the full checked-out repo regardless of where the buildspec file itself lives, so moving these into `projects/` didn't require changing that `cd`.

### Secrets are injected at apply time, not in `inputs`

`docker_password` (`delivery`), `os_db_user`/`os_db_password` (`data`) are deliberately absent from their unit's `terragrunt.hcl` `inputs` block — they're injected as `TF_VAR_*` environment variables by the `cicd-terraform (apply-from-local)` CodeBuild jobs, sourced from Secrets Manager. Don't add real values for these to an `inputs` block (env vars take precedence over `inputs` in Terragrunt's TF_VAR resolution, so this works the same way it did with the old `-var-file`). (The Google Chat webhook URLs and `AlarmChatWebhook`, by contrast, are plain literal values in the relevant units' `inputs` blocks today despite being marked `sensitive = true` in their variable declarations — that's inherited from the pre-migration `production.tfvars` and wasn't introduced or fixed by this migration or the later tfvars→inputs conversion; be aware if you're auditing secret handling.)

### Naming & tagging convention

Nearly every resource across modules follows `${var.project}-<resource-purpose>-${var.environment}` for names and this tag set:

```hcl
tags = {
  Project     = var.project
  environment = var.environment
  Tier        = var.tier
  CreatedBy   = "terraform"
}
```

Match this when adding resources — inconsistent naming/tagging is one of the few things that'll stand out in review here.

### VPC subnet tiers

`modules/vpc/main.tf` defines three subnet tiers, each with its own CIDR/AZ variable set: `public` (ALB/NAT/IGW), `private` (EKS nodes/Fargate), and `secure` (databases, caches, OpenSearch — no direct route to the internet gateway). Downstream units pick the tier via which `networking` unit output (and matching `*_sg_id` output) they consume in their `dependency` block — check which tier a new module should land in before wiring it up.

### Modules and directories intentionally left alone (and outside projects/)

Everything that was commented out in the old root `main.tf` — `documentdb`, `rds-cluster-01`, `rds-proxy-cluster-01`, `elasticache-cluster-02`, `appstream`, `cloudwatch-alarm`, `eks-prometheus-grafana-node-group` — stayed at the true repo root exactly as it was and was **not** moved into `projects/modules/` or given a `projects/live/production/` unit. They're staged for future use, not deployed; don't assume resources from these exist in AWS. If you re-enable one, decide then whether it becomes its own unit or joins an existing composer, and move/wire it deliberately rather than assuming it fits the current grouping.

- `modules/eks/main.tf_bkp` and `main.tf_bkp_20240305` (i.e. `projects/modules/eks/...`) are dead reference copies (non-`.tf` extension, ignored by Terraform) — do not edit expecting them to take effect.
- `lambda/` (true repo root) is an empty placeholder directory, not a deployed Lambda.
- `main.tf`, `variable.tf`, `output.tf`, `provider.tf`, `imports.tf`, `production.tfvars` at the true repo root (not under `projects/`) are the **pre-Terragrunt config**, kept temporarily as a migration fallback — see `MIGRATION.md`. Once the state cutover in that document is complete and verified, these get archived/deleted; don't build new work on top of them.

will run from test
