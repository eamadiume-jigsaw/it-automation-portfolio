# --- Route 53 ----------------------------------------------------------------
# Domain is registered at Namecheap; its nameservers point at this zone.
resource "aws_route53_zone" "site" {
  name    = "eamadiume.com"
  comment = "" # live zone has no comment; the provider would otherwise add "Managed by Terraform"

  lifecycle {
    prevent_destroy = true
  }
}

# Alias records: apex and www both point at the CloudFront distribution.
resource "aws_route53_record" "apex_a" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "eamadiume.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "apex_aaaa" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "eamadiume.com"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_a" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "www.eamadiume.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# IPv6 for www, matching the apex (CloudFront has IPv6 enabled).
resource "aws_route53_record" "www_aaaa" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "www.eamadiume.com"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# ACM DNS-validation records. They must stay in place so the certificate
# keeps auto-renewing.
resource "aws_route53_record" "cert_validation_apex" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "_9f50735cbef9abec119e13f33da2b108.eamadiume.com"
  type    = "CNAME"
  ttl     = 300
  records = ["_31f9b2a6ee26e9f0425732c66d1e203a.jkddzztszm.acm-validations.aws."]
}

resource "aws_route53_record" "cert_validation_www" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "_2d52ef410063be12245da163d092ef5d.www.eamadiume.com"
  type    = "CNAME"
  ttl     = 300
  records = ["_001609ab6ce8e4707c8c60fdd2e404ff.jkddzztszm.acm-validations.aws."]
}
