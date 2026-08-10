variable "environment" {
  description = "environment name"
}

variable "project" {
  description = "Name of project"
}

variable "tier" {
  description = "Name of tier"
}

#variable "public_subnets" {
#    description = "id of public subnets"
#}   

variable "private_subnets" {
  description = "id of private subnets"
}
variable "fargate_profile" {
  description = "name ofeks fargate_profile"
}
variable "secure_sg" {
  description = "name of sg"
}

variable "alb_sg_id" {
  description = "alb sg id"
}
variable "cms_sg_id" {
  description = "cms sg id"
}
