variable "environment" {
  description = "environment name"
}

variable "vpc_cidr" {
  description = "Cidr value of vpc"
}

variable "project" {
  description = "Name of project"
}

variable "tier" {
  description = "Name of tier"
}

variable "public_subnets_cidr" {
  description = "List of public subnet cidr"
  type = list(string)
}

variable "private_subnets_cidr" {
  description = "List of private subnets cidr"
  type = list(string)
}

variable "secure_subnets_cidr" {
  description = "List of secure subnets cidr"
  type = list(string)
}

variable "availability_zones_public" {
  description = "List of availability zones of public subnets"
  type = list(string)
}

variable "availability_zones_private" {
  description = "List of availability zones of private subnets"
  type = list(string)
}

variable "availability_zones_secure" {
  description = "List of availability zones of secure subnets"
  type = list(string)
}

variable "cidr_block-nat_gw" {
  description = "Destination cidr of nat gateway"
}

variable "cidr_block-internet_gw" {
  description = "Destination cidr of internet gateway"
}
