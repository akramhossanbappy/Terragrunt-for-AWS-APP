locals {
  common_defaults = {
    # Global feature toggles
    waf_regional_enabled   = true
    waf_cloudfront_enabled = true
    waf_count_mode_only    = true

    monitoring_enabled   = true
    data_enabled         = true
    delivery_enabled     = true
    static_sites_enabled = true
    cluster_enabled      = true

    # Notification
    enable_webhook_notifications = true

    # Common tags
    default_tags = {
      Project   = "tfdemo"
      ManagedBy = "terragrunt"
      CreatedBy = "terraform"
    }
  }
}