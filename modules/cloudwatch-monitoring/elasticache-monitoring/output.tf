output "sns_topic_arn" {
  description = "ARN of the SNS alert topic."
  value       = aws_sns_topic.alerts.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function forwarding alarm notifications to Google Chat."
  value       = aws_lambda_function.gchat_notifier.function_name
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL for ElastiCache monitoring."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.elasticache.dashboard_name}"
}

output "alarm_names" {
  description = "All CloudWatch alarm names created by this module."
  value = compact([
    local.has_primaries ? aws_cloudwatch_metric_alarm.cache_cpu_high[0].alarm_name : null,
    local.has_primaries ? aws_cloudwatch_metric_alarm.cache_memory_high[0].alarm_name : null,
    local.has_primaries ? aws_cloudwatch_metric_alarm.cache_evictions[0].alarm_name : null,
    local.has_primaries ? aws_cloudwatch_metric_alarm.cache_connections_high[0].alarm_name : null,
    local.has_replicas ? aws_cloudwatch_metric_alarm.cache_replication_lag[0].alarm_name : null,
  ])
}
