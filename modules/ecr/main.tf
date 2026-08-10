resource "aws_ecr_repository" "ecr" {
  for_each             = toset(var.ms_name)
  name                 = "${var.project}-${each.key}-microservice-${var.environment}"
  image_tag_mutability = "MUTABLE"
  #   encryption_configuration {
  #     encryption_type = "KMS"
  #   }
  image_scanning_configuration {
    scan_on_push = false
  }
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_ecr_repository" "ecr_pp" {
  for_each             = toset(var.ms_name)
  name                 = "${var.project}-${each.key}-microservice-${var.cls_environment}"
  image_tag_mutability = "MUTABLE"
  #   encryption_configuration {
  #     encryption_type = "KMS"
  #   }
  image_scanning_configuration {
    scan_on_push = false
  }
  tags = {
    Project         = var.project
    environment     = var.environment
    cls_environment = var.cls_environment
    Tier            = var.tier
    CreatedBy       = "terraform"
  }
}
# data "aws_ecr_lifecycle_policy_document" "ecr_policy_document" {
#   rule {
#     priority    = 1
#     description = "managed by Terraform"

#     selection {
#       tag_status      = "any"
#       # tag_prefix_list = ["latest"]
#       count_type      = "imageCountMoreThan"
#       count_number    = 10
#     }
#   }
# }

# resource "aws_ecr_lifecycle_policy" "ecr_lifecycle_policy" {
#   for_each = toset(var.ms_name)
#   repository = aws_ecr_repository.ecr[each.key].name
#   policy = data.aws_ecr_lifecycle_policy_document.ecr_policy_document.json
# }
# resource "aws_ecr_lifecycle_policy" "ecr_lifecycle_policy_pp" {
#  for_each = toset(var.ms_name)
#  repository = aws_ecr_repository.ecr_pp[each.key].name
#  policy = data.aws_ecr_lifecycle_policy_document.ecr_policy_document.json
# }