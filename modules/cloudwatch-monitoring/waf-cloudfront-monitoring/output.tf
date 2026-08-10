output "sns_topic_arn" {
  description = "ARN of the SNS alert topic."
  value       = aws_sns_topic.alerts.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function forwarding alarm notifications to Google Chat."
  value       = aws_lambda_function.gchat_notifier.function_name
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL for WAF CloudFront monitoring."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.waf_cloudfront.dashboard_name}"
}

output "alarm_names" {
  description = "All CloudWatch alarm names created by this module."
  value = concat(
    [
      aws_cloudwatch_metric_alarm.waf_total_blocked_spike.alarm_name,
      aws_cloudwatch_metric_alarm.waf_block_rate_pct.alarm_name,
    ],
    [for k, v in aws_cloudwatch_metric_alarm.waf_per_rule_blocked : v.alarm_name],
    var.waf_enable_logging ? [aws_cloudwatch_metric_alarm.waf_log_block_count[0].alarm_name] : []
  )
}
