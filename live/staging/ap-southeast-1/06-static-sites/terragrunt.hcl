include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_config = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )

  region_config = read_terragrunt_config(
    find_in_parent_folders("region.hcl")
  )
}

terraform {
  source = "../../../../modules//static-sites"
}

inputs = {
  project     = local.env_config.locals.project
  environment = local.env_config.locals.environment
  tier        = local.env_config.locals.tier
  aws_region  = local.region_config.locals.aws_region

  s3_static_bucket = [
    "REPLACE_WITH_DEV_STATIC_BUCKET_NAME"
  ]

  s3_cdn_static_bucket = [
    "REPLACE_WITH_DEV_CDN_STATIC_BUCKET_NAME"
  ]

  acm_cert_arn_static = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

  cdn_extra_aliases = {}

  s3_cdn_deeplink_bucket = [
    "REPLACE_WITH_DEV_DEEPLINK_BUCKET_NAME"
  ]

  acm_cert_arn_deeplink = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

  cdn_deeplink_extra_aliases = {}
}