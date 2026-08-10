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

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "waf_cloudfront" {
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
          title  = "WAF CloudFront — Blocked vs Allowed Requests"
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
          title  = "WAF CloudFront — Per-Rule Blocked Requests"
          region = var.aws_region
          metrics = [
            for k, v in local.waf_rule_metrics : ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_acl_name, "Region", var.aws_region, "Rule", v, { label = k }]
          ]
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
        }
      }
    ]
  })
}
