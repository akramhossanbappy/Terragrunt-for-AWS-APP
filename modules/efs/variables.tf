variable "project" {}
variable "environment" {}
variable "aws_region" {}
variable "private_subnets" {
    type = list(string)
}
variable "efs_sg" {}
variable "tier" {}
