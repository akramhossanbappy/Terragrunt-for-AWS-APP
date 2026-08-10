resource "aws_eks_cluster" "eks_cluster" {
  name                      = "${var.project}-${var.environment}"
  role_arn                  = aws_iam_role.eks_cluster_role.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  timeouts {
    delete = "30m"
  }
  vpc_config {
    subnet_ids              = concat(var.private_subnets)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["100.25.23.221/32", "68.183.227.163/32", "13.250.202.122/32"] # source IP from where the api-server will be reachable.
    security_group_ids      = [var.secure_sg]
  }
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment_01,
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment_04,
    aws_cloudwatch_log_group.eks_fargate_log_group,
    aws_iam_role_policy_attachment.eks_fargate_policy_attachment_01,
  ]
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_security_group_rule" "eks_cluster_default_sg_rule" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.alb_sg_id
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}
resource "aws_security_group_rule" "eks_cluster_cms_sg_rule" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.cms_sg_id
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}

resource "aws_iam_policy" "eks_cluster_cw_metric_policy" {
  name   = "${var.project}-eks-cluster-cw-metric-policy-${var.environment}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name                  = "${var.project}-cluster-role-${var.environment}"
  description           = "Allow cluster to manage node groups, fargate nodes and cloudwatch logs"
  force_detach_policies = true
  assume_role_policy    = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "eks.amazonaws.com",
          "eks-fargate-pods.amazonaws.com"
          ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment_01" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment_02" {
  policy_arn = aws_iam_policy.eks_cluster_cw_metric_policy.arn
  role       = aws_iam_role.eks_cluster_role.name
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment_03" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy" # Add this policy to get scheduled on fargate node
  role       = aws_iam_role.eks_cluster_role.name
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment_04" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_cloudwatch_log_group" "eks_fargate_log_group" {
  name              = "/aws/eks/${var.project}-${var.environment}/cluster"
  retention_in_days = 30
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_role" "eks_fargate_role" {
  name                  = "${var.project}-fargate-cluster-role-${var.environment}"
  description           = "Allow fargate cluster to allocate resources for running pods"
  force_detach_policies = true
  assume_role_policy    = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "eks.amazonaws.com",
          "eks-fargate-pods.amazonaws.com"
          ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_iam_role_policy_attachment" "eks_fargate_policy_attachment_01" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.eks_fargate_role.name
}

resource "aws_iam_role_policy_attachment" "eks_fargate_policy_attachment_02" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_fargate_role.name
}


resource "aws_iam_role_policy_attachment" "eks_fargate_policy_attachment_03" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_fargate_role.name
}


resource "aws_eks_fargate_profile" "kube-system" {
  for_each               = toset(var.fargate_profile)
  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = each.key
  pod_execution_role_arn = aws_iam_role.eks_fargate_role.arn
  subnet_ids             = var.private_subnets

  selector {
    namespace = each.key # Adjust this to target your desired Kubernetes namespace
  }
  timeouts {
    create = "30m"
    delete = "30m"
  }
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }

}

data "tls_certificate" "auth" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "my_openid" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.auth.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_policy" "eks_cluster_secret_manager_policy" {
  name   = "${var.project}-allow-get-secret-policy-${var.environment}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSecretsManagerReadAccess",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:*",
                "ssm:*",
                "kms:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "external_secret_role" {
  name                  = "${var.project}-eks-external-secrets-role-${var.environment}"
  description           = "Allow cluster to access secretsmanager,ssm,kms"
  assume_role_policy    = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/")}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:*"


        }
      }
    }
  ]
}
POLICY
  force_detach_policies = true
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "eks_external_secret_manager_policy" {
  policy_arn = aws_iam_policy.eks_cluster_secret_manager_policy.arn
  role       = aws_iam_role.external_secret_role.name
}

