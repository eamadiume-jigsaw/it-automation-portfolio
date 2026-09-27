# --- API Gateway -----------------------------------------------------------
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default" # serves at the API root, no /stage prefix in the URL
  auto_deploy = true

  # The API is public with no auth -- throttle so a stray loop (or a stranger)
  # can't run up Lambda/DynamoDB costs.
  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  for_each               = local.functions
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.incident[each.key].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "incident" {
  for_each  = local.functions
  api_id    = aws_apigatewayv2_api.main.id
  route_key = each.value.route
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"
}

# Lets API Gateway invoke each function -- but only via its own route,
# e.g. create_incident can't be reached through GET /incidents.
resource "aws_lambda_permission" "apigateway" {
  for_each      = local.functions
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incident[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/${replace(each.value.route, " ", "")}"
}
