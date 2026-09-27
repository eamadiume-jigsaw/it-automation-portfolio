# Personal Portfolio Site — eamadiume.com

A single-file static portfolio site, deployed on AWS using S3, CloudFront, ACM, and Route 53 — chosen deliberately over an EC2-based approach, since a static site doesn't need a running server.

**Live**: [eamadiume.com](https://eamadiume.com)

## Why this architecture, not EC2

A landing page is static content — HTML, CSS, and a small amount of JS, no server-side processing. Running EC2 plus a Load Balancer for that would cost roughly $20+/month for infrastructure the content doesn't need. S3 + CloudFront is the standard, correct AWS pattern for static hosting: no server to patch or pay for hourly, HTTPS is free and built into CloudFront (no Load Balancer required for the certificate, unlike an EC2-based setup), and cost is under $1/month for a low-traffic personal site.

## Architecture-

 **S3** stores the site as a single static file, with all public access explicitly blocked
- **CloudFront** serves the site globally from edge locations and is the only thing allowed to read from the bucket, via Origin Access Control (OAC) — the bucket itself stays private
- **ACM** issues a free TLS certificate, requested in `us-east-1` specifically, since CloudFront only accepts certificates from that region regardless of where other resources live
- **Route 53** manages DNS for a domain registered externally (Namecheap), with nameservers delegated to a Route 53 hosted zone

## Design: private bucket, CDN-only access

The S3 bucket has **Block Public Access fully enabled** — nothing about it is public. Instead, CloudFront is granted read access via a bucket policy scoped specifically to this distribution's ARN:

```json
{
  "Effect": "Allow",
  "Principal": { "Service": "cloudfront.amazonaws.com" },
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::eamadiume-site/*",
  "Condition": {
    "StringEquals": { "AWS:SourceArn": "arn:aws:cloudfront::<account-id>:distribution/<distribution-id>" }
  }
}
```

This is the modern, recommended pattern (Origin Access Control) rather than the older approach of making the bucket itself public — the bucket cannot be accessed directly by anyone, only through CloudFront.

## Deployment

1. Create a private S3 bucket, upload `index.html`
2. Request an ACM certificate in `us-east-1` covering both the root and `www` domains, validate via DNS
3. Create a CloudFront distribution: S3 origin with Origin Access Control, custom SSL certificate, both domains listed under Alternate Domain Names, `index.html` set as the Default Root Object
4. Update the S3 bucket policy with the CloudFront-generated statement
5. Create Route 53 alias records (A + AAAA) for both the root domain and `www`, pointing to the CloudFront distribution

## Infrastructure as Code: adopting the live site into Terraform

The site was originally built by hand in the console. It is now fully managed by Terraform in [`infra/`](infra/), adopted **without recreating or changing anything**:

1. Wrote only Terraform `import` blocks for the 12 live resources: bucket, public-access block, bucket policy, OAC, distribution, ACM certificate (in `us-east-1`), hosted zone, and five DNS records.
2. Ran `terraform plan -generate-config-out=generated.tf` so Terraform read each live resource and wrote matching configuration.
3. Cleaned the output into `s3.tf`, `cloudfront.tf`, `acm.tf` and `dns.tf`. Hardcoded IDs became references (the bucket policy uses the distribution's ARN, DNS aliases use CloudFront's domain name), and `prevent_destroy` was added to the bucket, distribution, certificate and zone.
4. Iterated until the plan read **"12 to import, 0 to add, 0 to change, 0 to destroy"**, applied it, and confirmed `No changes. Your infrastructure matches the configuration.`

State is stored remotely in S3 with native lockfile locking (`eamadiume-cicd-tfstate`, key `eamadiume-site/terraform.tfstate`).

**Problems hit during the import:**

- **Config generation produced invalid Route 53 records.** Alias records were generated with `records` and `ttl` as well as an `alias` block, which the provider rejects, and CNAMEs got a `multivalue_answer_routing_policy` without a `set_identifier`. Fixed by hand-writing those resources.
- **Provider defaults showing up as drift.** The hosted zone had no comment, but the provider defaults an unset comment to "Managed by Terraform", so the first plan wanted to change it. Setting `comment = ""` explicitly matched the live zone. Tags added through the provider's `default_tags` were removed for the same reason, so the import could be proven change-free before any deliberate changes.
- **IAM managed-policy size limit.** Adding the site permissions to the existing deployer policy failed with `LimitExceeded: Cannot exceed quota for PolicySize: 6144`. The site permissions now live in a separate `cloud-engineer-site-policy` attached to the same user. It is scoped to this one distribution, OAC, hosted zone and certificate, with **no delete permissions**, so the deploying identity can manage the site but not take it down.

## Known issues hit during this deployment

- **Root plan cannot register domains through Route 53** — the AWS account's Free plan tier blocks domain registration specifically; the domain was registered externally at Namecheap instead, with nameservers delegated to a Route 53 hosted zone for DNS management.
- **`AccessDenied` despite correct bucket policy and OAC** — root cause was a mismatched object filename: the uploaded file was saved as `index_8.html` rather than `index.html`, so CloudFront's Default Root Object request found nothing matching, and S3 returns `AccessDenied` rather than `NotFound` for unlisted buckets, which is misleading during troubleshooting. Fixed by renaming the object to exactly `index.html`.
- **`www.eamadiume.com` returned 403 after the root domain worked** — the CloudFront distribution's Alternate Domain Names list only included the root domain; `www` needed to be added explicitly even though the ACM certificate already covered both, and DNS was already correctly resolving `www` to CloudFront's edge IPs.

## Site design notes

Built as a single self-contained HTML file (no build step, no framework) with a terminal/infrastructure-as-code visual theme — the About section renders as a mock `terraform plan` output describing the author as a resource block, deliberately grounded in the actual subject matter rather than generic portfolio copy.