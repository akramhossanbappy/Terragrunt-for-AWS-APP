variable "project" {}
variable "environment" {}
variable "aws_region" {}
variable "tier" {}
variable "s3_bucket" {}
variable "acm_cert_arn_static" {
  default = ""
}

variable "cdn_extra_aliases" {
  description = "Map of CDN bucket name to the complete list of CloudFront CNAME aliases. When set, replaces the default alias (bucket name). When omitted, the bucket name is used as the sole alias."
  type        = map(list(string))
  default     = {}
}

variable "web_acl_id" {
  description = "ARN of the WAF WebACL (CLOUDFRONT scope, us-east-1) to associate with each CloudFront distribution."
  type        = string
  default     = ""
}