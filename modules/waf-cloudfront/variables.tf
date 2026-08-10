# Common
variable "project" {}
variable "environment" {}
variable "tier" {}
variable "aws_region" {
  description = "Must be us-east-1 — enforced by this unit's terragrunt.hcl generate \"provider\" block."
}

# Rate limiting
variable "waf_cf_rate_limit" {
  type    = number
  default = 2000
}

# IP allow/block lists — shared values with the waf-regional unit (same
# source config in the old root main.tf, now duplicated across both units'
# tfvars since they are independent Terragrunt units).
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

# WAF CloudFront monitoring
variable "monitoring_waf_cloudfront_name" {
  type = string
}
variable "monitoring_waf_cloudfront_log_group" {
  type    = string
  default = ""
}
variable "gchat_webhook_url" {
  description = "Google Chat webhook URL for WAF CloudFront CloudWatch alarm notifications."
  type        = string
  sensitive   = true
}
