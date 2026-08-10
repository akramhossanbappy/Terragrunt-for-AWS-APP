# Common
variable "project" {}
variable "environment" {}
variable "tier" {}
variable "aws_region" {}

# From the networking unit (module.vpc outputs)
variable "vpc_id" {
  description = "VPC ID. Sourced from the networking unit's vpc_id output."
}
variable "private_subnets" {
  description = "Private subnet IDs. Sourced from the networking unit's aws_subnets_private output."
}
variable "secure_sg" {
  description = "Secure security group ID. Sourced from the networking unit's secure_sg_id output."
}
variable "alb_sg_id" {
  description = "ALB security group ID. Sourced from the networking unit's alb_sg_id output."
}
variable "cms_sg_id" {
  description = "CMS security group ID. Sourced from the networking unit's cms_sg_id output."
}

# EKS
variable "fargate_profile" {
  description = "List of Fargate profile namespaces."
}
variable "eks_iam_user" {
  type = list(string)
}
