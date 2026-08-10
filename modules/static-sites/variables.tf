# Common
variable "project" {}
variable "environment" {}
variable "tier" {}
variable "aws_region" {}

# S3 static (reporting bucket)
variable "s3_static_bucket" {
  type=list(string)
}

# S3 + CloudFront static assets
variable "s3_cdn_static_bucket" {
  type = list(string)
}
variable "acm_cert_arn_static" {
  default = ""
}
variable "cdn_extra_aliases" {
  type    = map(list(string))
  default = {}
}

# S3 + CloudFront deeplink
variable "s3_cdn_deeplink_bucket" {
  type = list(string)
}
variable "acm_cert_arn_deeplink" {
  default = ""
}
variable "cdn_deeplink_extra_aliases" {
  type    = map(list(string))
  default = {}
}

# From the waf-cloudfront unit (module.waf-cloudfront web_acl_arn output)
variable "web_acl_id" {
  description = "ARN of the CLOUDFRONT-scope WAF WebACL (us-east-1). Sourced from the waf-cloudfront unit's web_acl_arn output."
  type        = string
  default     = ""
}
