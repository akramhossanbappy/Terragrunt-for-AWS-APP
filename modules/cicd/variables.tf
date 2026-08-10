variable "project" {
  description = "Project name"
}

variable "environment" {
  description = "Infra environment name"
}
variable "cls_environment" {
  description = "Cluster development environemtn name"
}
variable "tier" {
  description = "infra tier"
}
#AWS region
variable "aws_region" {
  type = string
}


# Create MicroService name
variable "ms_name" {
  type = list(string)
}
#create bucket and repository 
# variable "codecommit_repository" {
#   type = list(string)
# }

# repository Branch
# variable "codecommit_branch" {
#   type = string
# }
# variable "codecommit_branch_pp" {}

variable "pipeline_s3_bucket_name" {
  type = string
}
variable "ChatWebhook" {}
variable "docker_password" {
  sensitive = true
}

#github
variable "github_url" {
  type = string
}
variable "github_workspace" {
  type = string
}
variable "github_repository" {
  type = list(string)
}
variable "github_codeconnection_arn" {
  type = string
}
variable "github_branch" {
  type = string
}
variable "github_branch_pp" {
  type = string
}

#Codebuild,Codepipeline  role,policy,project name 
# variable "codebuild_role_name" {
#     type = string
#     default = "infra-vpc-codebuild-role" 
# }

# variable "codepipeline_role_name" {
#     type = string
#     default = "infra-vpc-codepipeline-role"
# }

# variable "codebuild_policy_name" {
#     type = string
#     default = "infra-vpc-codebuild-policy" 
# }

# variable "codepipeline_policy_name" {
#     type = string
#     default = "infra-vpc-codepipeline-policy"
# }

# variable "codebuild_plan_project_name" {
#     type = string
#     default = "infra-vpc-codebuild-project-plan" 
# }

# variable "codebuild_apply_project_name" {
#     type = string
#     default = "infra-vpc-codebuild-project-apply" 
# }

# variable "codepipeline_name" {
#     type = string
#     default = "infra-vpc-codepipeline" 
# }

#Cloudwatch event  role,policy,rule name 
# variable "cloudwatch_event_role_name" {
#     type = string
#     default = "infra-vpc-codewatch-event-role" 
# }

# variable "cloudwatch_event_policy_name" {
#     type = string
#     default = "infra-vpc-codewatch-event-policy" 
# }


# variable "cloudwatch_event_rule_name" {
#     type = string
#     default = "infra-vpc-codewatch-event-rule" 
# }

