data "aws_eks_cluster" "eks_cluster" {
  name = var.cluster_id
}
data "aws_eks_cluster_auth" "eks_cluster_auth" {
  name = var.cluster_id
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "alb_policy" {
  name = "${var.project}-alb-policy-${var.environment}"
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags",
                "elasticloadbalancing:DescribeListenerAttributes",
                "elasticloadbalancing:SetRulePriorities"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:GetSubscriptionState",
                "shield:DescribeProtection",
                "shield:CreateProtection",
                "shield:DeleteProtection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "StringEquals": {
                    "elasticloadbalancing:CreateAction": [
                        "CreateTargetGroup",
                        "CreateLoadBalancer"
                    ]
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_role" "eks_alb_ingress_controller_role" {
  name        = "${var.project}-eks-alb-ingress-controller-role-${var.environment}"
  description = "Permissions required by the Kubernetes AWS ALB Ingress controller to do it's job."

  force_detach_policies = true

  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }

  assume_role_policy = <<ROLE
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud": "sts.amazonaws.com",
          "${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
ROLE
}

resource "aws_iam_role_policy_attachment" "alb_policy_attachment" {
  policy_arn = aws_iam_policy.alb_policy.arn
  role       = aws_iam_role.eks_alb_ingress_controller_role.name
}


resource "aws_iam_role" "fluxcd_ecr_job_role" {
  name               = "${var.project}-cluster-ecr-access-role-${var.environment}"
  assume_role_policy = <<ROLE
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:flux-system:ecr-credentials-sync"
        }
      }
    }
  ]
}
ROLE
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_iam_role_policy_attachment" "fluxcd_ecr_job_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.fluxcd_ecr_job_role.id
}
resource "aws_iam_role" "pods_serivce_account_role" {
  name               = "${var.project}-cluster-pods-role-${var.environment}"
  assume_role_policy = <<ROLE
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:*"
        }
      }
    }
  ]
}
ROLE
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_iam_role_policy_attachment" "pods_serivce_account_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.pods_serivce_account_role.id
}

# ## aws k8 access 
# data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${local.account_id}:root"
      }
      Action    = "sts:AssumeRole"
      Condition = {}
    }]
  })
  admin_group_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowAssumeOrganizationAccountRole"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::${local.account_id}:role/k8sAdmin"
    }]
  })
  dev_group_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowAssumeOrganizationAccountRole"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::${local.account_id}:role/k8sDev"
    }]
  })
}

resource "aws_iam_role" "k8s_admin_role" {
  name               = "${var.project}-k8s-role-admin-${var.environment}"
  description        = "Kubernetes administrator role (for AWS IAM Authenticator for Kubernetes)."
  assume_role_policy = local.policy
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_role" "k8s_dev_role" {
  name               = "${var.project}-k8s-dev-role-${var.environment}"
  description        = "Kubernetes developer role (for AWS IAM Authenticator for Kubernetes)."
  assume_role_policy = local.policy
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_group" "k8s_admin_group" {
  name = "${var.project}-k8s-admin-group-${var.environment}"
}
resource "aws_iam_group_policy" "k8s_admin_group_policy" {
  name   = "${var.project}-k8s-admin-policy-${var.environment}"
  group  = aws_iam_group.k8s_admin_group.name
  policy = local.admin_group_policy
}
resource "aws_iam_role_policy_attachment" "k8s_admin_policy_attachment_01" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.k8s_admin_role.name
}

resource "aws_iam_role_policy_attachment" "k8s_admin_policy_attachment_02" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.k8s_admin_role.name
}


resource "aws_iam_role_policy_attachment" "k8s_admin_policy_attachment_03" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.k8s_admin_role.name
}
resource "aws_iam_group" "k8s_dev_group" {
  name = "${var.project}-k8s-dev-group-${var.environment}"
}
resource "aws_iam_group_policy" "k8s_dev_group_policy" {
  name   = "${var.project}-k8s-dev-policy-${var.environment}"
  group  = aws_iam_group.k8s_dev_group.name
  policy = local.dev_group_policy
}

resource "aws_eks_access_entry" "eks_access_entry" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.k8s_admin_role.arn
  type          = "FARGATE_LINUX" # If type id FARGATE_LINUX  then policy groups will not added
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_eks_access_entry" "eks_iam_user_access_entry" {
  for_each      = toset(var.eks_iam_user)
  cluster_name  = var.cluster_name
  principal_arn = "arn:aws:iam::${local.account_id}:user/${each.value}"
  type          = "STANDARD" # If type id FARGATE_LINUX  then policy groups will not added
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_eks_access_policy_association" "access_policy_association" {
  for_each      = toset(var.eks_iam_user)
  cluster_name  = var.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::${local.account_id}:user/${each.value}"

  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.eks_iam_user_access_entry]
}