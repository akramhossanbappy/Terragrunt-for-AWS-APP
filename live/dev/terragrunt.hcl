# Root Terragrunt config for the dev environment.
#
# Terminal config (no include blocks) — Terragrunt auto-loads parent
# terragrunt.hcl files when running a child unit, so live/terragrunt.hcl
# and dev/ap-southeast-1/terragrunt.hcl (the region root) are picked up
# automatically by units under dev/.
#
# Defines dev-specific locals: the S3 state bucket name, environment/tier
# labels, and per-env overrides merged onto the shared common_defaults.

locals {
  project                = "tfdemo"
  environment            = "dev"
  tier                   = "dev"
  s3_state_bucket_region = "ap-southeast-1"
  state_bucket           = "REPLACE_WITH_DEV_STATE_BUCKET"

  settings = merge(
    local.common_defaults,
    {
      waf_regional_enabled   = false
      waf_cloudfront_enabled = false
      waf_count_mode_only    = true
    }
  )
}
