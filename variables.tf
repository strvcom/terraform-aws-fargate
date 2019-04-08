# Variables file

## Global variables

variable "name" {
  description = "Name to be used on all the resources as identifier"
}

variable "region" {
  description = "AWS region"
  default     = ""
}

## VPC variables

variable "vpc_create" {
  description = "Whether or not create a vpc using this module. If you have a preexisting VPC, just mark it as false"
  default     = true
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "vpc_public_subnets" {
  description = "List of public subnets to be used for the vpc"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc_private_subnets" {
  description = "List of private subnets to be used for the vpc"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "vpc_create_nat" {
  description = "Whether or not create a NAT gateway in the VPC managed by this module. Note that disabling this, it will forced to put ALL Fargate services inside a PUBLIC subnet with a PUBLIC ip address"
  default     = true
}

## LOGS

variable "cloudwatch_logs_default_retention_days" {
  default = 30
}

## ECS variables

variable "ecr_default_retention_count" {
  default = 20
}

variable "services" {
  type = "map"
}

## ALB variables

variable "alb_default_health_check_path" {
  default = "/"
}

## CODEPIPELINE SNS EVENTS varialbes

variable "codepipeline_events_enabled" {
  default = false
}
