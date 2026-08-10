variable "project" {
  description = "your project name"
}
variable "environment" {
  description = "your environment name"
}
variable "aws_region" {
  description = "your Region name"
}
variable "tier" {
  description = "Name of tier"
}

variable "secure_subnets" {
  description = "List of private subnet IDs"
}

variable "secure_sg_id" {
  description = "The ID of security group that is used for secure subnet"
}

variable "elasticache_cluster_01_name" {
  description = "Microservice 1 name"
}

variable "elasticache_cluster_01_engine_version" {
  description = "The engine version of redis"
}

variable "elasticache_cluster_01_node_type" {
  description = "The node type of elasticache redis"
}
variable "replicas_count" {}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover. Requires at least 1 replica per shard."
  type        = bool
  default     = true
}

variable "num_node_groups" {
  description = "Number of shards (node groups) for the cluster. Total nodes = num_node_groups × (1 + replicas_per_node_group)."
  type        = number
  default     = 1
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes per shard. Must be >= 1 when automatic_failover is enabled."
  type        = number
  default     = 1
}