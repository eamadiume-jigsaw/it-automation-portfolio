# Terraform CI/CD Pipeline (GitHub Actions + OIDC)

A GitHub Actions pipeline that validates, plans, and applies Terraform changes to AWS automatically — with no stored credentials, a mandatory manual approval gate before anything touches production, and branch protection that stops changes from merging unless the pipeline passes.

## The problem

Every change to cloud infrastructure should go through a controlled, auditable process that prevents unauthorized or untested changes from reaching production — not a person manually running `terraform apply` from their own machine, using whatever credentials happen to be configured locally.

## Architecture

Push / Pull Request
|
Validate (fmt check, terraform validate)
|
Plan (terraform plan, OIDC auth, result commented on PR)
|
[ PR merged to main ]
|
Apply (waits for manual approval on the "production" environment)
|
Terraform applies against AWS


## Design: no stored AWS credentials

The pipeline authenticates to AWS via **OIDC federation**, not a stored access key. GitHub issues a short-lived token proving "this exact workflow, in this exact repo" is who it claims to be; an IAM OIDC identity provider and a role with a trust policy scoped to this specific repository grant temporary access for the duration of the job only. Nothing is stored in GitHub Secrets, nothing to rotate, nothing that can leak from a secrets store.

IAM OIDC Provider (trusts token.actions.githubusercontent.com)
|
IAM Role: github-actions-terraform-role
Trust policy condition: repo:eamadiume-jigsaw/it-automation-portfolio:*
Permissions: same least-privilege policy used across the AWS portfolio projects


## Design: staged jobs, not one script

`Validate`, `Plan`, and `Apply` are separate GitHub Actions **jobs**, not steps in one job. Each stage's logs are independently visible in the run history, and `needs:` dependencies mean a failure at any stage blocks the next one from running at all — `Plan` never runs if `Validate` fails; `Apply` never runs if `Plan` fails.

## Design: the actual approval gate

`Apply` targets a GitHub **Environment** named `production`, configured with a required reviewer. Any job referencing that environment pauses and waits for an explicit approval click — even a fully passing plan cannot silently apply itself. Branch protection on `main` separately requires the `Validate` and `Plan` checks to pass before a pull request can even be merged, so a broken change can't reach `main` in the first place.

**Known limitation**: GitHub does not allow self-approval of a pull request one authored, and this is a solo project with no second reviewer. Branch protection was adjusted to allow self-merge for demonstration purposes; in a real team, a second person would review and approve, and self-merge would remain blocked.

## Real problems hit and fixed

**Hardcoded AWS CLI profile broke CI.** The Terraform config originally specified `profile = "cloud-engineer-scoped"` for local use. GitHub Actions has no such named profile — it authenticates via OIDC-issued environment variables instead. Fixed by removing the hardcoded profile, letting the AWS provider pick up whatever credentials are present in the environment, which works correctly both locally (falls back to the default profile) and in CI (uses the OIDC-issued session).

**A truncated workflow file silently skipped steps.** After editing the `apply` job to add credential and Terraform steps, a paste error left the file cut off mid-job. The job still reported "success" in 4 seconds, having only run its first two steps (checkout only) — because a job with no remaining steps to fail simply completes. This was only caught by opening the raw workflow file on GitHub and confirming every expected step was actually present, rather than trusting the green checkmark in the run summary.

**Missing remote backend caused orphaned infrastructure.** The first successful `Apply` ran using Terraform's default local state — inside a GitHub Actions runner, which is destroyed the moment the job ends. Real AWS resources (VPC, EC2, RDS) were created, but the state file describing them vanished with the runner, leaving Terraform with no record of what it had built. Fixed by adding an S3 backend with native state locking (`use_lockfile`), so every apply — local or CI — reads and writes the same persistent, locked state file. The orphaned resources from the earlier run had to be identified and removed manually via AWS CLI before the fix could be verified cleanly.

## Setup

1. Create an IAM OIDC identity provider trusting `token.actions.githubusercontent.com`
2. Create an IAM role with a trust policy scoped to `repo:<owner>/<repo>:*`, and attach a least-privilege permissions policy
3. Create an S3 bucket for remote state (versioned, public access blocked)
4. Add the `backend "s3"` block to the Terraform config, pointing at that bucket
5. Add the workflow file at `.github/workflows/terraform-ci-cd.yml`
6. Create a `production` GitHub Environment with a required reviewer
7. Add a branch protection rule on `main` requiring the `Validate` and `Plan` checks to pass

## Result

A push or pull request automatically triggers validation and a plan; a merge to `main` triggers an apply that pauses for explicit human approval before touching real infrastructure; and a broken or unreviewed change cannot reach `main` at all. Verified end-to-end multiple times, including recovering from each of the three failures documented above.