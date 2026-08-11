include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_config = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )

  region_config = read_terragrunt_config(
    find_in_parent_folders("region.hcl")
  )
}

terraform {
  source = "../../../../modules//waf-regional"
}

inputs = {
  # Common environment values
  project     = local.env_config.locals.project
  environment = local.env_config.locals.environment
  tier        = local.env_config.locals.tier

  # Region
  aws_region = local.region_config.locals.aws_region

  # ALB associations
  waf_alb_arn        = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:loadbalancer/app/my-load-balancer/50dc6c495c0c9188"
  monitoring_alb_arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:loadbalancer/app/my-load-balancer/50dc6c495c0c9188"

  # Rate limiting
  waf_alb_rate_limit                        = 700000
  waf_alb_evaluation_window_sec             = 60
  waf_alb_enable_rate_limit_custom_response = true

  # IP controls
  waf_blocked_ips   = []
  waf_allowed_ips   = []
  waf_blocked_ipv6s = []
  waf_allowed_ipv6s = []

  # WAF mode
  waf_count_mode_only = true

  # AWS managed rules
  waf_enable_ip_reputation_list               = true
  waf_enable_common_rule_set                  = true
  waf_common_rule_body_size_override_to_count = true
  waf_enable_known_bad_inputs                 = true
  waf_enable_sqli_rule_set                    = true
  waf_enable_linux_rule_set                   = true
  waf_enable_php_rule_set                     = false

  # Logging
  waf_enable_logging     = true
  waf_log_retention_days = 30

  # Monitoring
  monitoring_waf_alb_name      = "tfdemo-waf-alb-dev"
  monitoring_waf_alb_log_group = "aws-waf-logs-tfdemo-alb-dev"

  # Notification
  gchat_webhook_url = "REPLACE_WITH_DEV_GCHAT_WEBHOOK_URL"
}