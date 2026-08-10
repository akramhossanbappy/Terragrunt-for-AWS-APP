include "root" {
  path = find_in_parent_folders()
}

dependency "waf_cloudfront" {
  config_path = "../../us-east-1/08-waf-cloudfront"

  mock_outputs = {
    web_acl_arn = "arn:aws:wafv2:us-east-1:487542879553:global/webacl/mock/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../modules/static-sites"
}

inputs = {
  web_acl_id = dependency.waf_cloudfront.outputs.web_acl_arn

  project     = "singleapp"
  environment = "dev"
  tier        = "dev"
  aws_region  = "ap-southeast-1"

  s3_static_bucket     = ["REPLACE_WITH_DEV_STATIC_BUCKET_NAME"]
  s3_cdn_static_bucket = ["REPLACE_WITH_DEV_CDN_STATIC_BUCKET_NAME"]
  acm_cert_arn_static  = "REPLACE_WITH_DEV_ACM_CERT_ARN"
  cdn_extra_aliases    = {}

  s3_cdn_deeplink_bucket     = ["REPLACE_WITH_DEV_DEEPLINK_BUCKET_NAME"]
  acm_cert_arn_deeplink      = "REPLACE_WITH_DEV_ACM_CERT_ARN"
  cdn_deeplink_extra_aliases = {}
}
