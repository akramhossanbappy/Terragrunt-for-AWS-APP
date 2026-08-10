variable "project" {
  description = "Project name"
}

variable "environment" {
  description = "Infra environment name"
}
variable "cls_environment" {
  description = "Cluster development environemtn name"
}
variable "tier" {
  description = "infra tier"
}

# Create MicroService name
variable "ms_name" {
  type = list(string)
}

variable "aws_region" {
  type = string
}

