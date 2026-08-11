# Dev environment

Sandbox environment mirroring production's structure, with WAF toggles off
and a placeholder state bucket.

## Layout

```
dev/
├── terragrunt.hcl        ← env root — defines state_bucket, environment,
│                            tier, settings (terminal; Terragrunt
│                            auto-loads it from descendant units).
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

## Pre-flight

1. **Replace the placeholder bucket.** Edit `dev/terragrunt.hcl` and set
   `state_bucket` to the real dev S3 bucket name (currently
   `"REPLACE_WITH_DEV_STATE_BUCKET"`). The bucket must exist, be in
   `ap-southeast-1`, and have native S3 locking enabled.
2. Confirm AWS credentials are available:
   `aws sts get-caller-identity` should succeed.
3. `terragrunt --version` should be `>= 0.55` (we tested on
   `0.83.2`); `terraform --version` should be `>= 1.12.0`.

## Run Terragrunt

```bash
cd projects/live/dev
terragrunt run-all init
terragrunt run-all validate
terragrunt run-all plan
terragrunt run-all apply
```

Single unit:

```bash
cd projects/live/dev/ap-southeast-1/01-networking
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## Dev-specific overrides

Dev differs from production in two ways (set in `dev/terragrunt.hcl`'s
`settings = merge(local.common_defaults, {...})`):

- `waf_regional_enabled = false` — no regional WAF in dev.
- `waf_cloudfront_enabled = false` — no CloudFront WAF in dev.

`waf_count_mode_only = true` matches production (observe-don't-block).
Everything else (`monitoring_enabled`, `data_enabled`, `delivery_enabled`,
`static_sites_enabled`, `cluster_enabled`) defaults to `true` from
`common_defaults`.

## Cross-unit dependencies

Three units have real `dependency` blocks:

- `cluster` ← `networking` (VPC + private subnets + secure/alb/cms SGs)
- `data` ← `networking` (secure/private subnets + secure/efs/kibana-alb SGs)
- `static-sites` ← `waf-cloudfront` (`web_acl_arn` → `web_acl_id`)

Each unit has `mock_outputs` for `validate` / `plan` so planning works
even when the dependency hasn't been applied yet.

## See also

- [`../README.md`](../README.md) — top-level pattern, shared config, lint.
- Per-region READMEs in each `<region>/README.md`.
