module "eks" {
  source          = "../eks"
  project         = var.project
  environment     = var.environment
  tier            = var.tier
  private_subnets = var.private_subnets
  fargate_profile = var.fargate_profile
  secure_sg       = var.secure_sg
  alb_sg_id       = var.alb_sg_id
  cms_sg_id       = var.cms_sg_id
}

module "kubernetes" {
  source       = "../kubernetes"
  project      = var.project
  tier         = var.tier
  environment  = var.environment
  aws_region   = var.aws_region
  cluster_id   = module.eks.cluster_id
  vpc_id       = var.vpc_id
  cluster_name = module.eks.cluster_name
  eks_iam_user = var.eks_iam_user
}
