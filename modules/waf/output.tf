output "web_acl_arn" {
  description = "ARN of the WAF WebACL. For CloudFront, assign this to the aws_cloudfront_distribution web_acl_id attribute."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "ID of the WAF WebACL."
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_name" {
  description = "Name of the WAF WebACL."
  value       = aws_wafv2_web_acl.this.name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group receiving WAF logs (empty string if logging is disabled)."
  value       = var.enable_logging ? aws_cloudwatch_log_group.waf[0].name : ""
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group receiving WAF logs (empty string if logging is disabled)."
  value       = var.enable_logging ? aws_cloudwatch_log_group.waf[0].arn : ""
}

output "count_mode_active" {
  description = "True when managed rule groups are in COUNT (observe) mode and are not blocking. Flip count_mode_only to false to enforce."
  value       = var.count_mode_only
}
