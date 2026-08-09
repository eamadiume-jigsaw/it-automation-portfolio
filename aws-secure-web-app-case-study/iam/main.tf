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
          "ec2:DescribeVpcAttribute","ec2:DescribeInstanceAttribute","ec2:DescribeVolumes", "ec2:DescribeVolumeAttribute",
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