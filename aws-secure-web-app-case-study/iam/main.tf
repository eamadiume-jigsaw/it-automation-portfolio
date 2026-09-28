terraform {
  # Remote state (migrated from a local file). Contains no secrets: the user
  # access key is intentionally not managed here.
  backend "s3" {
    bucket       = "eamadiume-cicd-tfstate"
    key          = "iam/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

resource "aws_iam_policy" "cloud_engineer_scoped" {
  name        = "cloud-engineer-project-policy"
  description = "Least-privilege policy scoped to specific actions needed for VPC/EC2/RDS/S3 project work"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2NetworkingAndCompute"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs", "ec2:ModifyVpcAttribute",
          "ec2:DescribeVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway", "ec2:DescribeInternetGateways",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:DescribeRouteTables",
          "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses",
          "ec2:DescribeAddressesAttribute", "ec2:DisassociateAddress",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeAvailabilityZones",
          "ec2:RunInstances", "ec2:TerminateInstances", "ec2:StopInstances", "ec2:StartInstances",
          "ec2:DescribeInstances", "ec2:DescribeInstanceTypes", "ec2:DescribeImages",
          "ec2:DescribeInstanceAttribute", "ec2:DescribeInstanceCreditSpecifications",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeVolumes", "ec2:DescribeVolumeAttribute",
          "ec2:DescribeNetworkInterfaces", "ec2:DescribeNetworkInterfaceAttribute",
          "ec2:CreateKeyPair", "ec2:DeleteKeyPair", "ec2:DescribeKeyPairs",
          "ec2:CreateTags", "ec2:DeleteTags", "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance", "rds:DeleteDBInstance", "rds:ModifyDBInstance",
          "rds:DescribeDBInstances", "rds:DescribeDBSnapshots",
          "rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup", "rds:DescribeDBSubnetGroups",
          "rds:AddTagsToResource", "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket", "s3:ListBucket", "s3:ListAllMyBuckets",
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:PutBucketVersioning", "s3:GetBucketVersioning",
          "s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketTagging", "s3:PutBucketTagging",
          "s3:GetBucketPolicy", "s3:GetBucketAcl", "s3:GetBucketCORS",
          "s3:GetBucketWebsite", "s3:GetBucketLogging", "s3:GetBucketRequestPayment",
          "s3:GetBucketObjectLockConfiguration", "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration",
          "s3:GetAccelerateConfiguration"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchReadAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBStateLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:DescribeTable",
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:eu-west-2:751835847368:table/terraform-locks"
      },
      {
        Sid    = "IncidentApiDynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:DescribeTable",
          "dynamodb:TagResource", "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeTimeToLive", "dynamodb:ListTagsOfResource"
        ]
        Resource = "arn:aws:dynamodb:eu-west-2:751835847368:table/incident-api-*"
      },
         {
        Sid    = "IncidentApiLambda"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:DeleteFunction", "lambda:GetFunction",
          "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission", "lambda:RemovePermission", "lambda:GetPolicy",
          "lambda:ListVersionsByFunction", "lambda:TagResource",
          "lambda:GetFunctionCodeSigningConfig"
        ]
        Resource = "arn:aws:lambda:eu-west-2:751835847368:function:incident-api-*"
      },
      {
        Sid    = "IncidentApiApiGateway"
        Effect = "Allow"
        Action = [
          "apigateway:GET", "apigateway:POST", "apigateway:PUT",
          "apigateway:DELETE", "apigateway:PATCH"
        ]
        Resource = "arn:aws:apigateway:eu-west-2::/*"
      },
      {
        Sid    = "IncidentApiIAMRolesCreateDelete"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:PassRole"
        ]
        Resource = "arn:aws:iam::751835847368:role/incident-api-*"
        Condition = {
          StringEquals = {
            "iam:PermissionsBoundary" = "arn:aws:iam::751835847368:policy/incident-api-lambda-boundary"
          }
        }
      },
            {
        Sid    = "IncidentApiIAMRolesReadAndPolicy"
        Effect = "Allow"
        Action = [
          "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy"
        ]
        Resource = "arn:aws:iam::751835847368:role/incident-api-*"
      },
            {
        Sid    = "IncidentApiCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy", "logs:TagResource", "logs:ListTagsForResource",
          "logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:eu-west-2:751835847368:log-group:*"
      }
    ]
  })
}

resource "aws_iam_user" "cloud_engineer" {
  name = "cloud-engineer-scoped"
}

resource "aws_iam_user_policy_attachment" "cloud_engineer_attach" {
  user       = aws_iam_user.cloud_engineer.name
  policy_arn = aws_iam_policy.cloud_engineer_scoped.arn
}

