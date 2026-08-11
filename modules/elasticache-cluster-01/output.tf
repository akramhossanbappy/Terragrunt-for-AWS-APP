output "ms1_elasticache_id" {
  value = aws_elasticache_replication_group.elasticache_cluster_01.id
}
output "elasticache_cluster_subnet_group_name" {
  value = aws_elasticache_subnet_group.elasticache_subnet.name
}


output "redis_member_cluster_ids" {
  value = aws_elasticache_replication_group.elasticache_cluster_01.member_clusters
}