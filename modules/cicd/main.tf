resource "aws_s3_bucket" "s3-bucket-backend" {
  bucket = var.pipeline_s3_bucket_name
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "s3-bucket-backend-versioning" {
  bucket = aws_s3_bucket.s3-bucket-backend.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_object" "codebuild_folder" {
  bucket = aws_s3_bucket.s3-bucket-backend.id
  key    = "codebuild_artifact/"
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_s3_object" "codepipeline_folder" {
  bucket = aws_s3_bucket.s3-bucket-backend.id
  key    = "codepipeline_artifact/"
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "codebuild-policy-document" {
  statement {
    actions   = ["logs:*"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.s3-bucket-backend.arn}/*",
      "${aws_s3_bucket.s3-bucket-backend.arn}"
    ]
    effect = "Allow"
  }
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["ecr:*"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "codeartifact:GetAuthorizationToken",
      "codeartifact:GetRepositoryEndpoint",
      "codeartifact:ReadFromRepository",
      "codeartifact:PublishPackageVersion"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "sts:GetServiceBearerToken"
    ]
    resources = ["*"]
    effect    = "Allow"

    condition {
      test     = "StringEquals"
      variable = "sts:AWSServiceName"

      values = [
        "codeartifact.amazonaws.com"
      ]
    }
  }

  # WAF — required for module.waf-alb (WebACL, IP sets, ALB association, logging)
  statement {
    actions   = ["wafv2:*"]
    resources = ["*"]
    effect    = "Allow"
  }

  # CloudWatch log resource policy — required for WAF log group policy
  statement {
    actions = [
      "logs:PutResourcePolicy",
      "logs:DeleteResourcePolicy",
      "logs:DescribeResourcePolicies"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "codebuild-policy" {
  name   = "${var.project}-codebuild-policy-${var.environment}"
  path   = "/"
  policy = data.aws_iam_policy_document.codebuild-policy-document.json
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_role" "codebuild-role" {
  name = "${var.project}-codebuild-role-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
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

resource "aws_iam_role_policy_attachment" "codebuild-policy-attachment1" {
  policy_arn = aws_iam_policy.codebuild-policy.arn
  role       = aws_iam_role.codebuild-role.id
}

resource "aws_iam_role_policy_attachment" "codebuild-s3-full-access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.codebuild-role.id
}
resource "aws_iam_role_policy_attachment" "codebuild-policy-attachment2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
  role       = aws_iam_role.codebuild-role.id
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "codepipeline-policy-document" {
  statement {
    actions   = ["cloudwatch:*"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = ["codebuild:*"]
    resources = [
      "arn:aws:codebuild:${var.aws_region}:${local.account_id}:project/${var.project}-codebuild-project-${var.environment}",
      "arn:aws:codebuild:${var.aws_region}:${local.account_id}:project/${var.project}-codebuild-project-${var.cls_environment}"
    ]
    effect = "Allow"
  }
  statement {
    actions   = ["codecommit:*"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["ecr:*"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.s3-bucket-backend.arn}/*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["codestar-connections:UseConnection"]
    resources = ["*"]
    effect    = "Allow"

  }
}

resource "aws_iam_policy" "codepipeline-policy" {
  name   = "${var.project}-codepipeline-policy-${var.environment}"
  path   = "/"
  policy = data.aws_iam_policy_document.codepipeline-policy-document.json
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_role" "codepipeline-role" {
  name = "${var.project}-codepipeline-role-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
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

resource "aws_iam_role_policy_attachment" "codepipeline-policy-attachment" {
  policy_arn = aws_iam_policy.codepipeline-policy.arn
  role       = aws_iam_role.codepipeline-role.id
}

resource "aws_codebuild_project" "codebuild_project_plan_stage" {
  name         = "${var.project}-codebuild-project-${var.environment}"
  description  = "Terraform Planning Stage for infra VPC"
  service_role = aws_iam_role.codebuild-role.arn
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    dynamic "environment_variable" {
      for_each = [
        for ms in var.ms_name : {
          name  = "${replace(upper(ms), "-", "_")}_ECR_REPO"
          value = "${var.project}-${ms}-microservice-${var.environment}"
        }
      ]
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
      }
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "ENVNAME"
      value = ".env.production"
    }
    environment_variable {
      name  = "BUILD_ENV"
      value = var.environment
    }
    environment_variable {
      name  = "docker_password"
      value = "Digi@channel#2024"
    }
    environment_variable {
      name  = "docker_user"
      value = "digital.channels@rventuresplc.com"
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yaml"
  }
  # Local cache configuration
  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }

}
resource "aws_codebuild_project" "codebuild_project_plan_stage_pp" {
  name         = "${var.project}-codebuild-project-${var.cls_environment}"
  description  = "Terraform Planning Stage for infra VPC"
  service_role = aws_iam_role.codebuild-role.arn
  tags = {
    Project         = var.project
    environment     = var.environment
    cls_environment = var.cls_environment
    Tier            = var.tier
    CreatedBy       = "terraform"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    dynamic "environment_variable" {
      for_each = [
        for ms in var.ms_name : {
          name  = "${replace(upper(ms), "-", "_")}_ECR_REPO"
          value = "${var.project}-${ms}-microservice-${var.cls_environment}"
        }
      ]
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
      }
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "ENVNAME"
      value = ".env.preprod"
    }
    environment_variable {
      name  = "BUILD_ENV"
      value = var.cls_environment
    }
    environment_variable {
      name  = "docker_password"
      value = "Digi@channel#2024"
    }
    environment_variable {
      name  = "docker_user"
      value = "digital.channels@rventuresplc.com"
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yaml"
  }

  # Local cache configuration
  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }

}
resource "aws_codepipeline" "codepipeline" {
  for_each      = toset(var.github_repository)
  name          = "${var.project}-codepipeline-${each.key}-microservice-${var.environment}"
  pipeline_type = "V2"
  role_arn      = aws_iam_role.codepipeline-role.arn
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.s3-bucket-backend.bucket
  }

  stage {
    name = "Source"

    action {
      category = "Source"
      configuration = {
        "BranchName"           = var.github_branch
        "ConnectionArn"        = var.github_codeconnection_arn
        "DetectChanges"        = "false"
        "FullRepositoryId"     = "${var.github_workspace}/${each.value}"
        "OutputArtifactFormat" = "CODE_ZIP"
      }
      input_artifacts = []
      name            = "Source"
      namespace       = null
      output_artifacts = [
        "pipeline_output_artifact",
      ]
      owner     = "AWS"
      provider  = "CodeStarSourceConnection"
      region    = var.aws_region
      role_arn  = null
      run_order = 1
      version   = "1"
    }
  }

  stage {
    name = "Approval"
    action {
      name      = "Approval"
      category  = "Approval" # Approval only disabled for production branch
      owner     = "AWS"
      provider  = "Manual"
      run_order = "1"
      version   = "1"
    }
  }

  # stage {
  #     name ="Sonar-Build"
  #     action{
  #         name = "Sonar-Build"
  #         category = "Build"
  #         provider = "CodeBuild"
  #         version = "1"
  #         owner = "AWS"
  #         input_artifacts = ["pipeline_output_artifact"]
  #         output_artifacts = ["Sonar_output_artifact"]
  #         configuration = {
  #             ProjectName = aws_codebuild_project.codebuild_project_plan_stage.name
  #             BuildspecOverride = "buildspec-sonarqube.yml"
  #         }
  #     }
  # }

  stage {
    name = "Build"
    action {
      name            = "Build"
      category        = "Build"
      provider        = "CodeBuild"
      version         = "1"
      owner           = "AWS"
      input_artifacts = ["pipeline_output_artifact"]
      configuration = {
        ProjectName = aws_codebuild_project.codebuild_project_plan_stage.name
      }
    }
  }

  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "Source"

      push {
        branches {
          includes = [
            var.github_branch,
          ]
        }
      }
    }
  }
}
resource "aws_codepipeline" "codepipeline_pp" {
  for_each      = toset(var.github_repository)
  name          = "${var.project}-codepipeline-${each.key}-microservice-${var.cls_environment}"
  pipeline_type = "V2"
  role_arn      = aws_iam_role.codepipeline-role.arn
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.s3-bucket-backend.bucket
  }

  stage {
    name = "Source"

    action {
      category = "Source"
      configuration = {
        "BranchName"           = var.github_branch_pp
        "ConnectionArn"        = var.github_codeconnection_arn
        "DetectChanges"        = "false"
        "FullRepositoryId"     = "${var.github_workspace}/${each.value}"
        "OutputArtifactFormat" = "CODE_ZIP"
      }
      input_artifacts = []
      name            = "Source"
      namespace       = null
      output_artifacts = [
        "pipeline_output_artifact",
      ]
      owner     = "AWS"
      provider  = "CodeStarSourceConnection"
      region    = var.aws_region
      role_arn  = null
      run_order = 1
      version   = "1"
    }
  }

  # stage {
  #     name = "Approval"
  #     action{
  #         name = "Approval" 
  #         category = "Approval"  # Approval only disabled for production branch
  #         owner = "AWS"
  #         provider = "Manual"
  #         run_order = "1"
  #         version = "1"
  #     }
  # }
  # stage {
  #     name ="Sonar-Build"
  #     action{
  #         name = "Sonar-Build"
  #         category = "Build"
  #         provider = "CodeBuild"
  #         version = "1"
  #         owner = "AWS"
  #         input_artifacts = ["pipeline_output_artifact"]
  #         output_artifacts = ["Sonar_output_artifact"]
  #         configuration = {
  #             ProjectName = aws_codebuild_project.codebuild_project_plan_stage.name
  #             BuildspecOverride = "buildspec-sonarqube.yml"
  #         }
  #     }
  # }

  stage {
    name = "Build"
    action {
      name            = "Build"
      category        = "Build"
      provider        = "CodeBuild"
      version         = "1"
      owner           = "AWS"
      input_artifacts = ["pipeline_output_artifact"]
      configuration = {
        ProjectName = aws_codebuild_project.codebuild_project_plan_stage_pp.name
      }
    }
  }

  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "Source"

      push {
        branches {
          includes = [
            var.github_branch_pp,
          ]
        }
      }
    }
  }
}
data "aws_iam_policy_document" "cloudwatch-event-policy-document" {
  statement {
    actions   = ["logs:*"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.s3-bucket-backend.arn}/*",
      "${aws_s3_bucket.s3-bucket-backend.arn}"
    ]
    effect = "Allow"
  }
  statement {
    actions = ["codepipeline:StartPipelineExecution"]
    resources = [
      "arn:aws:codepipeline:${var.aws_region}:${local.account_id}:project/${var.project}-codepipeline-*}"
    ]
    effect = "Allow"
  }
  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "cloudwatch-event-policy" {
  name   = "${var.project}-cloudwatch-event-policy-${var.environment}"
  path   = "/"
  policy = data.aws_iam_policy_document.cloudwatch-event-policy-document.json
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_iam_role" "cloudwatch-event-role" {
  name = "${var.project}-cloudwatch-event-role-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
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

resource "aws_iam_role_policy_attachment" "cloudwatch-policy-attachment1" {
  policy_arn = aws_iam_policy.cloudwatch-event-policy.arn
  role       = aws_iam_role.cloudwatch-event-role.id
}

resource "aws_sns_topic" "CodebuildSNSTopic" {
  name = "${var.project}-codebuild-topic-${var.environment}"
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_rule" "Build_EventRule" {
  description   = "Managed By Terraform"
  name          = "${var.project}-build-notification-rule-${var.environment}"
  event_pattern = <<PATTERN
  {
    "source": ["aws.codebuild"],
    "detail-type": ["CodeBuild Build State Change"],
    "detail": {
      "build-status": ["FAILED"],
      "project-name": ["${var.project}-codebuild-project-${var.environment}"]
    }
  }
PATTERN
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "Build_EventRuleTarget" {
  rule      = aws_cloudwatch_event_rule.Build_EventRule.name
  arn       = aws_sns_topic.CodebuildSNSTopic.arn
  target_id = "SendToSNS"

  input_transformer {
    input_paths = {
      "build-id"      = "$.detail.build-id"
      "build-status"  = "$.detail.build-status"
      "current-phase" = "$.detail.current-phase"
      "initiator"     = "$.detail.additional-information.initiator"
      "project-name"  = "$.detail.project-name"
    }

    input_template = <<PATTERN
    {
      "Build Id" : [<build-id>],
      "Build State" : [<build-status>],
      "Project Name" : "project-name"
    }
    PATTERN
  }
}

resource "aws_cloudwatch_event_rule" "ECR_EventRule" {
  description = "Managed By Terraform"
  name        = "${var.project}-ecr-notification-rule-${var.environment}"
  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Action"]
    detail = {
      action-type = ["PUSH"]
      result      = ["SUCCESS"]
      repository-name = flatten([
        [for service in var.ms_name : "${var.project}-${service}-microservice-${var.cls_environment}"],
        [for service in var.ms_name : "${var.project}-${service}-microservice-${var.environment}"]
      ])
    }
  })
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "ECR_EventRuleTarget" {
  rule      = aws_cloudwatch_event_rule.ECR_EventRule.name
  arn       = aws_sns_topic.CodebuildSNSTopic.arn
  target_id = "SentToNotification"

  input_transformer {
    input_paths = {
      "image-tag"       = "$.detail.image-tag"
      "repository-name" = "$.detail.repository-name"
      "result"          = "$.detail.result"
      "time"            = "$.time"
    }

    input_template = <<PATTERN
  {
    "Time": "<time>",
    "Repo Name": "<repository-name>",
    "Image ID": [<image-tag>],
    "Build State": [<result>]
  }
  PATTERN
  }
}

resource "aws_iam_role" "LambdaIamRole" {
  name = "${var.project}-codebuild-notification-lambda-role-${var.environment}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Principal" : {
        "Service" : "lambda.amazonaws.com"
      },
      "Action" : "sts:AssumeRole"
    }]
  })

  # inline_policy {
  #   name = "AWSLambdaAssumeRole"
  #   policy = jsonencode({
  #     "Version" : "2012-10-17",
  #     "Statement": [{
  #       "Effect"   : "Allow",
  #       "Action"   : "*",
  #       "Resource" : "*"
  #     }]
  #   })
  # }
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.LambdaIamRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "lambda_sns_policy" {
  name = "${var.project}-lambda-sns-policy"
  role = aws_iam_role.LambdaIamRole.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "sns:Publish"
        ]

        Resource = "*"
      }
    ]
  })
}
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/index.js"
  output_path = "${path.module}/lambda_function_payload.zip"
}

resource "aws_lambda_function" "codebuild_lambda_function" {
  function_name = "${var.project}-code-build-notification-lambda-${var.environment}"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 5
  role          = aws_iam_role.LambdaIamRole.arn

  environment {
    variables = {
      CHAT_API_PATH = var.ChatWebhook
    }
  }
  # Specify the path to your lambda function code here
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_sns_topic_policy" "MySNSTopicPolicy" {
  arn = aws_sns_topic.CodebuildSNSTopic.arn

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Principal" : {
        "AWS" : "*"
      },
      "Action" : ["sns:Publish", "sns:Subscribe"],
      "Resource" : aws_sns_topic.CodebuildSNSTopic.arn
    }]
  })
}

resource "aws_lambda_permission" "ExampleFunctionInvokePermission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.codebuild_lambda_function.arn
  principal     = "sns.amazonaws.com"
}

resource "aws_sns_topic_subscription" "codebuild_lambda_functionSubscription" {
  topic_arn = aws_sns_topic.CodebuildSNSTopic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.codebuild_lambda_function.arn
}

