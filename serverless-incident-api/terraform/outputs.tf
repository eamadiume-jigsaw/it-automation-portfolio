output "api_endpoint" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.incidents.name
}

output "lambda_function_names" {
  value = { for k, f in aws_lambda_function.incident : k => f.function_name }
}

output "next_steps" {
  value = <<-EOT
    1. Create an incident:
       Invoke-RestMethod -Uri ${aws_apigatewayv2_api.main.api_endpoint}/incidents -Method Post -ContentType "application/json" -Body '{"title":"disk usage 92%","severity":"high"}'
    2. List incidents:
       Invoke-RestMethod -Uri ${aws_apigatewayv2_api.main.api_endpoint}/incidents
    3. Get one (use an incident_id from step 1 or 2):
       Invoke-RestMethod -Uri ${aws_apigatewayv2_api.main.api_endpoint}/incidents/<incident_id>
    4. Tail a function's logs:
       aws logs tail /aws/lambda/${aws_lambda_function.incident["create_incident"].function_name} --follow
  EOT
}
