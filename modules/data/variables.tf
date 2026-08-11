# Common
variable "project" {}
variable "environment" {}
variable "tier" {}
variable "aws_region" {}

# From the networking unit (module.vpc outputs)
variable "secure_subnets" {
  description = "Secure subnet IDs. Sourced from the networking unit's aws_subnets_secure output. Shared by elasticache-cluster-01 and opensearch, same as today's root main.tf."
  type = list(string)
}
variable "secure_sg_id" {
  description = "Secure security group ID. Sourced from the networking unit's secure_sg_id output. Shared by elasticache-cluster-01 and opensearch."
}
variable "private_subnets" {
  description = "Private subnet IDs. Sourced from the networking unit's aws_subnets_private output."
  type = list(string)
}
variable "efs_sg" {
  description = "EFS security group ID. Sourced from the networking unit's efs_sg_id output."
}
variable "vpc_id" {
  description = "VPC ID. Sourced from the networking unit's vpc_id output."
}
variable "kibana_alb_sg_id" {
  description = "Kibana ALB security group ID. Sourced from the networking unit's kibana_alb_sg_id output."
}
variable "public_subnets" {
  description = "Public subnet IDs. Sourced from the networking unit's aws_subnets_public output."
  type = list(string)
}

# ElastiCache 01
variable "elasticache_cluster_01_name" {}
variable "elasticache_cluster_01_engine_version" {}
variable "elasticache_cluster_01_node_type" {}
variable "replicas_count" {}
variable "automatic_failover_enabled" {
  type    = bool
  default = true
}
variable "num_node_groups" {
  type    = number
  default = 1
}
variable "replicas_per_node_group" {
  type    = number
  default = 1
}

# OpenSearch
variable "os_db_user" {}
variable "os_db_password" {
  sensitive = true
}
variable "opensearch_instance_type" {}
variable "opensearch_instance_count" {
  type    = number
  default = 1
}
variable "opensearch_volume_size" {}
variable "opensearch_volume_type" {}
variable "opensearch_dedicated_master_enabled" {
  type    = bool
  default = false
}
variable "opensearch_dedicated_master_type" {
  type    = string
  default = ""
}
variable "opensearch_dedicated_master_count" {
  type    = number
  default = 3
}
variable "opensearch_zone_awareness_enabled" {
  type    = bool
  default = false
}
variable "opensearch_availability_zone_count" {
  type    = number
  default = 2
}

# Kibana
variable "kibana_certificate_arn" {}
variable "create_kibana_alb" {
  type    = bool
  default = false
}