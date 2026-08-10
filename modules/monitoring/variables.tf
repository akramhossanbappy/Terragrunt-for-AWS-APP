# Common
variable "project" {}
variable "environment" {}
variable "tier" {}
variable "aws_region" {}

# From the data unit (module.elasticache-cluster-01 output, via the data
# unit's elasticache_replication_group_id output). This is the one place
# this migration wires a dependency block where the old root main.tf used a
# manually copy-pasted var instead — the output already existed and is an
# exact match.
variable "elasticache_replication_group_id" {
  type = string
}

# Redis / ElastiCache monitoring — still plain vars (no matching per-node
# outputs exist on elasticache-cluster-01 to derive these from).
variable "monitoring_redis_primary_cluster_ids" {
  type    = list(string)
  default = []
}
variable "monitoring_redis_replica_cluster_ids" {
  type    = list(string)
  default = []
}

# OpenSearch monitoring
variable "monitoring_opensearch_domain_name" {
  type = string
}

variable "gchat_webhook_url" {
  description = "Google Chat webhook URL for ElastiCache/OpenSearch CloudWatch alarm notifications."
  type        = string
  sensitive   = true
}
