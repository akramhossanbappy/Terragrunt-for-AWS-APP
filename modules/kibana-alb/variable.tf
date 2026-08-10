variable "project" {}
variable "environment" {}
variable "aws_region" {}
variable "vpc_id" {}
variable "kibana_alb_sg_id" {}
variable "public_subnets" {
    type = list(string)
}
variable "tier" {}
variable "kibana_certificate_arn" {}