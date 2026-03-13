output "ecr_repository_url" {
  description = "ECR repository URL for image pushes."
  value       = module.ecr.repository_url
}

output "alb_dns_name" {
  description = "Public DNS name of the application load balancer."
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}
