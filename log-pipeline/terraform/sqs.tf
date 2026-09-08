# --- SQS -----------------------------------------------------------------
resource "aws_sqs_queue" "events" {
  name                       = "${var.project_name}-events"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400 # 1 day, plenty for a lab

  tags = { Name = "${var.project_name}-events" }
}
