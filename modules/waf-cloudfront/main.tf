# WAF for CloudFront (CLOUDFRONT scope — must be deployed in us-east-1).
# This unit's terragrunt.hcl generates a us-east-1 provider block, so no
# provider alias is needed here (unlike the old single-root-module setup).
module "waf-cloudfront" {
  source      = "../waf"
  project     = var.project
  environment = var.environment
  tier        = var.tier
  aws_region  = var.aws_region

  scope       = "CLOUDFRONT"
  name_suffix = "cloudfront"

  default_action       = "allow"
  enable_rate_limiting = true
  rate_limit           = var.waf_cf_rate_limit

  allowed_ips   = var.waf_allowed_ips
  allowed_ipv6s = var.waf_allowed_ipv6s
  blocked_ips   = var.waf_blocked_ips
  blocked_ipv6s = var.waf_blocked_ipv6s

  count_mode_only                         = var.waf_count_mode_only
  enable_ip_reputation_list               = var.waf_enable_ip_reputation_list
  enable_common_rule_set                  = var.waf_enable_common_rule_set
  common_rule_body_size_override_to_count = var.waf_common_rule_body_size_override_to_count
  enable_known_bad_inputs                 = var.waf_enable_known_bad_inputs
  enable_sqli_rule_set                    = var.waf_enable_sqli_rule_set
  enable_linux_rule_set                   = var.waf_enable_linux_rule_set
  enable_php_rule_set                     = var.waf_enable_php_rule_set

  alb_arn = "" # not used for CloudFront scope

  enable_logging     = var.waf_enable_logging
  log_retention_days = var.waf_log_retention_days
}

# WAF CloudFront monitoring — WAF alarms only.
module "waf-cloudfront-monitoring" {
  source      = "../cloudwatch-monitoring/waf-cloudfront-monitoring"
  project     = var.project
  environment = var.environment
  tier        = var.tier
  aws_region  = var.aws_region

  waf_acl_name       = var.monitoring_waf_cloudfront_name
  waf_log_group_name = var.monitoring_waf_cloudfront_log_group
  waf_enable_logging = var.waf_enable_logging

  # php excluded — waf_enable_php_rule_set = false in terraform.tfvars
  waf_enabled_rule_keys = ["rate_limit", "ip_reputation", "common_rules", "bad_inputs", "sqli", "linux"]

  gchat_webhook_url = var.gchat_webhook_url
}
