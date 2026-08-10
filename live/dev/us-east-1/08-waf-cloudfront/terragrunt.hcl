include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../modules/waf-cloudfront"
}

inputs = {
  project     = "singleapp"
  environment = "dev"
  tier        = "dev"
  aws_region  = "us-east-1"

  waf_cf_rate_limit = 2000

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

  monitoring_waf_cloudfront_name      = "singleapp-waf-cloudfront-dev"
  monitoring_waf_cloudfront_log_group = "aws-waf-logs-singleapp-cloudfront-dev"

  gchat_webhook_url = "REPLACE_WITH_DEV_GCHAT_WEBHOOK_URL"
}
