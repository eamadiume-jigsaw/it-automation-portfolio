# --- Lambda ----------------------------------------------------------------
# One entry per function. The key drives resource names, `file` is the source
# in ../lambda/, and `dynamodb_actions` is the only table access that function's
# role gets -- create can't read, list/get can't write.
locals {
  functions = {
    create_incident = {
      file             = "create_incident.py"
      handler          = "create_incident.lambda_handler"
      route            = "POST /incidents"
      dynamodb_actions = ["dynamodb:PutItem"]
    }
    list_incidents = {
      file             = "list_incidents.py"
      handler          = "list_incidents.lambda_handler"
      route            = "GET /incidents"
      dynamodb_actions = ["dynamodb:Scan"]
    }
    get_incident = {
      file             = "get_incident.py"
      handler          = "get_incident.lambda_handler"
      route            = "GET /incidents/{id}"
      dynamodb_actions = ["dynamodb:GetItem"]
    }
  }

  function_names = { for k, _ in local.functions : k => "${var.project_name}-${replace(k, "_", "-")}" }
}

# Each function gets its own zip containing just its own .py file.
# boto3 ships with the Lambda Python runtime, so no dependencies to bundle.
data "archive_file" "lambda" {
  for_each    = local.functions
  type        = "zip"
  source_file = "${path.module}/../lambda/${each.value.file}"
  output_path = "${path.module}/build/${each.key}.zip"
}

# Created up front so retention is set -- otherwise Lambda auto-creates the
# group on first invoke with "never expire". It also means the function roles
# don't need logs:CreateLogGroup.
resource "aws_cloudwatch_log_group" "lambda" {
  for_each          = local.functions
  name              = "/aws/lambda/${local.function_names[each.key]}"
  retention_in_days = 3 # short retention -- this is a lab, not production
}

resource "aws_lambda_function" "incident" {
  for_each         = local.functions
  function_name    = local.function_names[each.key]
  role             = aws_iam_role.lambda[each.key].arn
  runtime          = var.lambda_runtime
  handler          = each.value.handler
  filename         = data.archive_file.lambda[each.key].output_path
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256 # redeploys only when the code actually changes
  memory_size      = 128
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.incidents.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}
