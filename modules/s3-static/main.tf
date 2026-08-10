resource "aws_s3_bucket" "s3_static_bucket" {
  for_each      = toset(var.s3_bucket)
  bucket        = each.key
  force_destroy = true
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
  for_each = toset(var.s3_bucket)
  bucket   = aws_s3_bucket.s3_static_bucket[each.key].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_website_configuration" "s3_static_bucket_website" {
  for_each = toset(var.s3_bucket)
  bucket   = aws_s3_bucket.s3_static_bucket[each.key].id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  for_each                = toset(var.s3_bucket)
  bucket                  = aws_s3_bucket.s3_static_bucket[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "s3_static_bucket_policy" {
  for_each = toset(var.s3_bucket)
  bucket   = aws_s3_bucket.s3_static_bucket[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.s3_static_bucket[each.key].arn}/*"
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.s3_static_bucket[each.key].arn,
          "${aws_s3_bucket.s3_static_bucket[each.key].arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })
  depends_on = [
    aws_s3_bucket_public_access_block.public_access_block
  ]
}

resource "aws_s3_bucket_acl" "s3_static_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.bucket_ownership,
    aws_s3_bucket_public_access_block.public_access_block,
  ]
  bucket   = aws_s3_bucket.s3_static_bucket[each.key].id
  for_each = toset(var.s3_bucket)

  acl = "public-read"

}
