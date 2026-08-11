locals {
  project     = "tfdemo"
  environment = "staging"
  tier        = "staging"

  # Terraform state
  state_bucket           = "REPLACE_WITH_DEV_STATE_BUCKET"
  s3_state_bucket_region = "ap-southeast-1"

  # Development environment overrides
  environment_overrides = {
    waf_regional_enabled   = false
    waf_cloudfront_enabled = false
    waf_count_mode_only    = true

    monitoring_enabled   = true
    data_enabled         = true
    delivery_enabled     = true
    static_sites_enabled = true
    cluster_enabled      = true

    enable_webhook_notifications = true
  }

  environment_tags = {
    Environment = "staging"
    Tier        = "staging"
  }
}