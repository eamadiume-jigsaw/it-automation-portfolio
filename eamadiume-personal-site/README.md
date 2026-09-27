# Personal Portfolio Site: eamadiume.com

A single-file static portfolio site on AWS (S3, CloudFront, ACM, Route 53). It is **fully managed by Terraform** and **deployed automatically by GitHub Actions** through OIDC, with no stored AWS keys. It was first built by hand in the console, then brought under Terraform with a proven zero-change import.

**Live**: [eamadiume.com](https://eamadiume.com)

```
 git push to main ──▶ GitHub Actions (deploy-site.yml)
                        │  OIDC → github-actions-site-deploy-role
                        │  1. sanity-check page   2. s3 cp   3. invalidate   4. verify live hash
                        ▼
 visitor ──HTTPS──▶ CloudFront (ACM cert, us-east-1) ──OAC──▶ S3 eamadiume-site (private, versioned)
    ▲
    └── Route 53: eamadiume.com / www → A + AAAA alias → CloudFront

 Everything above except the workflow run is defined in infra/ (Terraform, S3 remote state)
```

## Why this architecture, not EC2

A landing page is static content: HTML, CSS and a little JS, with no server-side processing. EC2 plus a load balancer would cost roughly $20+/month for infrastructure the content doesn't need. S3 + CloudFront is the standard AWS pattern for static hosting. There's no server to patch or pay for hourly, HTTPS is free and built into CloudFront, and the cost is under $1/month for a low-traffic personal site.

## Architecture

- **S3** stores the site with all public access blocked. **Versioning** is on, so every deploy keeps the previous page for rollback; old versions expire after 30 days.
- **CloudFront** serves the site from edge locations and is the only thing allowed to read the bucket, via Origin Access Control (OAC).
- **ACM** provides the TLS certificate. It lives in `us-east-1` because CloudFront only accepts certificates from there, and renews automatically through DNS validation records in Route 53.
- **Route 53** hosts DNS for a domain registered at Namecheap (nameservers delegated). Both the apex and `www` have IPv4 (`A`) and IPv6 (`AAAA`) alias records to CloudFront.

## Design: private bucket, CDN-only access

The bucket has **Block Public Access fully enabled**. CloudFront is granted read access by a bucket policy scoped to this one distribution's ARN (in Terraform, the ARN is a reference, not a hardcoded string):

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

This is the recommended Origin Access Control pattern, rather than the older approach of making the bucket public. Nobody can read the bucket directly, only through CloudFront.

## Continuous deployment: GitHub Actions with OIDC

[`.github/workflows/deploy-site.yml`](../.github/workflows/deploy-site.yml) runs whenever `index.html` (or the workflow itself) changes on `main`, and can also be run manually.

| Step | What it does | Why |
|---|---|---|
| Sanity check | Fails if the page is empty or has no `</html>` | Catches a truncated file before it goes live |
| OIDC sign-in | Assumes `github-actions-site-deploy-role` with a short-lived token | No AWS keys stored in GitHub |
| Upload | `aws s3 cp` with `text/html` content type and a 5-minute cache header | |
| Invalidate | Clears `/` and `/index.html` in CloudFront and **waits** for completion | Visitors get the new page immediately |
| Verify | Fetches `https://eamadiume.com` and compares its SHA-256 to the committed file, retrying up to 6 times | The run only passes if the live site is serving *this exact commit* |

Deploys never overlap (`concurrency` group), so two quick pushes can't race each other.

### The deploy role is deliberately tiny

`github-actions-site-deploy-role` is separate from the Terraform CI role and far narrower:

- **Trust:** only `repo:eamadiume-jigsaw/it-automation-portfolio:ref:refs/heads/main`. Pull requests, other branches and forks cannot assume it.
- **Permissions:** `s3:PutObject` on the single object `eamadiume-site/index.html`, plus `cloudfront:CreateInvalidation`/`GetInvalidation` on this one distribution. It cannot read, list or delete anything, and cannot touch DNS, the certificate or the distribution's settings.

The role, its trust policy and the reused GitHub OIDC provider are defined in the IAM project ([`aws-secure-web-app-case-study/iam/main.tf`](../aws-secure-web-app-case-study/iam/main.tf)), which is applied with admin credentials. The CI pipeline can't grant itself more access.

## Infrastructure as Code: adopting the live site into Terraform

The site was originally built by hand. It is now fully managed in [`infra/`](infra/), adopted **without recreating or changing anything**:

1. Wrote only Terraform `import` blocks for the 12 live resources: bucket, public-access block, bucket policy, OAC, distribution, ACM certificate (in `us-east-1`), hosted zone, and five DNS records.
2. Ran `terraform plan -generate-config-out=generated.tf` so Terraform read each live resource and wrote matching configuration.
3. Cleaned the output into `s3.tf`, `cloudfront.tf`, `acm.tf` and `dns.tf`. Hardcoded IDs became references, and `prevent_destroy` was added to the bucket, distribution, certificate and zone.
4. Iterated until the plan read **"12 to import, 0 to add, 0 to change, 0 to destroy"**, applied it, and confirmed `No changes. Your infrastructure matches the configuration.`

Only then were deliberate changes made, each as its own reviewed plan: bucket versioning with 30-day expiry of old versions, the missing `www` IPv6 record, and `Project`/`ManagedBy` tags via the provider's `default_tags`.

State is stored in S3 with native lockfile locking (`eamadiume-cicd-tfstate`, key `eamadiume-site/terraform.tfstate`). Day-to-day Terraform runs use the scoped `cloud-engineer-scoped` user, not an admin.

### Least privilege for the humans too

The scoped user's site permissions live in their own managed policy, `cloud-engineer-site-policy`. It is scoped to this one distribution, OAC, hosted zone and certificate, with **no delete permissions on any of them**. Combined with `prevent_destroy`, neither a Terraform mistake nor the deploying identity can take the site down.

### Cost guardrail

An account-wide AWS Budget (`monthly-account-budget`, $10/month) emails at **$5 actual**, **$10 actual** and when the **forecast** exceeds $10. It's defined in the admin-applied IAM project rather than here, so the scoped user can't change its own spending alarm. The alert address is a Terraform variable, so it isn't committed to the public repo.

## Problems hit, and how they were resolved

**Original console build**

- **Free plan can't register domains through Route 53.** The domain was registered at Namecheap instead, with nameservers delegated to a Route 53 hosted zone.
- **`AccessDenied` despite a correct bucket policy and OAC.** The uploaded file was named `index_8.html` rather than `index.html`, so the default root object didn't exist. S3 returns `AccessDenied` rather than `NotFound` when the caller can't list the bucket, which is misleading. Fixed by renaming the object.
- **`www` returned 403 after the apex worked.** `www` was missing from the distribution's alternate domain names, even though the certificate covered it and DNS already resolved to CloudFront.

**Terraform import**

- **Config generation produced invalid Route 53 records.** Alias records came out with `records` and `ttl` alongside the `alias` block, and CNAMEs got `multivalue_answer_routing_policy` without a `set_identifier`. Those resources were hand-written.
- **Provider defaults showing up as drift.** The zone had no comment, but the provider defaults an unset comment to "Managed by Terraform". Setting `comment = ""` matched the live zone. Tags were held back for the same reason until the import was proven change-free.
- **Repo copy of the site was stale.** The committed `index.html` was an older draft than the live one in S3. Deploying from git would have silently rolled the site back, so the live file was pulled into git before the pipeline was enabled.

**IAM**

- **Managed policy size limit.** Adding the site permissions to the existing deployer policy failed with `LimitExceeded: Cannot exceed quota for PolicySize: 6144`. Split into a separate site policy.
- **Two copies of the IAM config.** The IAM project was being applied from a folder outside the repo, and the repo copy had drifted into an unapplied draft. That was only caught because the repo folder had no state file, and a diff against the applied folder showed the difference. The repo copy is now synced to exactly what's applied.

**CI/CD**

- **Deprecated Node.js 20 actions.** `actions/checkout@v4` and `aws-actions/configure-aws-credentials@v4` triggered deprecation warnings. `configure-aws-credentials@v5` still targeted Node 20; `@v6` is the Node 24 release. Both workflows now use `checkout@v5` and `configure-aws-credentials@v6`.

## Working on the site

- **Change the page:** edit `index.html`, open a PR, merge. The pipeline deploys and verifies it.
- **Change infrastructure:** `cd infra`, set `$env:AWS_PROFILE = "cloud-engineer-scoped"`, then `terraform plan` and review before `terraform apply`.
- **Roll back a bad deploy:** revert the commit (the pipeline redeploys the previous page), or restore the prior S3 object version within 30 days.

## Site design notes

Built as a single self-contained HTML file (no build step, no framework) with a terminal/infrastructure-as-code visual theme. The About section renders as a mock `terraform plan` output describing the author as a resource block, grounded in the actual subject matter rather than generic portfolio copy.
