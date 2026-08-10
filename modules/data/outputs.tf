output "elasticache_replication_group_id" {
  value = module.elasticache-cluster-01.ms1_elasticache_id
}

output "elasticache_cluster_subnet_group_name" {
  value = module.elasticache-cluster-01.elasticache_cluster_subnet_group_name
}
