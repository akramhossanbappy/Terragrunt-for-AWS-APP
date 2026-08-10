variable "project" {
  description = "Project name"
}

variable "environment" {
  description = "Environment name"
}

variable "tier" {
  description = "Tier name"
}

variable "aws_region" {
  description = "AWS region where this WAF is deployed (ap-southeast-1 for ALB, us-east-1 for CloudFront)."
}

# REGIONAL = ALB | CLOUDFRONT = CloudFront (must be deployed in us-east-1)
variable "scope" {
  description = "Scope of the WAF WebACL. Use REGIONAL for ALB and CLOUDFRONT for CloudFront distributions."
  type        = string
  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be either REGIONAL or CLOUDFRONT."
  }
}

# Used to distinguish multiple WAF ACLs (e.g. "alb", "cloudfront")
variable "name_suffix" {
  description = "Short suffix appended to resource names to distinguish multiple WAF instances, e.g. 'alb' or 'cloudfront'."
  type        = string
  default     = "alb"
}

# Default action when no rule matches: ALLOW or BLOCK
variable "default_action" {
  description = "Default action for requests that do not match any rule: allow or block."
  type        = string
  default     = "allow"
  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block."
  }
}

# ── Rate limiting ────────────────────────────────────────────────────────────
variable "enable_rate_limiting" {
  description = "Enable rate-based rule to block IPs exceeding the request threshold."
  type        = bool
  default     = true
}

variable "rate_limit" {
  description = "Maximum number of requests allowed from a single IP in the evaluation window before blocking. AWS minimum is 100."
  type        = number
  default     = 2000
  validation {
    condition     = var.rate_limit >= 100
    error_message = "rate_limit must be at least 100 (AWS WAFv2 minimum)."
  }
}

variable "rate_limit_evaluation_window_sec" {
  description = "Evaluation window in seconds for the rate-based rule. Valid values: 60, 120, 300, or 600."
  type        = number
  default     = 300
  validation {
    condition     = contains([60, 120, 300, 600], var.rate_limit_evaluation_window_sec)
    error_message = "rate_limit_evaluation_window_sec must be 60, 120, 300, or 600."
  }
}

variable "enable_rate_limit_custom_response" {
  description = "When true, returns a custom 429 JSON body (with Retry-After header) when the rate limit is exceeded."
  type        = bool
  default     = false
}

variable "rate_limit_action" {
  description = "Action to take when the rate limit is exceeded: block or count (observe only)."
  type        = string
  default     = "count"
  validation {
    condition     = contains(["block", "count"], var.rate_limit_action)
    error_message = "rate_limit_action must be block or count."
  }
}

# ── IPv4 IP sets ─────────────────────────────────────────────────────────────
variable "blocked_ips" {
  description = "List of IPv4 CIDR ranges to explicitly block (e.g. [\"1.2.3.4/32\"])."
  type        = list(string)
  default     = []
}

variable "allowed_ips" {
  description = "List of IPv4 CIDR ranges to explicitly allow, bypassing all other rules (e.g. office IPs)."
  type        = list(string)
  default     = []
}

# ── IPv6 IP sets ─────────────────────────────────────────────────────────────
variable "blocked_ipv6s" {
  description = "List of IPv6 CIDR ranges to explicitly block (e.g. [\"2001:db8::/32\"])."
  type        = list(string)
  default     = []
}

variable "allowed_ipv6s" {
  description = "List of IPv6 CIDR ranges to explicitly allow, bypassing all other rules."
  type        = list(string)
  default     = []
}

# ── AWS Managed Rule Groups ──────────────────────────────────────────────────
# Set count_mode_only = true during initial rollout to observe what would be
# blocked before switching to enforce. Flip to false once confirmed.
variable "count_mode_only" {
  description = "When true, all managed rule groups use COUNT override (observe, do not block). Set to true on initial rollout; flip to false after confirming no false positives."
  type        = bool
  default     = false
}

variable "enable_ip_reputation_list" {
  description = "Enable AWS managed rule group: AWSManagedRulesAmazonIpReputationList (blocks known malicious IPs)."
  type        = bool
  default     = true
}

variable "override_ip_reputation_ddos_to_block" {
  description = "Override the AWSManagedIPDDoSList rule inside AWSManagedRulesAmazonIpReputationList to BLOCK, regardless of count_mode_only."
  type        = bool
  default     = false
}

variable "enable_common_rule_set" {
  description = "Enable AWS managed rule group: AWSManagedRulesCommonRuleSet (OWASP Top 10 protections)."
  type        = bool
  default     = true
}

# The CommonRuleSet blocks request bodies > 8 KB (SizeRestrictions_BODY rule).
# REST/GraphQL APIs that accept large payloads should override this to COUNT.
variable "common_rule_body_size_override_to_count" {
  description = "Override the SizeRestrictions_BODY rule inside CommonRuleSet to COUNT mode. Enable if your API accepts request bodies larger than 8 KB to prevent false positives."
  type        = bool
  default     = false
}

variable "enable_known_bad_inputs" {
  description = "Enable AWS managed rule group: AWSManagedRulesKnownBadInputsRuleSet (blocks exploit-pattern payloads)."
  type        = bool
  default     = true
}

variable "enable_sqli_rule_set" {
  description = "Enable AWS managed rule group: AWSManagedRulesSQLiRuleSet (SQL injection protection)."
  type        = bool
  default     = true
}

variable "enable_linux_rule_set" {
  description = "Enable AWS managed rule group: AWSManagedRulesLinuxRuleSet (Linux-specific LFI/path traversal)."
  type        = bool
  default     = false
}

variable "override_linux_lfi_to_block" {
  description = "Override the LFI_URIPATH, LFI_QUERYSTRING, and LFI_HEADER rules inside AWSManagedRulesLinuxRuleSet to BLOCK, regardless of count_mode_only."
  type        = bool
  default     = false
}

variable "enable_php_rule_set" {
  description = "Enable AWS managed rule group: AWSManagedRulesPHPRuleSet (PHP injection protections)."
  type        = bool
  default     = false
}

# ── Logging ──────────────────────────────────────────────────────────────────
variable "enable_logging" {
  description = "Enable WAF logging to a CloudWatch log group (log group and resource policy are created by this module)."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention period in days for the WAF CloudWatch log group."
  type        = number
  default     = 30
}

# ── ALB Association (REGIONAL scope only) ────────────────────────────────────
variable "alb_arn" {
  description = "ARN of the ALB to associate with this WAF WebACL. Only used when scope = REGIONAL. Leave empty to skip association (e.g. when scope = CLOUDFRONT or associating externally)."
  type        = string
  default     = ""
}
