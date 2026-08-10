include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../modules/waf-regional"
}

inputs = {
  project     = "singleapp"
  environment = "prod"
  tier        = "production"
  aws_region  = "ap-southeast-1"

  # ALB to protect — the API ALB created by EKS ingress (not managed by any
  # Terraform module in this repo). Two variables holding the same ARN,
  # preserved from the old root main.tf's waf_alb_arn / monitoring_alb_arn.
  waf_alb_arn        = "arn:aws:elasticloadbalancing:ap-southeast-1:487542879553:loadbalancer/app/singleapp-fifa-api-alb-prod/43e0b822acf62178"
  monitoring_alb_arn = "arn:aws:elasticloadbalancing:ap-southeast-1:487542879553:loadbalancer/app/singleapp-fifa-api-alb-prod/43e0b822acf62178"

  waf_alb_rate_limit                        = 700000
  waf_alb_evaluation_window_sec             = 60
  waf_alb_enable_rate_limit_custom_response = true

  waf_blocked_ips   = []
  waf_allowed_ips   = []
  waf_blocked_ipv6s = []
  waf_allowed_ipv6s = []

  # Count/observe mode — true = log what would be blocked but do not block.
  # Keep true for 48–72 h after first apply, then flip to false to enforce.
  waf_count_mode_only = true

  waf_enable_ip_reputation_list               = true
  waf_enable_common_rule_set                  = true
  waf_common_rule_body_size_override_to_count = true # engagement service may POST large JSON payloads
  waf_enable_known_bad_inputs                 = true
  waf_enable_sqli_rule_set                    = true
  waf_enable_linux_rule_set                   = true
  waf_enable_php_rule_set                     = false # not applicable — Node.js/Go backend

  waf_enable_logging     = true
  waf_log_retention_days = 30

  monitoring_waf_alb_name      = "singleapp-waf-alb-prod"
  monitoring_waf_alb_log_group = "aws-waf-logs-singleapp-alb-prod"

  gchat_webhook_url = "https://chat.googleapis.com/v1/spaces/AAAA2phmPyI/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=BH4i0Snua9FlE3nlSarqz06COVpaJXfocLfg6n0oYPI"
}
