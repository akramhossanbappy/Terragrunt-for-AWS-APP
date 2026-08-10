# Production environment

Active AWS environment. Project `singleapp`, account `487542879553`,
region `ap-southeast-1`. State backend is
`singleapp-fifa-terraform-state-bucket-production` (already configured in
`production/terragrunt.hcl`).

## Layout

```
production/
├── terragrunt.hcl        ← env root — project=singleapp,
│                            environment=prod, tier=production,
│                            state_bucket=singleapp-fifa-terraform-state-
│                            bucket-production (terminal; auto-loaded by
│                            descendant units).
├── ap-southeast-1/       ← ap-southeast-1 region root
│   ├── terragrunt.hcl    ← terminal; generates AWS provider for this region
│   ├── 01-networking/    ← VPC (points straight at modules/vpc)
│   ├── 02-cluster/       ← EKS + Kubernetes add-ons (composer module)
│   ├── 03-data/          ← ElastiCache, EFS, OpenSearch + Kibana ALB
│   ├── 04-delivery/      ← ECR + per-microservice CodePipelines
│   ├── 05-monitoring/    ← ElastiCache/OpenSearch CloudWatch alarms
│   ├── 06-static-sites/  ← S3 + CloudFront static/deeplink sites
│   └── 07-waf-regional/  ← Regional WAF + monitoring
└── us-east-1/            ← us-east-1 region root (WAF-CloudFront only)
    ├── terragrunt.hcl    ← terminal; generates AWS provider for this region
    └── 08-waf-cloudfront/← CloudFront WAF (must live in us-east-1)
                            + monitoring
```

## Run Terragrunt

```bash
cd projects/live/production
terragrunt run-all init
terragrunt run-all validate
terragrunt run-all plan
terragrunt run-all apply
```

Single unit:

```bash
cd projects/live/production/ap-southeast-1/01-networking
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

Cross-unit `dependency` blocks resolve automatically — `terragrunt plan` in
a unit that depends on another uses that other unit's real outputs if it's
been applied; otherwise the dependency's `mock_outputs` fallback is used
(already configured).

## Per-unit state

Each unit gets its own state file at:

```
s3://singleapp-fifa-terraform-state-bucket-production/production/<region>/<unit>/terraform.tfstate
```

This split is deliberate — the production stack used to share a single
state file before the Terragrunt migration. See `../../MIGRATION.md` for
the state cutover runbook if the old shared state is still in use.

## Cross-unit dependencies

Three units have real `dependency` blocks:

- `cluster` ← `networking` (VPC + private subnets + secure/alb/cms SGs)
- `data` ← `networking` (secure/private subnets + secure/efs/kibana-alb SGs)
- `static-sites` ← `waf-cloudfront` (`web_acl_arn` → `web_acl_id`)

`monitoring` also has a small `dependency "data"` block to pull
`elasticache_replication_group_id` instead of copying the value by hand.

## WAF

Both WAF instances run with `waf_count_mode_only = true` (observe, don't
block). Flipping to enforcing mode is a deliberate separate change after
48–72h of watching CloudWatch metrics, not something to bundle into an
unrelated change.

`waf-regional` and `waf-cloudfront`'s `inputs` blocks intentionally
duplicate several values (IP allow/block lists, managed-rule-group
toggles, logging config) that used to be a single shared root variable —
keep both units' `inputs` in sync by hand when changing these.

## See also

- [`../../CLAUDE.md`](../../CLAUDE.md) — repo-wide conventions, unit
  composition table, secrets handling, naming/tagging.
- [`../../MIGRATION.md`](../../MIGRATION.md) — Terragrunt migration
  runbook, state cutover steps.
- [`../README.md`](../README.md) — top-level pattern, shared config,
  lint.
