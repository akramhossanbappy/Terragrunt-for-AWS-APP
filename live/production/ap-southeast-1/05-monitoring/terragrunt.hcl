include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_config = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )

  region_config = read_terragrunt_config(
    find_in_parent_folders("region.hcl")
  )
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
  # Dependency output
  elasticache_replication_group_id = dependency.data.outputs.elasticache_replication_group_id

  # Common environment values
  project     = local.env_config.locals.project
  environment = local.env_config.locals.environment
  tier        = local.env_config.locals.tier

  # Region
  aws_region = local.region_config.locals.aws_region

  # Redis monitoring
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

  # OpenSearch monitoring
  monitoring_opensearch_domain_name = "tfdemo-os-dev"

  # Notification
  gchat_webhook_url = "REPLACE_WITH_DEV_GCHAT_WEBHOOK_URL"
}