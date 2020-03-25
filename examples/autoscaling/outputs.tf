# VPC
output "vpc" {
  value = module.fargate.vpc_id
}

# ECR
output "ecr" {
  value = module.fargate.ecr_repository_urls
}

# ECS Cluster
output "ecs_cluster" {
  value = module.fargate.ecs_cluster_arn
}

# ALBs
output "application_load_balancers" {
  value = module.fargate.application_load_balancers_arns
}

# Security Groups
output "web_security_group" {
  value = module.fargate.web_security_group_arn
}

output "services_security_groups" {
  value = module.fargate.services_security_groups_arns
}

# CloudWatch
output "cloudwatch_log_groups" {
  value = module.fargate.cloudwatch_log_group_names
}
