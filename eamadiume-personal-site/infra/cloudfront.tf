# --- CloudFront --------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "oac-eamadiume-site.s3.eu-west-2.amazonaws.com-msukihn29wc"
  description                       = "Created by CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  s3_origin_id = "eamadiume-site.s3.eu-west-2.amazonaws.com-msudrcyo37g"
}

resource "aws_cloudfront_distribution" "site" {
  aliases             = ["eamadiume.com", "www.eamadiume.com"]
  default_root_object = "index.html"
  enabled             = true
  http_version        = "http2"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"

  tags = {
    Name = "eamadiume-dis"
  }

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
    connection_attempts      = 3
    connection_timeout       = 10
  }

  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # AWS managed: CachingOptimized

    # TTLs are governed by the cache policy; kept at 0 to match the live config.
    default_ttl = 0
    max_ttl     = 0
    min_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.site.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  lifecycle {
    prevent_destroy = true
  }
}
