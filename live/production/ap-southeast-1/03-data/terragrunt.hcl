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

dependency "networking" {
  config_path = "../01-networking"

  mock_outputs = {
    vpc_id              = "vpc-mock00000000000"
    aws_subnets_secure  = ["subnet-mocksec1", "subnet-mocksec2", "subnet-mocksec3"]
    aws_subnets_private = ["subnet-mockpriv1", "subnet-mockpriv2", "subnet-mockpriv3"]
    aws_subnets_public  = ["subnet-mockpub1", "subnet-mockpub2", "subnet-mockpub3"]
    secure_sg_id        = "sg-mocksecure00000"
    efs_sg_id           = "sg-mockefs000000000"
    kibana_alb_sg_id    = "sg-mockkibana000000"
  }

  mock_outputs_allowed_terraform_commands = [
    "init",
    "validate",
    "plan"
  ]
}

terraform {
  source = "../../../../modules//data"
}

inputs = {
  # Networking
  vpc_id           = dependency.networking.outputs.vpc_id
  secure_subnets   = dependency.networking.outputs.aws_subnets_secure
  secure_sg_id     = dependency.networking.outputs.secure_sg_id
  private_subnets  = dependency.networking.outputs.aws_subnets_private
  efs_sg           = dependency.networking.outputs.efs_sg_id
  kibana_alb_sg_id = dependency.networking.outputs.kibana_alb_sg_id
  public_subnets   = dependency.networking.outputs.aws_subnets_public

  # Common environment
  project     = local.env_config.locals.project
  environment = local.env_config.locals.environment
  tier        = local.env_config.locals.tier

  # Region
  aws_region = local.region_config.locals.aws_region

  # ElastiCache
  elasticache_cluster_01_name           = "tfdemo-dev"
  elasticache_cluster_01_engine_version = "7.1"
  elasticache_cluster_01_node_type      = "cache.t3.micro"

  replicas_count             = 0
  automatic_failover_enabled = true
  num_node_groups             = 1
  replicas_per_node_group     = 1

  # OpenSearch
  opensearch_instance_type           = "r7g.medium.search"
  opensearch_instance_count          = 1
  opensearch_volume_size             = 600
  opensearch_volume_type             = "gp3"
  opensearch_zone_awareness_enabled  = false
  opensearch_availability_zone_count = 2

  # Kibana ALB
  create_kibana_alb = false

  kibana_certificate_arn = "arn:aws:acm:us-east-1:487542879553:certificate/dd7e8e2d-c99f-4e71-b37f-743d0131765c"

  # os_db_user / os_db_password intentionally omitted
  # Inject with TF_VAR_os_db_user / TF_VAR_os_db_password
}