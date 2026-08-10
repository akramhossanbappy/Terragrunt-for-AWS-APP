locals {
  common_tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }

  has_primaries = length(var.primary_cluster_ids) > 0
  has_replicas  = length(var.replica_cluster_ids) > 0

  # Metric math query ID lists.
  # CloudWatch alarms allow max 10 data queries per alarm; keep list lengths ≤ 9
  # to leave one slot for the aggregating expression.
  cpu_ids   = [for i, _ in var.primary_cluster_ids : "cpu${i}"]
  mem_ids   = [for i, _ in var.primary_cluster_ids : "mem${i}"]
  evict_ids = [for i, _ in var.primary_cluster_ids : "evict${i}"]
  conn_ids  = [for i, _ in var.primary_cluster_ids : "conn${i}"]
  lag_ids   = [for i, _ in var.replica_cluster_ids : "lag${i}"]
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
  name = "${var.replication_group_id}-gchat-role"

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
  function_name    = "${var.replication_group_id}-gchat"
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
  name = "${var.replication_group_id}-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.gchat_notifier.arn

  depends_on = [aws_lambda_permission.sns_invoke]
}

# ── ElastiCache Alarms ────────────────────────────────────────────────────────
# CPU/memory/evictions/connections alarms use primary_cluster_ids only (≤ 9 nodes).
# ReplicationLag alarm uses replica_cluster_ids only (≤ 9 nodes).
# This split is required because CloudWatch metric math alarms are limited to
# 10 data queries per alarm (9 metrics + 1 aggregating expression).

# MAX EngineCPUUtilization across primary nodes — Redis is single-threaded;
# high engine CPU signals saturation of the command-processing thread.
resource "aws_cloudwatch_metric_alarm" "cache_cpu_high" {
  count = local.has_primaries ? 1 : 0

  alarm_name          = "${var.replication_group_id}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = var.cpu_threshold
  alarm_description   = "Redis EngineCPUUtilization (MAX across primary nodes) > ${var.cpu_threshold}% for 15 min — single-threaded engine approaching saturation"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dynamic "metric_query" {
    for_each = var.primary_cluster_ids
    iterator = node
    content {
      id          = "cpu${node.key}"
      return_data = false
      metric {
        metric_name = "EngineCPUUtilization"
        namespace   = "AWS/ElastiCache"
        period      = 300
        stat        = "Maximum"
        dimensions  = { CacheClusterId = node.value }
      }
    }
  }

  metric_query {
    id          = "max_cpu"
    expression  = "MAX([${join(",", local.cpu_ids)}])"
    label       = "MaxEngineCPUUtilization"
    return_data = true
  }

  tags = local.common_tags
}

# MAX DatabaseMemoryUsagePercentage across primary nodes — tracks Redis used
# memory vs maxmemory. Sustained above 80% risks key evictions or OOM errors.
resource "aws_cloudwatch_metric_alarm" "cache_memory_high" {
  count = local.has_primaries ? 1 : 0

  alarm_name          = "${var.replication_group_id}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.memory_threshold_pct
  alarm_description   = "Redis DatabaseMemoryUsagePercentage (MAX across primary nodes) > ${var.memory_threshold_pct}% — risk of evictions or OOM"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dynamic "metric_query" {
    for_each = var.primary_cluster_ids
    iterator = node
    content {
      id          = "mem${node.key}"
      return_data = false
      metric {
        metric_name = "DatabaseMemoryUsagePercentage"
        namespace   = "AWS/ElastiCache"
        period      = 300
        stat        = "Maximum"
        dimensions  = { CacheClusterId = node.value }
      }
    }
  }

  metric_query {
    id          = "max_mem"
    expression  = "MAX([${join(",", local.mem_ids)}])"
    label       = "MaxMemoryUsagePct"
    return_data = true
  }

  tags = local.common_tags
}

# SUM Evictions across primary nodes — any sustained eviction means keys are
# being dropped under memory pressure and warrants immediate investigation.
resource "aws_cloudwatch_metric_alarm" "cache_evictions" {
  count = local.has_primaries ? 1 : 0

  alarm_name          = "${var.replication_group_id}-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.evictions_threshold
  alarm_description   = "Redis total Evictions (SUM across primary nodes) > ${var.evictions_threshold} per 5 min — cluster evicting keys due to memory pressure"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dynamic "metric_query" {
    for_each = var.primary_cluster_ids
    iterator = node
    content {
      id          = "evict${node.key}"
      return_data = false
      metric {
        metric_name = "Evictions"
        namespace   = "AWS/ElastiCache"
        period      = 300
        stat        = "Sum"
        dimensions  = { CacheClusterId = node.value }
      }
    }
  }

  metric_query {
    id          = "total_evictions"
    expression  = "SUM([${join(",", local.evict_ids)}])"
    label       = "TotalEvictions"
    return_data = true
  }

  tags = local.common_tags
}

