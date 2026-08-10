# Root Terragrunt config for the staging environment.
#
# Terminal config (no include blocks) — Terragrunt auto-loads parent
# terragrunt.hcl files when running a child unit, so live/terragrunt.hcl
# and the region roots are picked up automatically by units under staging/.
#
# Defines staging-specific locals: the S3 state bucket name,
# environment/tier labels, and per-env overrides merged onto the shared
# common_defaults.

locals {
  project                = "tfdemo"
  environment            = "staging"
  tier                   = "staging"
  s3_state_bucket_region = "ap-southeast-1"
  state_bucket           = "REPLACE_WITH_STAGING_STATE_BUCKET"

  settings = merge(
    local.common_defaults,
    {
      waf_count_mode_only = true
    }
  )
}
