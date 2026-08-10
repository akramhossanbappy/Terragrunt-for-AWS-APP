# Root Terragrunt config for the production environment.
#
# Terminal config (no include blocks) — Terragrunt auto-loads parent
# terragrunt.hcl files when running a child unit, so live/terragrunt.hcl
# and the region roots are picked up automatically by units under
# production/. Each unit gets its own state file at
# tfdemo-fifa-terraform-state-bucket-production/<region>/<unit>/terraform.tfstate
# — a deliberate split from the old monolithic root state file.

locals {
  project                = "tfdemo"
  environment            = "prod"
  tier                   = "production"
  s3_state_bucket_region = "ap-southeast-1"
  state_bucket           = "tfdemo-fifa-terraform-state-bucket-production"

  settings = merge(
    local.common_defaults,
    {
      waf_count_mode_only = true
    }
  )
}
