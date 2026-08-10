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
# resource "aws_s3_bucket_website_configuration" "s3_static_bucket_website" {
#   for_each = toset(var.s3_bucket)
#   bucket = aws_s3_bucket.s3_static_bucket[each.key].id

#   index_document {
#     suffix = "index.html"
#   }
#   error_document {
#     key = "error.html"
#   }
# }

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  for_each                = toset(var.s3_bucket)
  bucket                  = aws_s3_bucket.s3_static_bucket[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# resource "aws_s3_bucket_policy" "s3_static_bucket_policy" {
#   for_each = toset(var.s3_bucket)
#   bucket = aws_s3_bucket.s3_static_bucket[each.key].id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Sid       = "AllowGetObject"
#       Effect    = "Allow"
#       Principal = "*"
#       Action    = "s3:GetObject"
#       Resource  = "${aws_s3_bucket.s3_static_bucket[each.key].arn}/*"
#     }]
#   })
# }

resource "aws_s3_bucket_acl" "s3_static_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.bucket_ownership,
    aws_s3_bucket_public_access_block.public_access_block,
  ]
  bucket   = aws_s3_bucket.s3_static_bucket[each.key].id
  for_each = toset(var.s3_bucket)

  acl = "private"
}

#CloudFront Distribution
resource "aws_cloudfront_origin_access_identity" "site_identity" {
  for_each = toset(var.s3_bucket)
  comment  = "${each.key} CloudFront OAI"
}

data "aws_iam_policy_document" "portal_frontend_origin" {
  for_each = toset(var.s3_bucket)

  statement {
    sid       = "S3GetObjectForCloudfront"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.s3_static_bucket[each.key].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.site_identity[each.key].iam_arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.s3_static_bucket[each.key].arn,
      "${aws_s3_bucket.s3_static_bucket[each.key].arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_portal_frontend_cloudfront" {
  for_each = toset(var.s3_bucket)
  bucket   = aws_s3_bucket.s3_static_bucket[each.key].id
  policy   = data.aws_iam_policy_document.portal_frontend_origin[each.key].json
}

resource "aws_cloudfront_distribution" "site_s3_distribution" {
  for_each = toset(var.s3_bucket)

  origin {
    domain_name = aws_s3_bucket.s3_static_bucket[each.key].bucket_regional_domain_name
    origin_id   = "${each.key}-origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.site_identity[each.key].cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"
  web_acl_id          = var.web_acl_id != "" ? var.web_acl_id : null

  # Custom aliases require a valid ACM cert in us-east-1; omit when cert is not set.
  # When cdn_extra_aliases has an entry for this bucket, use that list exclusively.
  # Otherwise default to the bucket name itself as the single alias.
  aliases = var.acm_cert_arn_static != "" ? lookup(var.cdn_extra_aliases, each.key, [each.key]) : []

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${each.key}-origin"

    forwarded_values {
      query_string = true
      headers      = []
      cookies {
        forward = "all"
      }
    }

    # viewer_protocol_policy = "redirect-to-https"   # Enable this while have ssl certificate 
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }

  viewer_certificate {
    # Falls back to CloudFront's default *.cloudfront.net cert when no ACM cert is
    # provided (acm_cert_arn_static = ""). Set acm_cert_arn_static to a valid
    # us-east-1 ACM cert ARN covering the domain aliases to enable HTTPS with a
    # custom domain. When the cert is set, aliases above are also enabled.
    cloudfront_default_certificate = var.acm_cert_arn_static == "" ? true : false
    acm_certificate_arn            = var.acm_cert_arn_static != "" ? var.acm_cert_arn_static : null
    ssl_support_method             = var.acm_cert_arn_static != "" ? "sni-only" : null
    minimum_protocol_version       = var.acm_cert_arn_static != "" ? "TLSv1.2_2021" : null
  }

  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 403
    response_code         = 200
    response_page_path    = "/"
  }
}
