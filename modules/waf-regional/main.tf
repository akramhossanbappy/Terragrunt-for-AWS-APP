# WAF for ALB (REGIONAL scope — ap-southeast-1).
# Uses count_mode_only = true on first rollout (observe, do not block).
# Monitor CloudWatch WAF metrics for 48–72 h, then flip waf_count_mode_only
# to false in terraform.tfvars to enforce blocking.
module "waf-alb" {
  source      = "../waf"
  project     = var.project
  environment = var.environment
  tier        = var.tier
  aws_region  = var.aws_region

  scope       = "REGIONAL"
  name_suffix = "alb"

  default_action = "allow"

  enable_rate_limiting              = true
  rate_limit                        = var.waf_alb_rate_limit
  rate_limit_evaluation_window_sec  = var.waf_alb_evaluation_window_sec
  enable_rate_limit_custom_response = var.waf_alb_enable_rate_limit_custom_response
  rate_limit_action                 = "block"

  allowed_ips   = var.waf_allowed_ips
  allowed_ipv6s = var.waf_allowed_ipv6s
  blocked_ips   = var.waf_blocked_ips
  blocked_ipv6s = var.waf_blocked_ipv6s

  count_mode_only                         = var.waf_count_mode_only
  enable_ip_reputation_list               = var.waf_enable_ip_reputation_list
  override_ip_reputation_ddos_to_block    = true
  enable_common_rule_set                  = var.waf_enable_common_rule_set
  common_rule_body_size_override_to_count = var.waf_common_rule_body_size_override_to_count
  enable_known_bad_inputs                 = var.waf_enable_known_bad_inputs
  enable_sqli_rule_set                    = var.waf_enable_sqli_rule_set
  enable_linux_rule_set                   = var.waf_enable_linux_rule_set
  override_linux_lfi_to_block             = true
  enable_php_rule_set                     = var.waf_enable_php_rule_set

  alb_arn = var.waf_alb_arn

  enable_logging     = var.waf_enable_logging
  log_retention_days = var.waf_log_retention_days
}

# WAF ALB monitoring — WAF alarms + ALB alarms.
module "waf-alb-monitoring" {
  source      = "../cloudwatch-monitoring/waf-alb-monitoring"
  project     = var.project
  environment = var.environment
  tier        = var.tier
  aws_region  = var.aws_region

  waf_acl_name       = var.monitoring_waf_alb_name
  waf_log_group_name = var.monitoring_waf_alb_log_group
  waf_enable_logging = var.waf_enable_logging

  # rate_limit excluded — rule is in count mode, tracked via waf_ratelimit_count alarm (CountedRequests)
  # php excluded — waf_enable_php_rule_set = false in terraform.tfvars
  waf_enabled_rule_keys = ["ip_reputation", "common_rules", "bad_inputs", "sqli", "linux"]

  alb_arn           = var.monitoring_alb_arn
  gchat_webhook_url = var.gchat_webhook_url
}