# SUM CurrConnections across primary nodes — a spike usually means a connection
# leak or pool misconfiguration in the application layer.
resource "aws_cloudwatch_metric_alarm" "cache_connections_high" {
  count = local.has_primaries ? 1 : 0

  alarm_name          = "${var.replication_group_id}-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.connections_threshold
  alarm_description   = "Redis total CurrConnections (SUM across primary nodes) > ${var.connections_threshold} — connection spike detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dynamic "metric_query" {
    for_each = var.primary_cluster_ids
    iterator = node
    content {
      id          = "conn${node.key}"
      return_data = false
      metric {
        metric_name = "CurrConnections"
        namespace   = "AWS/ElastiCache"
        period      = 300
        stat        = "Average"
        dimensions  = { CacheClusterId = node.value }
      }
    }
  }

  metric_query {
    id          = "total_connections"
    expression  = "SUM([${join(",", local.conn_ids)}])"
    label       = "TotalConnections"
    return_data = true
  }

  tags = local.common_tags
}

# MAX ReplicationLag across replica nodes — fires if any replica falls behind
# the primary. Uses replica_cluster_ids so primary nodes (always 0 lag) don't
# mask a lagging replica in the MAX aggregation.
resource "aws_cloudwatch_metric_alarm" "cache_replication_lag" {
  count = local.has_replicas ? 1 : 0

  alarm_name          = "${var.replication_group_id}-replication-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.replication_lag_threshold_sec
  alarm_description   = "Redis ReplicationLag (MAX across replica nodes) > ${var.replication_lag_threshold_sec}s — replica falling behind primary; possible write pressure or network issue"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dynamic "metric_query" {
    for_each = var.replica_cluster_ids
    iterator = node
    content {
      id          = "lag${node.key}"
      return_data = false
      metric {
        metric_name = "ReplicationLag"
        namespace   = "AWS/ElastiCache"
        period      = 300
        stat        = "Maximum"
        dimensions  = { CacheClusterId = node.value }
      }
    }
  }

  metric_query {
    id          = "max_lag"
    expression  = "MAX([${join(",", local.lag_ids)}])"
    label       = "MaxReplicationLag"
    return_data = true
  }

  tags = local.common_tags
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "elasticache" {
  dashboard_name = "${var.replication_group_id}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Redis — Engine CPU per Primary Node (%)"
          region = var.aws_region
          metrics = [
            for id in var.primary_cluster_ids : ["AWS/ElastiCache", "EngineCPUUtilization", "CacheClusterId", id, { label = id }]
          ]
          period = 300
          stat   = "Maximum"
          view   = "timeSeries"
          yAxis  = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Redis — Memory Usage per Primary Node (%)"
          region = var.aws_region
          metrics = [
            for id in var.primary_cluster_ids : ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", id, { label = id }]
          ]
          period = 300
          stat   = "Maximum"
          view   = "timeSeries"
          yAxis  = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Redis — Evictions per Primary Node (Sum)"
          region = var.aws_region
          metrics = [
            for id in var.primary_cluster_ids : ["AWS/ElastiCache", "Evictions", "CacheClusterId", id, { label = id }]
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
          title  = "Redis — Current Connections per Primary Node"
          region = var.aws_region
          metrics = [
            for id in var.primary_cluster_ids : ["AWS/ElastiCache", "CurrConnections", "CacheClusterId", id, { label = id }]
          ]
          period = 300
          stat   = "Sum"
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
          title  = "Redis — Replication Lag per Replica Node (s)"
          region = var.aws_region
          metrics = [
            for id in var.replica_cluster_ids : ["AWS/ElastiCache", "ReplicationLag", "CacheClusterId", id, { label = id }]
          ]
          period = 300
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
          title  = "Redis — Cache Hits per Primary Node"
          region = var.aws_region
          metrics = [
            for id in var.primary_cluster_ids : ["AWS/ElastiCache", "CacheHits", "CacheClusterId", id, { label = id }]
          ]
          period = 300
          stat   = "Sum"
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
          title  = "Redis — Network Bytes In/Out (Primary Nodes)"
          region = var.aws_region
          metrics = concat(
            [for id in var.primary_cluster_ids : ["AWS/ElastiCache", "NetworkBytesIn", "CacheClusterId", id, { label = "In ${id}" }]],
            [for id in var.primary_cluster_ids : ["AWS/ElastiCache", "NetworkBytesOut", "CacheClusterId", id, { label = "Out ${id}" }]]
          )
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
        }
      }
    ]
  })
}
