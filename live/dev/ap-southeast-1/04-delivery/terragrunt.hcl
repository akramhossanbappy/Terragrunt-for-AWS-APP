include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../modules//delivery"
}

inputs = {
  project         = "tfdemo"
  environment     = "dev"
  cls_environment = "dev"
  tier            = "dev"
  aws_region      = "ap-southeast-1"

  ms_name = ["engagement", "static", "fluentd", "deeplink", "cron-worker"]

  pipeline_s3_bucket_name = "REPLACE_WITH_DEV_PIPELINE_LOG_BUCKET"
  ChatWebhook             = "REPLACE_WITH_DEV_GCHAT_WEBHOOK_URL"

  github_codeconnection_arn = "REPLACE_WITH_DEV_GITHUB_CODECONNECTION_ARN"
  github_url                = "https://github.com/"
  github_workspace          = "REPLACE_WITH_DEV_GITHUB_WORKSPACE"
  github_repository         = ["engagement", "single-app-fifa-static", "fluentd", "single-app-fifa-deeplink", "tfdemo-fifa-cron-worker"]
  github_branch_pp          = "dev"
  github_branch             = "main"
}
