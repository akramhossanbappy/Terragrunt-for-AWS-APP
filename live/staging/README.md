# Staging environment

Skeleton / placeholder environment. The env root and both region roots
exist (so the directory structure matches dev/preprod/production), but
no service-unit subdirectories have been populated yet.

## Layout

```
staging/
├── terragrunt.hcl        ← env root — defines state_bucket, environment,
│                            tier, settings (terminal; currently using
│                            placeholder bucket).
├── ap-southeast-1/       ← ap-southeast-1 region root (empty)
│   ├── terragrunt.hcl    ← terminal; generates AWS provider for this region
│   └── README.md         (region readme)
└── us-east-1/            ← us-east-1 region root (empty)
    ├── terragrunt.hcl    ← terminal; generates AWS provider for this region
    └── README.md
```

## Pre-flight

1. **Replace the placeholder bucket.** Edit `staging/terragrunt.hcl` and set
   `state_bucket` to the real staging S3 bucket name (currently
   `"REPLACE_WITH_STAGING_STATE_BUCKET"`). The bucket must exist, be in
   `ap-southeast-1`, and have native S3 locking enabled.
2. AWS credentials available (`aws sts get-caller-identity` succeeds).
3. `terragrunt --version >= 0.55`; `terraform --version >= 1.12.0`.

## Populating this environment

This environment currently has no service-unit subdirectories. To bring it
up to match `dev/`, copy dev's per-region structure as a starting point:

```bash
# from projects/live/
for unit in 01-networking 02-cluster 03-data 04-delivery \
            05-monitoring 06-static-sites 07-waf-regional; do
  cp -R dev/ap-southeast-1/$unit staging/ap-southeast-1/
done
cp -R dev/us-east-1/08-waf-cloudfront staging/us-east-1/
```

Then edit each unit's `inputs = {}` block to use staging-appropriate CIDR
ranges, AZs, and any other staging-specific values, and set
`dependency.<x>.config_path` to `"../<unit-name>"` to match the staging
sibling layout.

Cross-unit dependency blocks already use relative paths and
`mock_outputs`, so they continue to work for `validate` and `plan` without
everything being applied first.

## Override knobs

`settings = merge(local.common_defaults, { waf_count_mode_only = true })`
matches production (WAF stays in observe-only mode if/when it's enabled).

## Run Terragrunt (once units are added)

```bash
cd projects/live/staging
terragrunt run-all init
terragrunt run-all validate
terragrunt run-all plan
terragrunt run-all apply
```

## See also

- [`../README.md`](../README.md) — top-level pattern, shared config, lint.
