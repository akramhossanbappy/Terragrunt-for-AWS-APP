# Common
variable "project" {}
variable "environment" {}
variable "tier" {}
variable "aws_region" {}

# WAF CloudFront
variable "waf_acl_name" {
  description = "WAF WebACL name (CLOUDFRONT scope). Used as CloudWatch dimension and base for all resource names."
  type        = string
}

variable "waf_log_group_name" {
  description = "CloudWatch log group receiving WAF CloudFront logs. Required when waf_enable_logging = true."
  type        = string
  default     = ""
}

variable "waf_enable_logging" {
  description = "Create a log metric filter and log-based alarm from WAF CloudWatch Logs."
  type        = bool
  default     = true
}

variable "waf_enabled_rule_keys" {
  description = "Rule keys to create per-rule blocked-request alarms for. Omit disabled rules to avoid INSUFFICIENT_DATA noise."
  type        = list(string)
  default     = ["rate_limit", "ip_reputation", "common_rules", "bad_inputs", "sqli", "linux"]
}

variable "waf_rule_thresholds" {
  description = "Per-rule alarm thresholds (blocked requests per 5-min period)."
  type        = map(number)
  default = {
    rate_limit    = 5000
    ip_reputation = 100
    common_rules  = 50
    bad_inputs    = 20
    sqli          = 5
    linux         = 10
    php           = 20
  }
}

variable "waf_total_blocked_threshold" {
  description = "Alarm threshold for total WAF blocked requests (ALL rules) per 5-min period."
  type        = number
  default     = 500
}

variable "waf_block_rate_threshold_pct" {
  description = "Alarm threshold for WAF block rate as a percentage of total (blocked + allowed) requests."
  type        = number
  default     = 10
}

variable "waf_log_block_threshold" {
  description = "Alarm threshold for BLOCK events counted via CloudWatch Logs metric filter per 5-min period."
  type        = number
  default     = 200
}

# Notifications
variable "gchat_webhook_url" {
  description = "Google Chat webhook URL. Alarms are delivered via Lambda → POST to this URL."
  type        = string
  sensitive   = true
}
