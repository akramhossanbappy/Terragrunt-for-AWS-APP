module "elasticache-cluster-01" {
  source                                = "../elasticache-cluster-01"
  project                               = var.project
  tier                                  = var.tier
  environment                           = var.environment
  aws_region                            = var.aws_region
  secure_subnets                        = var.secure_subnets
  secure_sg_id                          = var.secure_sg_id
  elasticache_cluster_01_name           = var.elasticache_cluster_01_name
  elasticache_cluster_01_engine_version = var.elasticache_cluster_01_engine_version
  elasticache_cluster_01_node_type      = var.elasticache_cluster_01_node_type
  replicas_count                        = var.replicas_count
  automatic_failover_enabled            = var.automatic_failover_enabled
  num_node_groups                       = var.num_node_groups
  replicas_per_node_group               = var.replicas_per_node_group
}

module "efs" {
  source          = "../efs"
  environment     = var.environment
  project         = var.project
  tier            = var.tier
  aws_region      = var.aws_region
  private_subnets = var.private_subnets
  efs_sg          = var.efs_sg
}

module "opensearch" {
  source                              = "../opensearch"
  environment                         = var.environment
  project                             = var.project
  tier                                = var.tier
  aws_region                          = var.aws_region
  secure_subnets                      = var.secure_subnets
  secure_sg_id                        = var.secure_sg_id
  os_db_password                      = var.os_db_password
  os_db_user                          = var.os_db_user
  opensearch_instance_type            = var.opensearch_instance_type
  opensearch_instance_count           = var.opensearch_instance_count
  opensearch_volume_size              = var.opensearch_volume_size
  opensearch_volume_type              = var.opensearch_volume_type
  opensearch_dedicated_master_enabled = var.opensearch_dedicated_master_enabled
  opensearch_dedicated_master_type    = var.opensearch_dedicated_master_type
  opensearch_dedicated_master_count   = var.opensearch_dedicated_master_count
  opensearch_zone_awareness_enabled   = var.opensearch_zone_awareness_enabled
  opensearch_availability_zone_count  = var.opensearch_availability_zone_count
}

module "kibana-alb" {
  count = var.create_kibana_alb ? 1 : 0

  source                 = "../kibana-alb"
  project                = var.project
  environment            = var.environment
  tier                   = var.tier
  aws_region             = var.aws_region
  vpc_id                 = var.vpc_id
  kibana_alb_sg_id       = var.kibana_alb_sg_id
  public_subnets         = var.public_subnets
  kibana_certificate_arn = var.kibana_certificate_arn

  depends_on = [module.opensearch]
}

