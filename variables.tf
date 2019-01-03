# Variables file

## Global variables

variable "name" {
  description = "Name to be used on all the resources as identifier"
}

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "development_mode" {
  description = "Whether or not create a most robust production-ready infrastructure with ALBs and more than 1 replica"
  default     = false
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
