data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }

  # Both DomainName and ClientId are required dimensions for AWS/ES metrics.
  os_dimensions = {
    DomainName = var.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
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
  name = "${var.domain_name}-gchat-role"

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
  function_name    = "${var.domain_name}-gchat"
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
  name = "${var.domain_name}-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.gchat_notifier.arn

  depends_on = [aws_lambda_permission.sns_invoke]
}

# ── OpenSearch Alarms ─────────────────────────────────────────────────────────

# ClusterStatus.red = 1 means at least one primary shard is unassigned.
# This is CRITICAL — the cluster is partially offline and data may be inaccessible.
resource "aws_cloudwatch_metric_alarm" "os_cluster_red" {
  alarm_name          = "${var.domain_name}-cluster-red"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ClusterStatus.red"
  namespace           = "AWS/ES"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "OpenSearch ${var.domain_name} cluster status is RED — primary shard(s) unassigned, cluster is partially offline"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# ClusterStatus.yellow = 1 means replica shards are unassigned but all primaries are active.
# Data is available but fault tolerance is degraded.
resource "aws_cloudwatch_metric_alarm" "os_cluster_yellow" {
  alarm_name          = "${var.domain_name}-cluster-yellow"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "ClusterStatus.yellow"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "OpenSearch ${var.domain_name} cluster status is YELLOW — replica shard(s) unassigned, fault tolerance degraded"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# Data node CPUUtilization — sustained high CPU degrades search and indexing throughput.
resource "aws_cloudwatch_metric_alarm" "os_cpu_high" {
  alarm_name          = "${var.domain_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "OpenSearch ${var.domain_name} data node CPUUtilization > ${var.cpu_threshold}% for 15 min"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# FreeStorageSpace — total free disk across all data nodes in MB.
# Running low risks shard failures and write rejections.
resource "aws_cloudwatch_metric_alarm" "os_free_storage_low" {
  alarm_name          = "${var.domain_name}-free-storage-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Minimum"
  threshold           = var.free_storage_threshold_mb
  alarm_description   = "OpenSearch ${var.domain_name} FreeStorageSpace <= ${var.free_storage_threshold_mb} MB total — low disk space, risk of shard failures and write rejections"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# JVMMemoryPressure — sustained above 85% triggers aggressive GC that stalls
# all search and indexing requests.
resource "aws_cloudwatch_metric_alarm" "os_jvm_pressure" {
  alarm_name          = "${var.domain_name}-jvm-pressure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "JVMMemoryPressure"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.jvm_threshold
  alarm_description   = "OpenSearch ${var.domain_name} JVMMemoryPressure > ${var.jvm_threshold}% for 15 min — risk of GC pauses and request timeouts"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# KibanaHealthyNodes < 1 means the Kibana endpoint is unreachable.
resource "aws_cloudwatch_metric_alarm" "os_kibana_down" {
  alarm_name          = "${var.domain_name}-kibana-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "KibanaHealthyNodes"
  namespace           = "AWS/ES"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "OpenSearch ${var.domain_name} Kibana has no healthy nodes — Kibana endpoint is unreachable"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# MasterCPUUtilization — dedicated masters above 50% for sustained periods
# indicate they are overloaded with cluster state updates.
resource "aws_cloudwatch_metric_alarm" "os_master_cpu_high" {
  alarm_name          = "${var.domain_name}-master-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MasterCPUUtilization"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Average"
  threshold           = var.master_cpu_threshold
  alarm_description   = "OpenSearch ${var.domain_name} dedicated master CPUUtilization > ${var.master_cpu_threshold}% for 15 min — masters under pressure from cluster state updates"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# SearchLatency p99 — high latency is directly visible to end users querying Kibana
# or any application layer using OpenSearch.
resource "aws_cloudwatch_metric_alarm" "os_search_latency" {
  alarm_name          = "${var.domain_name}-search-latency-p99"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "SearchLatency"
  namespace           = "AWS/ES"
  period              = 300
  extended_statistic  = "p99"
  threshold           = var.search_latency_threshold_ms
  alarm_description   = "OpenSearch ${var.domain_name} SearchLatency p99 > ${var.search_latency_threshold_ms}ms for 15 min"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# IndexingLatency p99 — high indexing latency leads to ingestion backlog and
# can cascade into ThreadpoolWriteQueue buildup.
resource "aws_cloudwatch_metric_alarm" "os_indexing_latency" {
  alarm_name          = "${var.domain_name}-indexing-latency-p99"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "IndexingLatency"
  namespace           = "AWS/ES"
  period              = 300
  extended_statistic  = "p99"
  threshold           = var.indexing_latency_threshold_ms
  alarm_description   = "OpenSearch ${var.domain_name} IndexingLatency p99 > ${var.indexing_latency_threshold_ms}ms for 15 min"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# ThreadpoolWriteQueue — pending write operations backing up indicates the
# cluster cannot keep up with incoming indexing requests.
resource "aws_cloudwatch_metric_alarm" "os_write_queue" {
  alarm_name          = "${var.domain_name}-write-queue-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ThreadpoolWriteQueue"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.write_queue_threshold
  alarm_description   = "OpenSearch ${var.domain_name} ThreadpoolWriteQueue > ${var.write_queue_threshold} — write operations backing up, ingestion throughput may be falling behind"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = local.os_dimensions

  tags = local.common_tags
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "opensearch" {
  dashboard_name = "${var.domain_name}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "OpenSearch — Cluster Status"
          region = var.aws_region
          metrics = [
            ["AWS/ES", "ClusterStatus.red", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Red", color = "#d62728" }],
            ["AWS/ES", "ClusterStatus.yellow", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Yellow", color = "#ff7f0e" }]
          ]
          period = 60
          stat   = "Maximum"
          view   = "timeSeries"
          yAxis  = { left = { min = 0, max = 1 } }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "OpenSearch — Data Node CPU (%)"
          region = var.aws_region
          metrics = [
            ["AWS/ES", "CPUUtilization", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "CPU Avg" }]
          ]
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          yAxis  = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "OpenSearch — JVM Memory Pressure (%)"
          region = var.aws_region
          metrics = [
            ["AWS/ES", "JVMMemoryPressure", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "JVM Pressure", color = "#ff7f0e" }]
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
          title  = "OpenSearch — Free Storage Space (MB)"
          region = var.aws_region
          metrics = [
            ["AWS/ES", "FreeStorageSpace", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Free Storage MB", color = "#2ca02c" }]
          ]
          period = 300
          stat   = "Minimum"
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
          title  = "OpenSearch — Search & Indexing Latency p99 (ms)"
          region = var.aws_region
          metrics = [
            ["AWS/ES", "SearchLatency", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Search p99", stat = "p99" }],
            ["AWS/ES", "IndexingLatency", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Indexing p99", stat = "p99", color = "#ff7f0e" }]
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
          title  = "OpenSearch — Master CPU & Write Queue"
          region = var.aws_region
          metrics = [
            ["AWS/ES", "MasterCPUUtilization", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Master CPU %", yAxis = "left" }],
            ["AWS/ES", "ThreadpoolWriteQueue", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Write Queue", yAxis = "right", color = "#d62728" }]
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
          title  = "OpenSearch — Search & Indexing Rate"
          region = var.aws_region
          metrics = [
            ["AWS/ES", "SearchRate", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Search Requests/min" }],
            ["AWS/ES", "IndexingRate", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Indexing Requests/min", color = "#ff7f0e" }]
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
          title  = "OpenSearch — Kibana Healthy Nodes"
          region = var.aws_region
          metrics = [
            ["AWS/ES", "KibanaHealthyNodes", "DomainName", var.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { label = "Kibana Healthy Nodes", color = "#2ca02c" }]
          ]
          period = 60
          stat   = "Minimum"
          view   = "timeSeries"
          yAxis  = { left = { min = 0 } }
        }
      }
    ]
  })
}
