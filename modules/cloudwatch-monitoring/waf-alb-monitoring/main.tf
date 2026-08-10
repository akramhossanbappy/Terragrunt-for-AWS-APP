locals {
  # Per-rule metric names — suffixes match visibility_config.metric_name in waf/main.tf
  all_rule_metrics = {
    rate_limit    = "${var.waf_acl_name}-rate-limit"
    ip_reputation = "${var.waf_acl_name}-ip-reputation"
    common_rules  = "${var.waf_acl_name}-common-rules"
    bad_inputs    = "${var.waf_acl_name}-known-bad-inputs"
    sqli          = "${var.waf_acl_name}-sqli"
    linux         = "${var.waf_acl_name}-linux"
    php           = "${var.waf_acl_name}-php"
  }

  waf_rule_metrics = {
    for k, v in local.all_rule_metrics : k => v
    if contains(var.waf_enabled_rule_keys, k)
  }

  # ALB ARN suffix for CloudWatch LoadBalancer dimension (e.g. app/name/id)
  alb_arn_suffix = regex("loadbalancer/(.*)", var.alb_arn)[0]

  common_tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

# ── Lambda (GChat notifier) ───────────────────────────────────────────────────

data "archive_file" "gchat_notifier" {
  type        = "zip"
  output_path = "${path.module}/gchat_notifier.zip"

  source {
    content  = file("${path.module}/lambda_gchat.py")
    filename = "index.py"
  }
}

resource "aws_iam_role" "gchat_notifier" {
  name = "${var.waf_acl_name}-gchat-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "gchat_notifier_basic" {
  role       = aws_iam_role.gchat_notifier.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "gchat_notifier" {
  function_name    = "${var.waf_acl_name}-gchat"
  role             = aws_iam_role.gchat_notifier.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.gchat_notifier.output_path
  source_code_hash = data.archive_file.gchat_notifier.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      GCHAT_WEBHOOK_URL = var.gchat_webhook_url
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gchat_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# ── SNS ──────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${var.waf_acl_name}-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.gchat_notifier.arn

  depends_on = [aws_lambda_permission.sns_invoke]
}

# ── WAF Alarms ───────────────────────────────────────────────────────────────

# Fires when total blocked requests across ALL rules spike — broad attack indicator.
resource "aws_cloudwatch_metric_alarm" "waf_total_blocked_spike" {
  alarm_name          = "${var.waf_acl_name}-total-blocked-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = var.waf_total_blocked_threshold
  alarm_description   = "WAF ${var.waf_acl_name} total blocked requests (ALL rules) > ${var.waf_total_blocked_threshold} in 5 min"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = var.waf_acl_name
    Region = var.aws_region
    Rule   = "ALL"
  }

  tags = local.common_tags
}

# Metric math alarm: fires when blocked % of total traffic exceeds threshold — signals a targeted attack.
resource "aws_cloudwatch_metric_alarm" "waf_block_rate_pct" {
  alarm_name          = "${var.waf_acl_name}-block-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.waf_block_rate_threshold_pct
  alarm_description   = "WAF ${var.waf_acl_name} block rate > ${var.waf_block_rate_threshold_pct}% of total requests for 10 min"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "blocked"
    return_data = false
    metric {
      metric_name = "BlockedRequests"
      namespace   = "AWS/WAFV2"
      period      = 300
      stat        = "Sum"
      dimensions = {
        WebACL = var.waf_acl_name
        Region = var.aws_region
        Rule   = "ALL"
      }
    }
  }

  metric_query {
    id          = "allowed"
    return_data = false
    metric {
      metric_name = "AllowedRequests"
      namespace   = "AWS/WAFV2"
      period      = 300
      stat        = "Sum"
      dimensions = {
        WebACL = var.waf_acl_name
        Region = var.aws_region
        Rule   = "ALL"
      }
    }
  }

  metric_query {
    id          = "block_rate"
    expression  = "IF((blocked+allowed)>0, 100*(blocked/(blocked+allowed)), 0)"
    label       = "BlockedRequestsPct"
    return_data = true
  }

  tags = local.common_tags
}

# One alarm per enabled rule (for_each). Tracks BlockedRequests per rule metric.
# rate_limit excluded — it is in count mode and tracked by waf_ratelimit_count below.
resource "aws_cloudwatch_metric_alarm" "waf_per_rule_blocked" {
  for_each = local.waf_rule_metrics

  alarm_name          = "${var.waf_acl_name}-rule-${each.key}-blocked"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = lookup(var.waf_rule_thresholds, each.key, 100)
  alarm_description   = "WAF rule '${each.key}' blocked requests above threshold (metric: ${each.value})"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = var.waf_acl_name
    Region = var.aws_region
    Rule   = each.value
  }

  tags = local.common_tags
}

