module "ecr" {
  source          = "../ecr"
  project         = var.project
  environment     = var.environment
  cls_environment = var.cls_environment
  tier            = var.tier
  aws_region      = var.aws_region
  ms_name         = var.ms_name
}

module "cicd" {
  source                    = "../cicd"
  project                   = var.project
  environment               = var.environment
  cls_environment           = var.cls_environment
  tier                      = var.tier
  aws_region                = var.aws_region
  ms_name                   = var.ms_name
  pipeline_s3_bucket_name   = var.pipeline_s3_bucket_name
  ChatWebhook               = var.ChatWebhook
  docker_password           = var.docker_password
  github_url                = var.github_url
  github_workspace          = var.github_workspace
  github_repository         = var.github_repository
  github_codeconnection_arn = var.github_codeconnection_arn
  github_branch             = var.github_branch
  github_branch_pp          = var.github_branch_pp
}

# Pipeline artifact S3 bucket already exists in AWS — import it so Terraform
# doesn't try to create it and hit BucketAlreadyExists.
import {
  to = module.cicd.aws_s3_bucket.s3-bucket-backend
  id = var.pipeline_s3_bucket_name
}
