include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../modules/delivery"
}

inputs = {
  project         = "tfdemo"
  environment     = "prod"
  cls_environment = "preprod"
  tier            = "production"
  aws_region      = "ap-southeast-1"

  ms_name = ["engagement", "static", "fluentd", "deeplink", "cron-worker"]

  pipeline_s3_bucket_name = "tfdemo-fifa-pipeline-log-bucket-prod"
  ChatWebhook             = "/v1/spaces/AAQAGewvZxM/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=zDSTH7pG8Wd1o_8cAVD9Z3XyVzaVKEKCZ-W1QzODHqI"

  github_codeconnection_arn = "arn:aws:codeconnections:eu-north-1:487542879553:connection/4b9d50b6-450c-4637-a122-d566423919e9"
  github_url                = "https://github.com/"
  github_workspace          = "portonics-limited"
  github_repository         = ["engagement", "single-app-fifa-static", "fluentd", "single-app-fifa-deeplink", "tfdemo-fifa-cron-worker"]
  github_branch_pp          = "preprod"
  github_branch             = "main"

  # docker_password intentionally omitted — injected at apply time via
  # TF_VAR_docker_password from Secrets Manager (see
  # "cicd-terraform (apply-from-local)/main.tf"), same as before this migration.
}
