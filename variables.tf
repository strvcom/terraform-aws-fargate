# Variables file

## Global variables

variable "name" {
  description = "Name to be used on all the resources as identifier"
}

## VPC variables

variable "vpc-create" {
  description = "Whether or not create a vpc using this module. If you have a preexisting VPC, just mark it as false"
  default     = true
}

variable "vpc-cidr" {
  default = "10.0.0.0/16"
}

variable "vpc-public-subnets" {
  description = "List of public subnets to be used for the vpc"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc-private-subnets" {
  description = "List of private subnets to be used for the vpc"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}
