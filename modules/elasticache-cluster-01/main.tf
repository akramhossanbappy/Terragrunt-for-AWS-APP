
#elastic Cache subnet and cache cluster 
resource "aws_elasticache_subnet_group" "elasticache_subnet" {
  name       = "${var.project}-cache-subnet-${var.environment}" # _ not supported
  subnet_ids = var.secure_subnets
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

#elastic Cache cache cluster
resource "aws_elasticache_replication_group" "elasticache_cluster_01" {
  replication_group_id = "${var.project}-${var.elasticache_cluster_01_name}-${var.environment}"
  description          = "Redis cluster created for microservice"
  engine               = "redis"
  engine_version       = var.elasticache_cluster_01_engine_version
  node_type            = var.elasticache_cluster_01_node_type
  port                 = 6379
  parameter_group_name = "default.redis7.cluster.on"

  # Cluster mode enabled: use shards + replicas, NOT num_cache_clusters
  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  automatic_failover_enabled = var.automatic_failover_enabled
  # multi_az_enabled         = true   # consider enabling for real HA

  snapshot_retention_limit = 7
  snapshot_window          = "00:00-05:00"
  subnet_group_name        = aws_elasticache_subnet_group.elasticache_subnet.name
  security_group_ids       = [var.secure_sg_id]

  at_rest_encryption_enabled = false
  transit_encryption_enabled = false
  auto_minor_version_upgrade = false
  apply_immediately          = true

  log_delivery_configuration {
    destination      = "/aws/elasticache/tfdemo-fifa-production"
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }
  log_delivery_configuration {
    destination      = "/aws/elasticache/tfdemo-fifa-production"
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  lifecycle {}

  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
    Region      = var.aws_region
    Zone        = "Secure"
  }
}

