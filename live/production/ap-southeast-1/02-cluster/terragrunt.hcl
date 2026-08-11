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
    vpc_id = "vpc-mock00000000000"

    aws_subnets_private = [
      "subnet-mockpriv1",
      "subnet-mockpriv2",
      "subnet-mockpriv3"
    ]

    secure_sg_id = "sg-mocksecure00000"
    alb_sg_id    = "sg-mockalb000000000"
    cms_sg_id    = "sg-mockcms000000000"
  }

  mock_outputs_allowed_terraform_commands = [
    "init",
    "validate",
    "plan"
  ]
}

terraform {
  source = "../../../../modules//cluster"
}

inputs = {
  # Networking dependency
  vpc_id          = dependency.networking.outputs.vpc_id
  private_subnets = dependency.networking.outputs.aws_subnets_private
  secure_sg       = dependency.networking.outputs.secure_sg_id
  alb_sg_id       = dependency.networking.outputs.alb_sg_id
  cms_sg_id       = dependency.networking.outputs.cms_sg_id

  # Common environment values
  project     = local.env_config.locals.project
  environment = local.env_config.locals.environment
  tier        = local.env_config.locals.tier

  # Region
  aws_region = local.region_config.locals.aws_region

  # Cluster-specific values
  fargate_profile = [
    "kube-system",
    "dev",
    "flux-system"
  ]

  eks_iam_user = [
    "dev-user@example.com"
  ]
}