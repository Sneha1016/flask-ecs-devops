variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "flask-ecs"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "container_name" {
  description = "Container name in the task definition."
  type        = string
  default     = "flask-app"
}

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 5000
}

variable "health_check_path" {
  description = "ALB target group health check path."
  type        = string
  default     = "/health"
}

variable "ecs_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "ecs_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of ECS tasks."
  type        = number
  default     = 1
}

variable "image_tag" {
  description = "Container image tag to deploy from ECR."
  type        = string
  default     = "latest"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 7
}
