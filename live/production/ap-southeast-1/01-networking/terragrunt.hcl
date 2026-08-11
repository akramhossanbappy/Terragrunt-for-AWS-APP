include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  root_config = read_terragrunt_config(
    find_in_parent_folders("root.hcl")
  )

  env_config = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )

  region_config = read_terragrunt_config(
    find_in_parent_folders("region.hcl")
  )

  settings = merge(
    local.root_config.locals.common_defaults,
    local.env_config.locals.environment_overrides
  )

  tags = merge(
    local.settings.default_tags,
    local.env_config.locals.environment_tags,
    local.region_config.locals.region_tags
  )
}

terraform {
  source = "../../../../modules//vpc"
}

inputs = {
  project     = local.env_config.locals.project
  environment = local.env_config.locals.environment
  tier        = local.env_config.locals.tier

  vpc_cidr = "10.10.0.0/16"

  public_subnets_cidr = [
    "10.10.0.0/20",
    "10.10.16.0/20",
    "10.10.32.0/20"
  ]

  private_subnets_cidr = [
    "10.10.64.0/19",
    "10.10.96.0/19",
    "10.10.128.0/19"
  ]

  secure_subnets_cidr = [
    "10.10.160.0/23",
    "10.10.162.0/23",
    "10.10.164.0/23"
  ]

  availability_zones_public  = local.region_config.locals.availability_zones
  availability_zones_private = local.region_config.locals.availability_zones
  availability_zones_secure  = local.region_config.locals.availability_zones

  cidr_block-internet_gw = "0.0.0.0/0"
  cidr_block-nat_gw      = "0.0.0.0/0"
}