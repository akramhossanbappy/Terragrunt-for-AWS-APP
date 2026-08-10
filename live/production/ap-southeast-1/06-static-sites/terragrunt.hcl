include "root" {
  path = find_in_parent_folders()
}

dependency "waf_cloudfront" {
  config_path = "../../us-east-1/08-waf-cloudfront"

  mock_outputs = {
    web_acl_arn = "arn:aws:wafv2:us-east-1:487542879553:global/webacl/mock/00000000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../modules/static-sites"
}

inputs = {
  web_acl_id = dependency.waf_cloudfront.outputs.web_acl_arn

  project     = "singleapp"
  environment = "prod"
  tier        = "production"
  aws_region  = "ap-southeast-1"

  s3_static_bucket     = ["singleapp-fifa-prod-reporting.robi.com.bd"]
  s3_cdn_static_bucket = ["singleapp-fifa-static-prod-cdn.robi.com.bd"]
  acm_cert_arn_static  = "arn:aws:acm:us-east-1:487542879553:certificate/dd7e8e2d-c99f-4e71-b37f-743d0131765c"
  cdn_extra_aliases = {
    "singleapp-fifa-static-prod-cdn.robi.com.bd" = [
      "myairtel-fifa-static-prod.robi.com.bd",
      "myrobi-fifa-static-prod.robi.com.bd",
    ]
  }

  s3_cdn_deeplink_bucket = ["singleapp-fifa-deeplink-prod-cdn.robi.com.bd"]
  acm_cert_arn_deeplink  = "arn:aws:acm:us-east-1:487542879553:certificate/dd7e8e2d-c99f-4e71-b37f-743d0131765c"
  cdn_deeplink_extra_aliases = {
    "singleapp-fifa-deeplink-prod-cdn.robi.com.bd" = [
      "myairtel-fifa-web-prod.robi.com.bd",
      "myrobi-fifa-web-prod.robi.com.bd",
    ]
  }
}
