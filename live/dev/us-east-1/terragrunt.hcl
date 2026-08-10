# Region root for development us-east-1 units.
#
# Terminal config (no include blocks) — Terragrunt auto-loads parent
# terragrunt.hcl files, so live/terragrunt.hcl and dev/terragrunt.hcl
# are picked up automatically by units under this directory.
#
# Services under this directory get a region-specific AWS provider
# generated here; the env root (dev/terragrunt.hcl) provides the S3
# backend state and the shared locals.

locals {
  region     = "us-east-1"
  aws_region = "us-east-1"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.94.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
EOF
}
