# Common
variable "project" {}
variable "environment" {}
variable "cls_environment" {}
variable "tier" {}
variable "aws_region" {}

# ECR / CICD
variable "ms_name" {
  type = list(string)
}
variable "pipeline_s3_bucket_name" {}
variable "ChatWebhook" {}
variable "docker_password" {
  sensitive = true
}
variable "github_url" {
  type = string
}
variable "github_workspace" {
  type = string
}
variable "github_repository" {
  type = list(string)
}
variable "github_codeconnection_arn" {
  type = string
}
variable "github_branch" {
  type = string
}
variable "github_branch_pp" {
  type = string
}
