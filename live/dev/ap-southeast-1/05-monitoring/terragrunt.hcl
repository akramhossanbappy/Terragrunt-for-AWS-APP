include "root" {
  path = find_in_parent_folders()
}

dependency "data" {
  config_path = "../03-data"

  mock_outputs = {
    elasticache_replication_group_id = "tfdemo-fifa-dev-mock"
  }

  mock_outputs_allowed_terraform_commands = [
    "init",
    "validate",
    "plan"
  ]
}

terraform {
  source = "../../../../modules//monitoring"
}

inputs = {
  elasticache_replication_group_id = dependency.data.outputs.elasticache_replication_group_id

  project     = "tfdemo"
  environment = "dev"
  tier        = "dev"
  aws_region  = "ap-southeast-1"

  monitoring_redis_primary_cluster_ids = [
    "tfdemo-fifa-dev-0001-001",
    "tfdemo-fifa-dev-0002-001",
    "tfdemo-fifa-dev-0003-001",
  ]

  monitoring_redis_replica_cluster_ids = [
    "tfdemo-fifa-dev-0001-002",
    "tfdemo-fifa-dev-0002-002",
    "tfdemo-fifa-dev-0003-002",
  ]

  monitoring_opensearch_domain_name = "tfdemo-os-dev"

  gchat_webhook_url = "REPLACE_WITH_DEV_GCHAT_WEBHOOK_URL"
}