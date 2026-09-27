# --- IAM -------------------------------------------------------------------
# One role per function, each scoped to the single DynamoDB action it needs
# plus writing to its own log group.
#
# Every role carries the incident-api-lambda-boundary permissions boundary
# (created alongside cloud-engineer-project-policy). The deploying user is only
# allowed to create roles that have it attached, so even a mistake here can't
# produce a role with more than table + log access.
data "aws_caller_identity" "current" {}

locals {
  lambda_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-lambda-boundary"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  for_each             = local.functions
  name                 = "${local.function_names[each.key]}-role"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json
  permissions_boundary = local.lambda_boundary_arn
}

data "aws_iam_policy_document" "lambda_access" {
  for_each = local.functions

  statement {
    actions   = each.value.dynamodb_actions
    resources = [aws_dynamodb_table.incidents.arn]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.lambda[each.key].arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda_access" {
  for_each = local.functions
  name     = "${local.function_names[each.key]}-policy"
  role     = aws_iam_role.lambda[each.key].id
  policy   = data.aws_iam_policy_document.lambda_access[each.key].json
}
