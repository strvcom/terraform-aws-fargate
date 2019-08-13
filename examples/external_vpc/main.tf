terraform {
  required_version = ">= 0.11.13"
}

provider "aws" {
  version = "~> 2.6.0"
  region  = "us-east-1"
  profile = "playground"
}

variable "public_subnets_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets_cidrs" {
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.60.0"

  create_vpc = true

  name = "the-external-vpc"
  cidr = "10.0.0.0/16"
  azs  = ["us-east-1a", "us-east-1b", "us-east-1c"]

  public_subnets  = "${var.public_subnets_cidrs}"
  private_subnets = "${var.private_subnets_cidrs}"
}

module "fargate" {
  source = "../../"

  name = "external-vpc-example"

  vpc_create      = false                  # This variable must be set to false, otherwise the module will create its own VPC
  vpc_external_id = "${module.vpc.vpc_id}"

  vpc_public_subnets  = "${var.public_subnets_cidrs}"
  vpc_private_subnets = "${var.private_subnets_cidrs}"

  vpc_external_public_subnets_ids  = "${module.vpc.public_subnets}"
  vpc_external_private_subnets_ids = "${module.vpc.private_subnets}"

  services = {
    api = {
      task_definition = "api.json"
      container_port  = 3000
      cpu             = "256"
      memory          = "512"
      replicas        = 2
    }
  }
}
