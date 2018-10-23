# Main Module file

terraform {
  required_version = "~> 0.11.8"
}

# VPC CONFIGURATION

data "aws_availability_zones" "this" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  create_vpc = "${var.vpc-create}"

  name = "${var.name}-vpc"
  cidr = "${var.vpc-cidr}"
  azs  = "${data.aws_availability_zones.this.names}"

  public_subnets  = "${var.vpc-public-subnets}"
  private_subnets = "${var.vpc-private-subnets}"

  # Every instance deployed within the VPC will get a hostname
  enable_dns_hostnames = true

  # Every instance will have a dedicated internal endpoint to communicate with S3
  enable_s3_endpoint = true
}