# RateLimitRule is in count mode — tracks CountedRequests instead of BlockedRequests.
# Fires when requests breaching the rate threshold exceed 300 in a 5-min window.
resource "aws_cloudwatch_metric_alarm" "waf_ratelimit_count" {
  alarm_name          = "${var.waf_acl_name}-ratelimit-counted"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CountedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 300
  alarm_description   = "WAF RateLimitRule counted > 300 requests in 5 min — rate threshold being breached (rule in count mode)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = var.waf_acl_name
    Region = var.aws_region
    Rule   = "${var.waf_acl_name}-rate-limit"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "waf_block_events" {
  count = var.waf_enable_logging ? 1 : 0

  name           = "${var.waf_acl_name}-block-events"
  pattern        = "{ $.action = \"BLOCK\" }"
  log_group_name = var.waf_log_group_name

  metric_transformation {
    name          = "BlockEvents"
    namespace     = "Custom/WAF/${var.waf_acl_name}"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "waf_log_block_count" {
  count = var.waf_enable_logging ? 1 : 0

  alarm_name          = "${var.waf_acl_name}-log-block-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BlockEvents"
  namespace           = "Custom/WAF/${var.waf_acl_name}"
  period              = 300
  statistic           = "Sum"
  threshold           = var.waf_log_block_threshold
  alarm_description   = "WAF ${var.waf_acl_name} block events from logs > ${var.waf_log_block_threshold} in 5 min"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags

  depends_on = [aws_cloudwatch_log_metric_filter.waf_block_events]
}

# ── ALB Alarms ───────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project}-alb-${var.environment}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  alarm_description   = "ALB 5xx error count > ${var.alb_5xx_threshold} in 5 min"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_p99_latency" {
  alarm_name          = "${var.project}-alb-${var.environment}-p99-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  extended_statistic  = "p99"
  threshold           = var.alb_p99_latency_threshold_sec
  alarm_description   = "ALB P99 target response time > ${var.alb_p99_latency_threshold_sec}s for 15 min"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.project}-alb-${var.environment}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "ALB has one or more unhealthy targets"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
  }

  tags = local.common_tags
}

# LCU alarms use IF() to return 0 when no reservation is set, preventing false positives.
# Self-calibrates within one 5-min period after a reservation change in the ALB console.
resource "aws_cloudwatch_metric_alarm" "alb_lcu_above_50pct" {
  alarm_name          = "${var.project}-alb-${var.environment}-lcu-above-50pct"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 50
  alarm_description   = "ALB LCU utilization > 50% of reservation"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "consumed"
    return_data = false
    metric {
      metric_name = "ConsumedLCUs"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Average"
      dimensions  = { LoadBalancer = local.alb_arn_suffix }
    }
  }

  metric_query {
    id          = "reserved"
    return_data = false
    metric {
      metric_name = "ReservedLCUs"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Average"
      dimensions  = { LoadBalancer = local.alb_arn_suffix }
    }
  }

  metric_query {
    id          = "lcu_pct"
    expression  = "IF(reserved>0, 100*(consumed/reserved), 0)"
    label       = "LCUUtilizationPct"
    return_data = true
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_lcu_above_90pct" {
  alarm_name          = "${var.project}-alb-${var.environment}-lcu-above-90pct"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 90
  alarm_description   = "ALB LCU utilization > 90% of reservation — scale up or increase reservation immediately"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "consumed"
    return_data = false
    metric {
      metric_name = "ConsumedLCUs"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Average"
      dimensions  = { LoadBalancer = local.alb_arn_suffix }
    }
  }

  metric_query {
    id          = "reserved"
    return_data = false
    metric {
      metric_name = "ReservedLCUs"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Average"
      dimensions  = { LoadBalancer = local.alb_arn_suffix }
    }
  }

  metric_query {
    id          = "lcu_pct"
    expression  = "IF(reserved>0, 100*(consumed/reserved), 0)"
    label       = "LCUUtilizationPct"
    return_data = true
  }

  tags = local.common_tags
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "waf_alb" {
  dashboard_name = "${var.waf_acl_name}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "WAF — Blocked vs Allowed Requests"
          region = var.aws_region
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_acl_name, "Region", var.aws_region, "Rule", "ALL", { label = "Blocked", color = "#d62728" }],
            ["AWS/WAFV2", "AllowedRequests", "WebACL", var.waf_acl_name, "Region", var.aws_region, "Rule", "ALL", { label = "Allowed", color = "#2ca02c" }]
          ]
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "WAF — Per-Rule Blocked Requests"
          region = var.aws_region
          metrics = [
            for k, v in local.waf_rule_metrics : ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_acl_name, "Region", var.aws_region, "Rule", v, { label = k }]
          ]
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "ALB — 5xx Errors"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.alb_arn_suffix, { color = "#d62728" }]
          ]
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "ALB — P99 Target Response Time (s)"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_arn_suffix, { stat = "p99", label = "P99", color = "#ff7f0e" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "ALB — Unhealthy Target Count"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", local.alb_arn_suffix, { color = "#d62728" }]
          ]
          period = 60
          stat   = "Maximum"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "ALB — LCU Utilization vs Reservation"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "ConsumedLCUs", "LoadBalancer", local.alb_arn_suffix, { label = "Consumed LCUs" }],
            ["AWS/ApplicationELB", "ReservedLCUs", "LoadBalancer", local.alb_arn_suffix, { label = "Reserved LCUs", color = "#aec7e8" }]
          ]
          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "ALB — Request Count"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_arn_suffix, { label = "Total Requests" }]
          ]
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
        }
      }
    ]
  })
}
