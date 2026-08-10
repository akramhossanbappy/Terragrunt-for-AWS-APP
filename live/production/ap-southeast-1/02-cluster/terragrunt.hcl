include "root" {
  path = find_in_parent_folders()
}

dependency "networking" {
  config_path = "../01-networking"

  mock_outputs = {
    vpc_id              = "vpc-mock00000000000"
    aws_subnets_private = ["subnet-mockpriv1", "subnet-mockpriv2", "subnet-mockpriv3"]
    secure_sg_id        = "sg-mocksecure00000"
    alb_sg_id           = "sg-mockalb000000000"
    cms_sg_id           = "sg-mockcms000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../modules/cluster"
}

inputs = {
  vpc_id          = dependency.networking.outputs.vpc_id
  private_subnets = dependency.networking.outputs.aws_subnets_private
  secure_sg       = dependency.networking.outputs.secure_sg_id
  alb_sg_id       = dependency.networking.outputs.alb_sg_id
  cms_sg_id       = dependency.networking.outputs.cms_sg_id

  project     = "tfdemo"
  environment = "prod"
  tier        = "production"
  aws_region  = "ap-southeast-1"

  fargate_profile = ["kube-system", "preprod", "production", "flux-system", "keda"]
  eks_iam_user    = ["sayfee.ahmed@portonics.com", "akram.hossan@portonics.com", "md.golam.shakir@portonics.com", "md.erfan.uddin.chowdhury@portonics.com"]
}
