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
  source = "../../../../modules//delivery"
}

inputs = {
  # Common environment values
  project         = local.env_config.locals.project
  environment     = local.env_config.locals.environment
  cls_environment = local.env_config.locals.environment
  tier            = local.env_config.locals.tier

  # Region
  aws_region = local.region_config.locals.aws_region

  # Microservices
  ms_name = [
    "engagement",
    "static",
    "fluentd",
    "deeplink",
    "cron-worker"
  ]

  # Pipeline
  pipeline_s3_bucket_name = "REPLACE_WITH_DEV_PIPELINE_LOG_BUCKET"

  # Notifications
  ChatWebhook = "REPLACE_WITH_DEV_GCHAT_WEBHOOK_URL"

  # GitHub
  github_codeconnection_arn = "REPLACE_WITH_DEV_GITHUB_CODECONNECTION_ARN"
  github_url                = "https://github.com/"
  github_workspace          = "REPLACE_WITH_DEV_GITHUB_WORKSPACE"

  github_repository = [
    "engagement",
    "single-app-fifa-static",
    "fluentd",
    "single-app-fifa-deeplink",
    "tfdemo-fifa-cron-worker"
  ]

  github_branch_pp = "dev"
  github_branch    = "main"

  # docker_password intentionally omitted
  # Inject through TF_VAR_docker_password from Secrets Manager / CodeBuild
}