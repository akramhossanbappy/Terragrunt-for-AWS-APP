output "sns_topic_arn" {
  description = "ARN of the SNS alert topic."
  value       = aws_sns_topic.alerts.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function forwarding alarm notifications to Google Chat."
  value       = aws_lambda_function.gchat_notifier.function_name
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL for OpenSearch monitoring."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.opensearch.dashboard_name}"
}

output "alarm_names" {
  description = "All CloudWatch alarm names created by this module."
  value = [
    aws_cloudwatch_metric_alarm.os_cluster_red.alarm_name,
    aws_cloudwatch_metric_alarm.os_cluster_yellow.alarm_name,
    aws_cloudwatch_metric_alarm.os_cpu_high.alarm_name,
    aws_cloudwatch_metric_alarm.os_free_storage_low.alarm_name,
    aws_cloudwatch_metric_alarm.os_jvm_pressure.alarm_name,
    aws_cloudwatch_metric_alarm.os_kibana_down.alarm_name,
    aws_cloudwatch_metric_alarm.os_master_cpu_high.alarm_name,
    aws_cloudwatch_metric_alarm.os_search_latency.alarm_name,
    aws_cloudwatch_metric_alarm.os_indexing_latency.alarm_name,
    aws_cloudwatch_metric_alarm.os_write_queue.alarm_name,
  ]
}
