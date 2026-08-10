# Common
variable "project" {}
variable "environment" {}
variable "tier" {}
variable "aws_region" {}

# ALB ARN to associate with the WAF WebACL, and to monitor.
# Two separate variables because root main.tf historically kept them distinct
# (waf_alb_arn for the association, monitoring_alb_arn for the alarms) even
# though they hold the same value in practice — preserved as-is.
variable "waf_alb_arn" {
  type    = string
  default = ""
}
variable "monitoring_alb_arn" {
  type = string
}

# Rate limiting
variable "waf_alb_rate_limit" {
  type    = number
  default = 2000
}
variable "waf_alb_evaluation_window_sec" {
  type    = number
  default = 300
}
variable "waf_alb_enable_rate_limit_custom_response" {
  type    = bool
  default = false
}

# IP allow/block lists
variable "waf_blocked_ips" {
  type    = list(string)
  default = []
}
variable "waf_allowed_ips" {
  type    = list(string)
  default = []
}
variable "waf_blocked_ipv6s" {
  type    = list(string)
  default = []
}
variable "waf_allowed_ipv6s" {
  type    = list(string)
  default = []
}

# Count/observe mode
variable "waf_count_mode_only" {
  type    = bool
  default = true
}

# Managed rule group toggles
variable "waf_enable_ip_reputation_list" {
  type    = bool
  default = true
}
variable "waf_enable_common_rule_set" {
  type    = bool
  default = true
}
variable "waf_common_rule_body_size_override_to_count" {
  type    = bool
  default = false
}
variable "waf_enable_known_bad_inputs" {
  type    = bool
  default = true
}
variable "waf_enable_sqli_rule_set" {
  type    = bool
  default = true
}
variable "waf_enable_linux_rule_set" {
  type    = bool
  default = false
}
variable "waf_enable_php_rule_set" {
  type    = bool
  default = false
}

# Logging
variable "waf_enable_logging" {
  type    = bool
  default = true
}
variable "waf_log_retention_days" {
  type    = number
  default = 30
}

# WAF ALB monitoring
variable "monitoring_waf_alb_name" {
  type = string
}
variable "monitoring_waf_alb_log_group" {
  type    = string
  default = ""
}
variable "gchat_webhook_url" {
  description = "Google Chat webhook URL for WAF/ALB CloudWatch alarm notifications."
  type        = string
  sensitive   = true
}
