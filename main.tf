# Main Module file

terraform {
  required_version = "~> 0.11.8"
}

provider "aws" {
  version = "~> 1.36.0"
  region  = "${var.region}"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  create_vpc = "${var.vpc-create}"

  name = "${var.vpc-name}"
  cidr = "${var.vpc-cidr}"
  azs  = "${local.vpc-azs}"

  public_subnets = "${var.vpc-public-subnets}"

  # Every instance deployed within the VPC will get a hostname
  enable_dns_hostnames = true

  # Every instance will have a dedicated internal endpoint to communicate with S3
  enable_s3_endpoint = true
}
