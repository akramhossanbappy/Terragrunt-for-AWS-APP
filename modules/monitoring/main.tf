# Redis (ElastiCache) monitoring — CPU, memory, evictions, connections, replication lag.
# Metric math aggregates primaries/replicas into one alarm per signal (CloudWatch 10-query limit).
module "elasticache-monitoring" {
  source      = "../cloudwatch-monitoring/elasticache-monitoring"
  project     = var.project
  environment = var.environment
  tier        = var.tier
  aws_region  = var.aws_region

  replication_group_id = var.elasticache_replication_group_id
  primary_cluster_ids  = var.monitoring_redis_primary_cluster_ids
  replica_cluster_ids  = var.monitoring_redis_replica_cluster_ids
  gchat_webhook_url    = var.gchat_webhook_url

  # Tuned for 6-shard cluster: observed baseline ~16,700 total (6 primaries).
  # 50,000 = ~3× baseline (~8,333/node); well below cache.m6g.2xlarge limit of ~65,000/node.
  connections_threshold = 50000
}

# OpenSearch monitoring — cluster status, CPU, storage, JVM, latency, write queue.
module "opensearch-monitoring" {
  source      = "../cloudwatch-monitoring/opensearch-monitoring"
  project     = var.project
  environment = var.environment
  tier        = var.tier
  aws_region  = var.aws_region

  domain_name       = var.monitoring_opensearch_domain_name
  gchat_webhook_url = var.gchat_webhook_url
}
