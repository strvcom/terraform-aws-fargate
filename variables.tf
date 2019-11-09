# Variables file

## Global variables

variable "name" {
  description = "Name to be used on all the resources as identifier"
}

variable "region" {
  description = "AWS region"
  default     = ""
}

variable "service_discovery_enabled" {
  default = false
}


## VPC variables

variable "vpc_create" {
  description = "Whether or not create a vpc using this module. If you have a preexisting VPC, just mark it as false"
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR to be used by the VPC"
  default     = "10.0.0.0/16"
}

variable "vpc_public_subnets" {
  description = "List of public subnets to be used for the vpc"
  default     = []
}

variable "vpc_private_subnets" {
  description = "List of private subnets to be used for the vpc"
  default     = []
}

variable "vpc_create_nat" {
  description = "Whether or not create a NAT gateway in the VPC managed by this module. Note that disabling this, it will forced to put ALL Fargate services inside a PUBLIC subnet with a PUBLIC ip address"
  default     = true
}

## External VPC variables

variable "vpc_external_id" {
  description = "Id of the external VPC to be used. var.vpc_create must be false, otherwise, this variable will be ignored."
  default     = ""
}

variable "vpc_external_public_subnets_ids" {
  description = "Lists of ids of external public subnets. var.vpc_create must be false, otherwise, this variable will be ignored."
  default     = []
}

variable "vpc_external_private_subnets_ids" {
  description = "Lists of ids of external private subnets. var.vpc_create must be false, otherwise, this variable will be ignored."
  default     = []
}

## ECS variables

variable "services" {}

variable "ssm_allowed_parameters" {
  description = "List of ssm parameters that can be acceesed by the Fargate task during execution. Could be an ARN or just the name of the parameter path prefix"
  default     = ""
}

## ALB variables

variable "alb_default_health_check_interval" {
  default = 30
}

variable "alb_default_health_check_path" {
  default = "/"
}

## CODEPIPELINE SNS EVENTS varialbes

variable "codepipeline_events_enabled" {
  default = false
}
