# Variables file

## Provider variables
variable "region" {
  description = "AWS region where the entire infrastructure is deployed"
  default     = "us-east-1"
}

## VPC variables

variable "vpc-region-azs" {
  default = {
    # N. Virginia
    "us-east-1" = ["us-east-1a", "us-east-1b", "us-east-1c"]

    # Ireland
    "eu-west-1" = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  }
}

variable "vpc-create" {
  description = "Whether or not create a vpc using this module. If you have a preexisting VPC, just mark it as false"
  default     = true
}

variable "vpc-name" {
  description = "Name to be used on all the resources as identifier"
}

variable "vpc-cidr" {
  default = "10.0.0.0/16"
}

locals {
  # Here are selected the default AZs used for the subnets  # By default, a, b and c AZs are chosen and only supports  # US-EAST-1 🇺🇸 and EU-WEST-1 🇪🇺 regions, for now.

  # 👎 We need to use locals becuase variables do not support interpolation
  vpc-azs = "${var.vpc-region-azs["${var.region}"]}"
}

variable "vpc-public-subnets" {
  description = "List of subnets to be used for the vpc"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
