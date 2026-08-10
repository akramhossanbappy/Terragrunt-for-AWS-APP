include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../modules/waf-cloudfront"
}

inputs = {
  project     = "tfdemo"
  environment = "prod"
  tier        = "production"
  aws_region  = "us-east-1"

  waf_cf_rate_limit = 2000

  # Shared with the waf-regional unit's inputs (same values in the old root
  # main.tf's production.tfvars, now duplicated since these are independent
  # Terragrunt units/state files).
  waf_blocked_ips   = []
  waf_allowed_ips   = []
  waf_blocked_ipv6s = []
  waf_allowed_ipv6s = []

  waf_count_mode_only = true

  waf_enable_ip_reputation_list               = true
  waf_enable_common_rule_set                  = true
  waf_common_rule_body_size_override_to_count = true
  waf_enable_known_bad_inputs                 = true
  waf_enable_sqli_rule_set                    = true
  waf_enable_linux_rule_set                   = true
  waf_enable_php_rule_set                     = false

  waf_enable_logging     = true
  waf_log_retention_days = 30

  monitoring_waf_cloudfront_name      = "tfdemo-waf-cloudfront-prod"
  monitoring_waf_cloudfront_log_group = "aws-waf-logs-tfdemo-cloudfront-prod"

  gchat_webhook_url = "https://chat.googleapis.com/v1/spaces/AAAA2phmPyI/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=BH4i0Snua9FlE3nlSarqz06COVpaJXfocLfg6n0oYPI"
}
