terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "networking" {
  source = "./modules/networking"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = local.azs
}

module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  app_port     = var.container_port
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name       = var.project_name
  environment        = var.environment
  log_retention_days = var.log_retention_days
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  target_group_port     = var.container_port
  health_check_path     = var.health_check_path
}

module "ecs" {
  source = "./modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  subnet_ids            = module.networking.public_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_security_group_id
  target_group_arn      = module.alb.target_group_arn
  execution_role_arn    = module.iam.ecs_task_execution_role_arn
  task_role_arn         = module.iam.ecs_task_role_arn
  log_group_name        = module.cloudwatch.log_group_name
  container_name        = var.container_name
  container_port        = var.container_port
  cpu                   = var.ecs_cpu
  memory                = var.ecs_memory
  desired_count         = var.desired_count
  ecr_repository_url    = module.ecr.repository_url
  image_tag             = var.image_tag
  assign_public_ip      = true

  depends_on = [
    module.alb,
    module.cloudwatch,
    module.iam,
  ]
}
