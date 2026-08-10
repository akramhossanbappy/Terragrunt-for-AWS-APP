# Terragrunt live environments

This directory holds the four AWS environments managed by Terragrunt:
**dev**, **staging**, **preprod**, **production**. Each one follows the same
nested layout:

```
projects/live/<environment>/<region>/<service-unit>/terragrunt.hcl
```

with one `terragrunt.hcl` per directory. Terragrunt walks the directory tree
and auto-loads every ancestor `terragrunt.hcl` it finds, merging them into
the unit's effective configuration.

---

## Environments at a glance

| Env       | State populated? | Region dirs        | Bucket (must exist in AWS)                                  |
|-----------|------------------|--------------------|-------------------------------------------------------------|
| dev       | yes              | ap-southeast-1, us-east-1 (8 units) | `REPLACE_WITH_DEV_STATE_BUCKET` (placeholder — see below)  |
| staging   | placeholder      | ap-southeast-1, us-east-1 (no units) | `REPLACE_WITH_STAGING_STATE_BUCKET` (placeholder — see below) |
| preprod   | placeholder      | ap-southeast-1, us-east-1 (no units) | `REPLACE_WITH_PREPROD_STATE_BUCKET` (placeholder — see below) |
| production| yes              | ap-southeast-1, us-east-1 (8 units) | `singleapp-fifa-terraform-state-bucket-production`         |

Production is the active stack. dev mirrors production with waf toggles off
and a placeholder state bucket. staging and preprod are skeleton trees —
they have env roots and region roots but no service-unit subdirectories.

Per-environment detail is in each env's own `README.md`:

- [`dev/README.md`](dev/README.md)
- [`staging/README.md`](staging/README.md)
- [`preprod/README.md`](preprod/README.md)
- [`production/README.md`](production/README.md)

---

## Shared configuration pattern

There is one shared Terragrunt config at this level:

- **`terragrunt.hcl`** — `remote_state` block (S3 with native locking) plus
  two shared locals: `common_defaults` (feature toggles, default tags,
  notification flag) and `service_settings` (the per-service deploy flags
  every module consults).

Environment roots (`<env>/terragrunt.hcl`) and region roots
(`<env>/<region>/terragrunt.hcl`) are **terminal configs** — they have NO
`include` blocks. Each one only defines its own `locals` (and a `generate
"provider"` block at the region level). Terragrunt auto-loads them as
ancestors when a unit runs, so the merged config picks up:

- The env root's `state_bucket`, `environment`, `tier`, and `settings`.
- The region root's `region` / `aws_region` and generated `provider.tf`.
- The live root's backend config and shared locals.

This flat auto-load pattern is required because Terragrunt forbids
chained `include` blocks — *You can have as many `include` blocks as you
want, but you cannot chain them together* (`./terragrunt.hcl includes
../terragrunt.hcl, which itself includes ../terragrunt.hcl`).

---

## Running Terragrunt

From any environment root (substitute the env name you want):

```bash
cd projects/live/<env>
terragrunt run-all init        # initializes every unit in the env
terragrunt run-all validate    # config + module-graph check
terragrunt run-all plan        # requires AWS credentials
terragrunt run-all apply       # requires AWS credentials + approval
```

To work on a single unit:

```bash
cd projects/live/<env>/<region>/<unit>
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

Cross-unit `dependency` blocks resolve automatically — `terragrunt plan` in
a unit that depends on another will use that other unit's real outputs if
it's been applied; otherwise the dependency's `mock_outputs` fallback is
used (already configured).

---

## Pre-flight checklist before `terragrunt init`

For `dev`, `staging`, and `preprod` only — production already has its real
bucket wired up:

1. Replace `state_bucket = "REPLACE_WITH_<ENV>_STATE_BUCKET"` in
   `<env>/terragrunt.hcl` with the real S3 bucket name for that
   environment. The bucket must exist, be in the same
   `s3_state_bucket_region` (currently `ap-southeast-1` everywhere), and
   have native S3 locking enabled.
2. Confirm AWS credentials are available in the environment where you're
   running Terragrunt (`aws sts get-caller-identity` should succeed).
3. Confirm the AWS provider versions installed locally match the pins in
   the region roots (`hashicorp/aws 5.94.1`, `hashicorp/tls 4.0.6`,
   Terraform `>= 1.12.0`).

---

## Why no chained `include` blocks

The earlier version of this directory had three shared files at the live
root (`root.hcl`, `common.hcl`, `settings.hcl`) and four env roots that
included all three via `find_in_parent_folders("name.hcl")`. Region roots
called `find_in_parent_folders()` (no arg), which found the env root, so
the chain became `unit → region → env → live/*.hcl`. Terragrunt errors out:

```
./terragrunt.hcl includes ../terragrunt.hcl, which itself includes
../terragrunt.hcl. Only one level of includes is allowed.
```

The fix was to collapse the three shared files into one
`live/terragrunt.hcl`, drop the `include` blocks from env and region roots,
and rely on Terragrunt's directory-tree auto-loading to assemble the merged
config. The configuration layering is preserved (live root → env root →
region root → unit), but with zero include chains.

---

## Linting

```bash
# Format plain Terraform under projects/modules
terraform fmt -recursive projects/modules

# Format Terragrunt HCL under projects/live
terragrunt hclfmt projects/live
```

---

## Out of scope (known issues)

- `modules/vpc/variable.tf` declares `cidr_block-nat_gw` and
  `cidr_block-internet_gw` but `modules/vpc/main.tf` never references them
  (route tables hardcode `0.0.0.0/0`). Either remove the variables or
  wire them up — separate cleanup.
- The identical `aws = 5.94.1` / `tls = 4.0.6` provider pins repeated in
  every region root could be DRYed into `live/terragrunt.hcl` via a single
  `generate "provider"`, but they currently work — not a blocker.
