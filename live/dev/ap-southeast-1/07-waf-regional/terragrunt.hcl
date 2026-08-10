include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../modules//waf-regional"
}

inputs = {
  project     = "tfdemo"
  environment = "dev"
  tier        = "dev"
  aws_region  = "ap-southeast-1"

  waf_alb_arn        = "arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/my-load-balancer/50dc6c495c0c9188"
  monitoring_alb_arn = "arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/my-load-balancer/50dc6c495c0c9188"

  waf_alb_rate_limit                        = 700000
  waf_alb_evaluation_window_sec             = 60
  waf_alb_enable_rate_limit_custom_response = true

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

  monitoring_waf_alb_name      = "tfdemo-waf-alb-dev"
  monitoring_waf_alb_log_group = "aws-waf-logs-tfdemo-alb-dev"

  gchat_webhook_url = "REPLACE_WITH_DEV_GCHAT_WEBHOOK_URL"
}
