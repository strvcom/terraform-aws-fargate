# Outputs file

# VPC

output "vpc" {
  value = {
    id                          = "${module.vpc.vpc_id}"
    cidr                        = "${module.vpc.vpc_cidr_block}"
    public_subnets              = ["${module.vpc.public_subnets}"]
    public_subnets_cidr_blocks  = ["${module.vpc.public_subnets_cidr_blocks}"]
    private_subnets             = ["${module.vpc.private_subnets}"]
    private_subnets_cidr_blocks = ["${module.vpc.private_subnets_cidr_blocks}"]
  }
}

# ECR

output "ecr_repository" {
  value = {
    arns            = ["${aws_ecr_repository.this.*.arn}"]
    repository_urls = ["${aws_ecr_repository.this.*.repository_url}"]
  }
}

# ECS CLUSTER

output "ecs_cluster" {
  value = {
    arn = "${aws_ecs_cluster.this.arn}"
  }
}

# ALB

output "application_load_balancers" {
  value = {
    arns     = ["${aws_lb.this.*.arn}"]
    dns_name = ["${aws_lb.this.*.dns_name}"]
  }
}

# SECURITY GROUPS

output "web_security_group" {
  value = {
    arn     = "${aws_security_group.web.arn}"
    ingress = "${aws_security_group.web.ingress}"
  }
}

output "services_security_groups" {
  value = {
    arns          = ["${aws_security_group.services.*.arn}"]
    ingress_rules = ["${aws_security_group.services.*.ingress}"]
  }
}

# CLOUDWATCH LOG GROUPS

output "cloudwatch_log_groups" {
  value = {
    names          = ["${aws_cloudwatch_log_group.this.*.name}"]
    retention_days = ["${aws_cloudwatch_log_group.this.*.retention_in_days}"]
  }
}
