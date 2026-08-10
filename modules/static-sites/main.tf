module "s3-static" {
  source      = "../s3-static"
  environment = var.environment
  project     = var.project
  tier        = var.tier
  aws_region  = var.aws_region
  s3_bucket   = var.s3_static_bucket
}

module "s3-cloudfront-static" {
  source              = "../s3-cloudfront-static"
  environment         = var.environment
  project             = var.project
  tier                = var.tier
  aws_region          = var.aws_region
  s3_bucket           = var.s3_cdn_static_bucket
  acm_cert_arn_static = var.acm_cert_arn_static
  cdn_extra_aliases   = var.cdn_extra_aliases
  web_acl_id          = var.web_acl_id
}

module "s3-cloudfront-deeplink" {
  source              = "../s3-cloudfront-static"
  environment         = var.environment
  project             = var.project
  tier                = var.tier
  aws_region          = var.aws_region
  s3_bucket           = var.s3_cdn_deeplink_bucket
  acm_cert_arn_static = var.acm_cert_arn_deeplink
  cdn_extra_aliases   = var.cdn_deeplink_extra_aliases
  web_acl_id          = var.web_acl_id
}
