locals {
  name_prefix = "${var.project}-waf-${var.name_suffix}-${var.environment}"

  common_tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
    Region      = var.aws_region
  }

  # Managed rule override: "none" = enforce, "count" = observe only
  managed_override_action = var.count_mode_only ? "count" : "none"
}

data "aws_caller_identity" "current" {}

# ── IPv4 IP Sets ──────────────────────────────────────────────────────────────

resource "aws_wafv2_ip_set" "blocked_ipv4" {
  count = length(var.blocked_ips) > 0 ? 1 : 0

  name               = "${local.name_prefix}-blocked-ipv4"
  description        = "Explicitly blocked IPv4 ranges"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.blocked_ips

  tags = local.common_tags
}

resource "aws_wafv2_ip_set" "allowed_ipv4" {
  count = length(var.allowed_ips) > 0 ? 1 : 0

  name               = "${local.name_prefix}-allowed-ipv4"
  description        = "Explicitly allowed IPv4 ranges (bypass all other rules)"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.allowed_ips

  tags = local.common_tags
}

# ── IPv6 IP Sets ──────────────────────────────────────────────────────────────

resource "aws_wafv2_ip_set" "blocked_ipv6" {
  count = length(var.blocked_ipv6s) > 0 ? 1 : 0

  name               = "${local.name_prefix}-blocked-ipv6"
  description        = "Explicitly blocked IPv6 ranges"
  scope              = var.scope
  ip_address_version = "IPV6"
  addresses          = var.blocked_ipv6s

  tags = local.common_tags
}

resource "aws_wafv2_ip_set" "allowed_ipv6" {
  count = length(var.allowed_ipv6s) > 0 ? 1 : 0

  name               = "${local.name_prefix}-allowed-ipv6"
  description        = "Explicitly allowed IPv6 ranges (bypass all other rules)"
  scope              = var.scope
  ip_address_version = "IPV6"
  addresses          = var.allowed_ipv6s

  tags = local.common_tags
}

# ── WAF WebACL ───────────────────────────────────────────────────────────────

