terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "ecommerce-analytics/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = "Platform-Team"
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
  
  tags = local.common_tags
}

# Security Groups
module "security_groups" {
  source = "./modules/security-groups"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  
  tags = local.common_tags
}

# RDS Module
module "rds" {
  source = "./modules/rds"
  
  project_name           = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  database_subnet_ids   = module.vpc.database_subnet_ids
  security_group_ids    = [module.security_groups.rds_security_group_id]
  
  db_instance_class     = var.db_instance_class
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  
  tags = local.common_tags
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.ecs_security_group_id, module.security_groups.alb_security_group_id]
  
  container_image   = var.container_image
  container_port    = var.container_port
  cpu              = var.ecs_cpu
  memory           = var.ecs_memory
  desired_count    = var.ecs_desired_count
  
  database_url     = module.rds.database_url
  
  tags = local.common_tags
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"
  
  project_name    = var.project_name
  environment     = var.environment
  target_group_arn = module.ecs.target_group_arn
  vpc_link_id     = module.ecs.vpc_link_id
  
  tags = local.common_tags
}

# Lambda Functions Module
module "lambda" {
  source = "./modules/lambda"
  
  project_name       = var.project_name
  environment        = var.environment
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.lambda_security_group_id]
  
  database_url = module.rds.database_url
  
  tags = local.common_tags
}

# CloudWatch Module
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name = var.project_name
  environment  = var.environment
  
  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name
  api_gateway_name   = module.api_gateway.api_name
  rds_instance_id    = module.rds.instance_id
  
  tags = local.common_tags
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "Platform-Team"
    ManagedBy   = "Terraform"
  }
}