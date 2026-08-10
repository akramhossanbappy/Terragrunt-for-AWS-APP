# This resource forces creation of the required service-linked role before OpenSearch domain is created.
resource "null_resource" "create_opensearch_service_linked_role" {
  provisioner "local-exec" {
    command = <<EOT
      aws iam create-service-linked-role --aws-service-name opensearchservice.amazonaws.com || echo "Service-linked role already exists or cannot be created in this context"
    EOT
  }
}
resource "aws_opensearch_domain" "opensearch_domain" {
  domain_name    = "${var.project}-os-${var.environment}" # Duo to char limit reduce env name
  engine_version = "Elasticsearch_7.10"
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.os_db_user
      master_user_password = var.os_db_password
    }
  }
  encrypt_at_rest {
    enabled = true
  }
  domain_endpoint_options {
    custom_endpoint_enabled = false
    enforce_https           = true
    tls_security_policy     = "Policy-Min-TLS-1-2-2019-07"
  }
  node_to_node_encryption {
    enabled = true
  }

  cluster_config {
    dedicated_master_enabled = var.opensearch_dedicated_master_enabled
    dedicated_master_count   = var.opensearch_dedicated_master_enabled ? var.opensearch_dedicated_master_count : null
    dedicated_master_type    = var.opensearch_dedicated_master_enabled ? var.opensearch_dedicated_master_type : null
    instance_count           = var.opensearch_instance_count
    instance_type            = var.opensearch_instance_type
    zone_awareness_enabled   = var.opensearch_zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = var.opensearch_zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.opensearch_availability_zone_count
      }
    }
  }
  vpc_options {
    subnet_ids         = var.opensearch_zone_awareness_enabled ? slice(var.secure_subnets, 0, var.opensearch_availability_zone_count) : [element(var.secure_subnets, 0)]
    security_group_ids = [var.secure_sg_id]
  }
  ebs_options {
    ebs_enabled = true
    volume_size = var.opensearch_volume_size # Specify the size of the EBS volume in GB
    volume_type = var.opensearch_volume_type # Specify the EBS volume type
  }
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }

}
data "aws_iam_policy_document" "opensearch_policy" {
  version = "2012-10-17"

  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["es:*"]
    resources = ["${aws_opensearch_domain.opensearch_domain.arn}/*"]
  }
}
resource "aws_opensearch_domain_policy" "opensearch_domain_policy" {
  domain_name     = aws_opensearch_domain.opensearch_domain.domain_name
  access_policies = data.aws_iam_policy_document.opensearch_policy.json
}

# resource "aws_elasticsearch_vpc_endpoint" "endpoint" {
#   domain_arn = aws_opensearch_domain.opensearch_domain.arn
#   vpc_options {
#     security_group_ids = [var.secure_sg_id]
#     # subnet_ids         = ["${var.secure_sg_id[0]}","${var.secure_sg_id[1]}"]
#     subnet_ids       = var.secure_subnets

#   }
# }