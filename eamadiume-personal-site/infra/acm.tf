# --- TLS certificate ---------------------------------------------------------
# Must live in us-east-1: CloudFront only accepts certificates from there.
resource "aws_acm_certificate" "site" {
  provider = aws.us_east_1

  domain_name               = "eamadiume.com"
  subject_alternative_names = ["eamadiume.com", "www.eamadiume.com"]
  validation_method         = "DNS"
  key_algorithm             = "RSA_2048"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    prevent_destroy = true
  }
}
