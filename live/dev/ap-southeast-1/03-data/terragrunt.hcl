include "root" {
  path = find_in_parent_folders()
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
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../modules/data"
}

inputs = {
  vpc_id           = dependency.networking.outputs.vpc_id
  secure_subnets   = dependency.networking.outputs.aws_subnets_secure
  secure_sg_id     = dependency.networking.outputs.secure_sg_id
  private_subnets  = dependency.networking.outputs.aws_subnets_private
  efs_sg           = dependency.networking.outputs.efs_sg_id
  kibana_alb_sg_id = dependency.networking.outputs.kibana_alb_sg_id
  public_subnets   = dependency.networking.outputs.aws_subnets_public

  project     = "singleapp"
  environment = "dev"
  tier        = "dev"
  aws_region  = "ap-southeast-1"

  elasticache_cluster_01_name           = "singleapp-dev"
  elasticache_cluster_01_engine_version = "7.1"
  elasticache_cluster_01_node_type      = "cache.t3.micro"
  replicas_count                        = "0"
  automatic_failover_enabled            = true
  num_node_groups                       = 1
  replicas_per_node_group               = 1

  opensearch_instance_type           = "r7g.medium.search"
  opensearch_instance_count          = 1
  opensearch_volume_size             = 600
  opensearch_volume_type             = "gp3"
  opensearch_zone_awareness_enabled  = false
  opensearch_availability_zone_count = 2

  kibana_certificate_arn = "REPLACE_WITH_DEV_KIBANA_CERT_ARN"
}