resource "aws_wafv2_web_acl" "this" {
  name        = local.name_prefix
  description = "WAF WebACL for ${var.name_suffix} - ${var.project} ${var.environment}"
  scope       = var.scope

  dynamic "custom_response_body" {
    for_each = var.enable_rate_limit_custom_response ? [1] : []
    content {
      key          = "WAF_Response"
      content_type = "APPLICATION_JSON"
      content = jsonencode({
        CustomResponseBodyKey = "too_many_requests_body"
        ResponseCode          = 429
        ResponseHeaders = [
          {
            Name  = "Retry-After"
            Value = "60"
          }
        ]
      })
    }
  }

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # ── Priority 1: IPv4 Allowlist — bypass all other rules ─────────────────
  dynamic "rule" {
    for_each = length(var.allowed_ips) > 0 ? [1] : []
    content {
      name     = "AllowListedIPv4"
      priority = 1

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed_ipv4[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-allowed-ipv4"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 2: IPv6 Allowlist — bypass all other rules ─────────────────
  dynamic "rule" {
    for_each = length(var.allowed_ipv6s) > 0 ? [1] : []
    content {
      name     = "AllowListedIPv6"
      priority = 2

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed_ipv6[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-allowed-ipv6"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 3: IPv4 Blocklist ───────────────────────────────────────────
  dynamic "rule" {
    for_each = length(var.blocked_ips) > 0 ? [1] : []
    content {
      name     = "BlockListedIPv4"
      priority = 3

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blocked_ipv4[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-blocked-ipv4"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 4: IPv6 Blocklist ───────────────────────────────────────────
  dynamic "rule" {
    for_each = length(var.blocked_ipv6s) > 0 ? [1] : []
    content {
      name     = "BlockListedIPv6"
      priority = 4

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blocked_ipv6[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-blocked-ipv6"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 5: Rate limiting ─────────────────────────────────────────────
  # Runs after allow-lists so trusted IPs are never rate-limited.
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      name     = "RateLimitRule"
      priority = 5

      action {
        dynamic "block" {
          for_each = var.rate_limit_action == "block" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = var.rate_limit_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        rate_based_statement {
          limit                 = var.rate_limit
          aggregate_key_type    = "IP"
          evaluation_window_sec = var.rate_limit_evaluation_window_sec
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-rate-limit"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 10: AWS IP Reputation List ──────────────────────────────────
  dynamic "rule" {
    for_each = var.enable_ip_reputation_list ? [1] : []
    content {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 10

      override_action {
        dynamic "none" {
          for_each = local.managed_override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = local.managed_override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = var.override_ip_reputation_ddos_to_block ? [1] : []
            content {
              name = "AWSManagedIPDDoSList"
              action_to_use {
                block {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-ip-reputation"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 20: Common Rule Set (OWASP Top 10) ───────────────────────────
  # SizeRestrictions_BODY blocks payloads > 8 KB.
  # Set common_rule_body_size_override_to_count = true if your API sends larger bodies.
  dynamic "rule" {
    for_each = var.enable_common_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 20

      override_action {
        dynamic "none" {
          for_each = local.managed_override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = local.managed_override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = var.common_rule_body_size_override_to_count && local.managed_override_action == "none" ? [1] : []
            content {
              name = "SizeRestrictions_BODY"
              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-common-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 30: Known Bad Inputs ─────────────────────────────────────────
  dynamic "rule" {
    for_each = var.enable_known_bad_inputs ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 30

      override_action {
        dynamic "none" {
          for_each = local.managed_override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = local.managed_override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-known-bad-inputs"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 40: SQL Injection ────────────────────────────────────────────
  dynamic "rule" {
    for_each = var.enable_sqli_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 40

      override_action {
        dynamic "none" {
          for_each = local.managed_override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = local.managed_override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesSQLiRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-sqli"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 50: Linux Rule Set ───────────────────────────────────────────
  dynamic "rule" {
    for_each = var.enable_linux_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesLinuxRuleSet"
      priority = 50

      override_action {
        dynamic "none" {
          for_each = local.managed_override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = local.managed_override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesLinuxRuleSet"
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = var.override_linux_lfi_to_block ? ["LFI_URIPATH", "LFI_QUERYSTRING", "LFI_HEADER"] : []
            content {
              name = rule_action_override.value
              action_to_use {
                block {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-linux"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Priority 60: PHP Rule Set ─────────────────────────────────────────────
  dynamic "rule" {
    for_each = var.enable_php_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesPHPRuleSet"
      priority = 60

      override_action {
        dynamic "none" {
          for_each = local.managed_override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = local.managed_override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesPHPRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-php"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.name_prefix
    sampled_requests_enabled   = true
  }

  tags = local.common_tags

  # The AWS provider computes custom_response_body as a set and its internal
  # hash diverges from the state hash on every plan even when content is
  # identical. Ignore changes to suppress the perpetual diff.
  lifecycle {
    ignore_changes = [custom_response_body]
  }
}

# ── CloudWatch Logging ────────────────────────────────────────────────────────
# Log group name MUST start with "aws-waf-logs-" (AWS hard requirement).
# The resource policy grants delivery.logs.amazonaws.com write access —
# without it, aws_wafv2_web_acl_logging_configuration will fail at apply.

resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_logging ? 1 : 0

  name              = "aws-waf-logs-${var.project}-${var.name_suffix}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_resource_policy" "waf_logging" {
  count = var.enable_logging ? 1 : 0

  policy_name = "${local.name_prefix}-log-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "${aws_cloudwatch_log_group.waf[0].arn}:*"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })

  depends_on = [aws_cloudwatch_log_group.waf]
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

  # Redact sensitive headers from logs
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  depends_on = [aws_cloudwatch_log_resource_policy.waf_logging]
}

# ── ALB Association (REGIONAL scope only) ────────────────────────────────────
# For CloudFront, set web_acl_id = module.waf_cloudfront.web_acl_arn directly
# on the aws_cloudfront_distribution resource — no association resource needed.

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.scope == "REGIONAL" && var.alb_arn != "" ? 1 : 0

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn

  depends_on = [aws_wafv2_web_acl.this]
}