# The user's access key is deliberately NOT managed by Terraform: a key created
# by Terraform has its secret stored in state, and this state lives in a shared
# S3 bucket. The existing key stays in AWS (used by the cloud-engineer-scoped
# CLI profile) and is rotated manually. This block drops it from state without
# deleting it.
removed {
  from = aws_iam_access_key.cloud_engineer_key

  lifecycle {
    destroy = false
  }
}

resource "aws_iam_policy" "incident_api_lambda_boundary" {
  name        = "incident-api-lambda-boundary"
  description = "Permissions boundary capping what incident-api Lambda execution roles can ever do, regardless of what policy is attached to them"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBTableAccessOnly"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:eu-west-2:751835847368:table/incident-api-incidents"
      },
      {
        Sid    = "LambdaLoggingOnly"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream", "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:eu-west-2:751835847368:log-group:/aws/lambda/incident-api-*:*"
      }
    ]
  })
}

# --- eamadiume.com personal site -------------------------------------------
# Kept in its own managed policy: cloud-engineer-project-policy is near the
# 6,144-character limit for a managed policy. Scoped to the one existing
# distribution, OAC, hosted zone and certificate, with deliberately NO Delete*
# actions on them -- this user can manage the live site but can't take it down.
# (S3 bucket/object access is covered by S3Access in the project policy.)
resource "aws_iam_policy" "cloud_engineer_site" {
  name        = "cloud-engineer-site-policy"
  description = "Manage the eamadiume.com site (CloudFront, Route 53, ACM read) without delete rights"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SiteCloudFront"
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution", "cloudfront:GetDistributionConfig",
          "cloudfront:UpdateDistribution", "cloudfront:ListTagsForResource",
          "cloudfront:TagResource", "cloudfront:UntagResource",
          "cloudfront:CreateInvalidation", "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = "arn:aws:cloudfront::751835847368:distribution/E1UXEDP6OVJFS5"
      },
      {
        Sid    = "SiteCloudFrontOAC"
        Effect = "Allow"
        Action = [
          "cloudfront:GetOriginAccessControl", "cloudfront:GetOriginAccessControlConfig",
          "cloudfront:UpdateOriginAccessControl"
        ]
        Resource = "arn:aws:cloudfront::751835847368:origin-access-control/E1J94FGWBCC2Z8"
      },
      {
        Sid    = "SiteRoute53Zone"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone", "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets", "route53:ListTagsForResource",
          "route53:ChangeTagsForResource"
        ]
        Resource = "arn:aws:route53:::hostedzone/Z04662192WP5WES78YW7L"
      },
      {
        Sid      = "Route53ChangeStatus"
        Effect   = "Allow"
        Action   = ["route53:GetChange"]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Sid      = "SiteCertificateRead"
        Effect   = "Allow"
        Action   = ["acm:DescribeCertificate", "acm:ListTagsForCertificate", "acm:AddTagsToCertificate"]
        Resource = "arn:aws:acm:us-east-1:751835847368:certificate/444706e8-c0c3-42ec-935e-868210346857"
      },
      {
        Sid      = "SiteBucketConfigWrite"
        Effect   = "Allow"
        Action   = ["s3:PutBucketPolicy", "s3:PutLifecycleConfiguration"]
        Resource = "arn:aws:s3:::eamadiume-site"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "cloud_engineer_site_attach" {
  user       = aws_iam_user.cloud_engineer.name
  policy_arn = aws_iam_policy.cloud_engineer_site.arn
}

# --- GitHub Actions: eamadiume.com deploy role -----------------------------
# Assumed via OIDC by .github/workflows/deploy-site.yml. Separate from the
# Terraform CI role and far narrower: it can upload the one page and
# invalidate the one distribution, and can only be assumed by workflows
# running on main in this repository.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "site_deploy" {
  name                 = "github-actions-site-deploy-role"
  description          = "OIDC role for GitHub Actions to deploy eamadiume.com"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:eamadiume-jigsaw/it-automation-portfolio:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "site_deploy" {
  name = "site-deploy"
  role = aws_iam_role.site_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "UploadSitePage"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "arn:aws:s3:::eamadiume-site/index.html"
      },
      {
        Sid      = "InvalidateSiteCache"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
        Resource = "arn:aws:cloudfront::751835847368:distribution/E1UXEDP6OVJFS5"
      }
    ]
  })
}

output "site_deploy_role_arn" {
  value = aws_iam_role.site_deploy.arn
}

# --- Account cost guardrail --------------------------------------------------
# Account-wide, so it lives here (admin-applied) rather than in a project the
# scoped user can change. Email is a variable so it isn't committed to the repo;
# Terraform prompts for it, or set TF_VAR_budget_alert_email.
variable "budget_alert_email" {
  description = "Where AWS Budgets sends cost alerts"
  type        = string
}

resource "aws_budgets_budget" "monthly" {
  name         = "monthly-account-budget"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # $5 actual spend
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # $10 actual spend
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # Forecast says the month will end above $10 -- early warning
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
