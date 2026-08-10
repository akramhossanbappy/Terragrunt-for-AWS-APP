variable "cluster_id" {
  description = "Put your cluster id here"
}

variable "vpc_id" {
  description = "put your vpc id"
}

variable "cluster_name" {}
variable "project" {}
variable "environment" {}
variable "aws_region" {}
variable "tier" {}
variable "eks_iam_user" {
  type = list(string)
}