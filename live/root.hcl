# Shared Terragrunt config for all live environments.
#
# Single source of truth for the backend (S3 with native locking) and the
# shared locals (common_defaults, service_settings) every environment root
# inherits via `include "live" { path = find_in_parent_folders() }`.
#
# Why a single file: Terragrunt's `find_in_parent_folders()` walks up from
# the current `terragrunt.hcl` and returns the FIRST matching file. Earlier
# this file lived next to `common.hcl` and `settings.hcl` siblings at this
# level, with each env root including all three via `find_in_parent_folders("name.hcl")`.
# That broke as soon as region roots and unit roots called `find_in_parent_folders()`
# (no arg) to find their env root — the chain region -> env -> live/*.hcl
# triggered Terragrunt's "only one level of includes is allowed" error.
# Collapsing everything into a single `live/terragrunt.hcl` keeps the include
# chain at one level per hop: env -> live, region -> env, unit -> region.

# ---------------------------------------------------------------------------
# Backend: S3 with native locking (one state file per Terragrunt unit,
# keyed off path_relative_to_include()).
# ---------------------------------------------------------------------------

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = local.state_bucket
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.s3_state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

# ---------------------------------------------------------------------------
# Shared locals.
#
# These are merged with environment-specific overrides inside each
# environment root's own terragrunt.hcl. The `service_settings` block
# references `local.settings.*`, `local.environment`, and `local.tier`,
# which are defined by the including environment root and propagated up
# the include chain.
# ---------------------------------------------------------------------------

locals {
  common_defaults = {
    # Global feature toggles
    waf_regional_enabled   = true
    waf_cloudfront_enabled = true
    waf_count_mode_only    = true
    monitoring_enabled     = true
    data_enabled           = true
    delivery_enabled       = true
    static_sites_enabled   = true
    cluster_enabled        = true

    # Common tagging values
    default_tags = {
      Project   = "singleapp"
      ManagedBy = "terragrunt"
      CreatedBy = "terraform"
    }

    # Default notification behavior
    enable_webhook_notifications = true
  }

  service_settings = {
    deploy_waf_regional          = local.settings.waf_regional_enabled
    deploy_waf_cloudfront        = local.settings.waf_cloudfront_enabled
    deploy_monitoring            = local.settings.monitoring_enabled
    deploy_data                  = local.settings.data_enabled
    deploy_delivery              = local.settings.delivery_enabled
    deploy_static_sites          = local.settings.static_sites_enabled
    deploy_cluster               = local.settings.cluster_enabled
    waf_count_mode_only          = local.settings.waf_count_mode_only
    enable_webhook_notifications = local.settings.enable_webhook_notifications
    tags = merge(local.settings.default_tags, {
      Environment = local.environment
      Tier        = local.tier
    })
  }
}
