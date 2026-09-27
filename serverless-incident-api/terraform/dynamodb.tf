# --- DynamoDB --------------------------------------------------------------
resource "aws_dynamodb_table" "incidents" {
  name         = "${var.project_name}-incidents"
  billing_mode = "PAY_PER_REQUEST" # no provisioned capacity -- costs nothing while idle
  hash_key     = "incident_id"

  attribute {
    name = "incident_id"
    type = "S"
  }

  tags = { Name = "${var.project_name}-incidents" }
}
