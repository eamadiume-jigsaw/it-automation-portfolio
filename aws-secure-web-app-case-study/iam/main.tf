terraform {
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

# Permissions boundary for the serverless-incident-api Lambda roles. The
# cloud-engineer user can only create/modify incident-api-* roles when this
# boundary is attached, so it caps what any role they create can ever do --
# without it, iam:CreateRole + iam:PassRole would be a privilege-escalation path.
resource "aws_iam_policy" "incident_api_lambda_boundary" {
  name        = "incident-api-lambda-boundary"
  description = "Maximum permissions for incident-api Lambda execution roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IncidentTableItemAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:eu-west-2:*:table/incident-api-*"
      },
      {
        Sid      = "LambdaLogWrite"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:eu-west-2:*:log-group:/aws/lambda/incident-api-*:*"
      }
    ]
  })
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
          "ec2:DescribeVpcAttribute", "ec2:DescribeInstanceAttribute", "ec2:DescribeVolumes", "ec2:DescribeVolumeAttribute",
          "ec2:DescribeNetworkInterfaces", "ec2:DescribeNetworkInterfaceAttribute",
          "ec2:DescribeInstanceCreditSpecifications", "ec2:DescribeInstanceStatus",
          "ec2:DescribeSecurityGroupRules", "ec2:DescribeAddressesAttribute", "ec2:DescribeNatGateways", "ec2:DisassociateAddress",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway", "ec2:DescribeInternetGateways",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:DescribeRouteTables",
          "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeAvailabilityZones",
          "ec2:RunInstances", "ec2:TerminateInstances", "ec2:StopInstances", "ec2:StartInstances",
          "ec2:DescribeInstances", "ec2:DescribeInstanceTypes", "ec2:DescribeImages",
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
      # --- serverless-incident-api: everything below is scoped to incident-api-* ---
      {
        Sid    = "IncidentApiLambda"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:DeleteFunction",
          "lambda:GetFunction", "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
          "lambda:ListVersionsByFunction", "lambda:GetFunctionCodeSigningConfig",
          "lambda:AddPermission", "lambda:RemovePermission", "lambda:GetPolicy",
          "lambda:ListTags", "lambda:TagResource", "lambda:UntagResource"
        ]
        Resource = "arn:aws:lambda:eu-west-2:*:function:incident-api-*"
      },
      {
        Sid    = "IncidentApiDynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:UpdateTable",
          "dynamodb:DescribeTable", "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeTimeToLive", "dynamodb:ListTagsOfResource",
          "dynamodb:TagResource", "dynamodb:UntagResource"
        ]
        Resource = "arn:aws:dynamodb:eu-west-2:*:table/incident-api-*"
      },
      {
        # HTTP API IDs are random, so these can't be name-scoped -- limited to
        # the API Gateway v2 /apis paths in this region instead.
        Sid    = "IncidentApiGateway"
        Effect = "Allow"
        Action = [
          "apigateway:GET", "apigateway:POST", "apigateway:PUT",
          "apigateway:PATCH", "apigateway:DELETE"
        ]
        Resource = [
          "arn:aws:apigateway:eu-west-2::/apis",
          "arn:aws:apigateway:eu-west-2::/apis/*",
          "arn:aws:apigateway:eu-west-2::/tags/*"
        ]
      },
      {
        Sid    = "IncidentApiLogGroups"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
          "logs:ListTagsLogGroup", "logs:ListTagsForResource",
          "logs:TagResource", "logs:UntagResource",
          "logs:DescribeLogStreams", "logs:GetLogEvents", "logs:FilterLogEvents"
        ]
        Resource = "arn:aws:logs:eu-west-2:*:log-group:/aws/lambda/incident-api-*"
      },
      {
        Sid      = "LogGroupDiscovery"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        # Creating or changing a role's inline policy is only allowed when the
        # role carries the incident-api boundary. No AttachRolePolicy, and no
        # Put/DeleteRolePermissionsBoundary, so the boundary can't be swapped out.
        Sid      = "IncidentApiRoleWriteWithBoundary"
        Effect   = "Allow"
        Action   = ["iam:CreateRole", "iam:PutRolePolicy", "iam:DeleteRolePolicy"]
        Resource = "arn:aws:iam::*:role/incident-api-*"
        Condition = {
          StringEquals = { "iam:PermissionsBoundary" = aws_iam_policy.incident_api_lambda_boundary.arn }
        }
      },
      {
        Sid    = "IncidentApiRoleReadAndDelete"
        Effect = "Allow"
        Action = [
          "iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
          "iam:DeleteRole"
        ]
        Resource = "arn:aws:iam::*:role/incident-api-*"
      },
      {
        Sid      = "IncidentApiPassRoleToLambda"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::*:role/incident-api-*"
        Condition = {
          StringEquals = { "iam:PassedToService" = "lambda.amazonaws.com" }
        }
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

resource "aws_iam_access_key" "cloud_engineer_key" {
  user = aws_iam_user.cloud_engineer.name
}

output "cloud_engineer_access_key_id" {
  value = aws_iam_access_key.cloud_engineer_key.id
}

output "cloud_engineer_secret_key" {
  value     = aws_iam_access_key.cloud_engineer_key.secret
  sensitive = true
}