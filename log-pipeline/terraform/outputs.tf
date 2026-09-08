output "ecr_api_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecr_worker_repository_url" {
  value = aws_ecr_repository.worker.repository_url
}

output "sqs_queue_url" {
  value = aws_sqs_queue.events.url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "api_service_name" {
  value = aws_ecs_service.api.name
}

output "worker_service_name" {
  value = aws_ecs_service.worker.name
}

output "next_steps" {
  value = <<-EOT
    1. Build and push images to the ECR repos above (see README for exact commands).
    2. Force a new deployment so ECS picks up the pushed image:
       aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.api.name} --force-new-deployment
       aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.worker.name} --force-new-deployment
    3. Find the API task's public IP (see README) and curl it on port 8000.
  EOT
}
