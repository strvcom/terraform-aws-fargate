# Outputs file

# VPC

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "public_subnets_cidr_blocks" {
  description = "List of cidr_blocks of public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

# ECR

output "ecr_repository_arns" {
  description = "List of ARNs of ECR repositories"
  value       = aws_ecr_repository.this.*.arn
}

output "ecr_repository_urls" {
  description = "List of URLs of ECR repositories"
  value       = aws_ecr_repository.this.*.repository_url
}

# ECS CLUSTER

output "ecs_cluster_arn" {
  description = "ARN of the ECS Cluster"
  value       = aws_ecs_cluster.this.arn
}

# ALB

output "application_load_balancers_arns" {
  description = "List of ARNs of Application Load Balancers"
  value       = values(aws_lb.this).*.arn
}

output "application_load_balancers_zone_ids" {
  description = "List of Zone IDs of Application Load Balancers"
  value       = values(aws_lb.this).*.zone_id
}

output "application_load_balancers_dns_names" {
  description = "List of DNS Names of Application Load Balancers"
  value       = values(aws_lb.this).*.dns_name
}

# SECURITY GROUPS

output "web_security_group_arn" {
  description = "ARN of Web-facing Security Rule"
  value       = aws_security_group.web.arn
}

output "web_security_group_ingress" {
  description = "Ingress Rule of Web-facing Security Rule"
  value       = aws_security_group.web.ingress
}

output "services_security_groups_arns" {
  description = "List of ARNs of Services' Security Groups"
  value       = aws_security_group.services.*.arn
}

output "services_security_groups_ingress_rules" {
  description = "List of Ingress Rules of Services' Security Groups"
  value       = aws_security_group.services.*.ingress
}

# CLOUDWATCH LOG GROUPS

output "cloudwatch_log_group_names" {
  description = "List of Names of Cloudwatch Log Groups"
  value       = aws_cloudwatch_log_group.this.*.name
}

output "cloudwatch_log_group_retention_days" {
  description = "List of Retention in Days configuration of Cloudwatch Log Groups"
  value       = aws_cloudwatch_log_group.this.*.retention_in_days
}

# CODEPIPELINE SNS EVENTS

output "codepipeline_events_sns_arn" {
  description = "ARN of CodePipeline's SNS Topic"
  value       = var.codepipeline_events_enabled ? join(",", aws_sns_topic.codepipeline_events.*.arn) : "not set"
}
