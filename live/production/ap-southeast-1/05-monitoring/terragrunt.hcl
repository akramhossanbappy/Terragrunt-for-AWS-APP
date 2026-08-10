include "root" {
  path = find_in_parent_folders()
}

dependency "data" {
  config_path = "../03-data"

  mock_outputs = {
    elasticache_replication_group_id = "singleapp-fifa-prod-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../modules/monitoring"
}

inputs = {
  elasticache_replication_group_id = dependency.data.outputs.elasticache_replication_group_id

  project     = "singleapp"
  environment = "prod"
  tier        = "production"
  aws_region  = "ap-southeast-1"

  # Replication group: singleapp-fifa-prod (6 shards × 2 nodes = 12 total)
  # IMPORTANT: Verify node IDs from AWS Console → ElastiCache → singleapp-fifa-prod → Nodes tab
  # before applying. The -001 suffix = primary, -002 = replica (standard AWS naming).
  monitoring_redis_primary_cluster_ids = [
    "singleapp-fifa-prod-0001-001",
    "singleapp-fifa-prod-0002-001",
    "singleapp-fifa-prod-0003-001",
    "singleapp-fifa-prod-0004-001",
    "singleapp-fifa-prod-0005-001",
    "singleapp-fifa-prod-0006-001",
  ]
  monitoring_redis_replica_cluster_ids = [
    "singleapp-fifa-prod-0001-002",
    "singleapp-fifa-prod-0002-002",
    "singleapp-fifa-prod-0003-002",
    "singleapp-fifa-prod-0004-002",
    "singleapp-fifa-prod-0005-002",
    "singleapp-fifa-prod-0006-002",
  ]

  monitoring_opensearch_domain_name = "singleapp-os-prod"

  gchat_webhook_url = "https://chat.googleapis.com/v1/spaces/AAAA2phmPyI/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=BH4i0Snua9FlE3nlSarqz06COVpaJXfocLfg6n0oYPI"
}
