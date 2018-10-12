# Main Module file

terraform {
  required_version = "~> 0.11.8"
}

# VPC CONFIGURATION

data "aws_availability_zones" "this" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  create_vpc = "${var.vpc_create}"

  name = "${var.name}-${terraform.workspace}-vpc"
  cidr = "${var.vpc_cidr}"
  azs  = "${data.aws_availability_zones.this.names}"

  public_subnets  = "${var.vpc_public_subnets}"
  private_subnets = "${var.vpc_private_subnets}"

  # Every instance deployed within the VPC will get a hostname
  enable_dns_hostnames = true

  # Every instance will have a dedicated internal endpoint to communicate with S3
  enable_s3_endpoint = true
}

# ECR

resource "aws_ecr_repository" "this" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  name = "${element(keys(var.services), count.index)}-${terraform.workspace}"
}

data "template_file" "ecr-lifecycle" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  template = "${file("${path.module}/policies/ecr-lifecycle-policy.json")}"

  vars {
    count = "${lookup(var.services[element(keys(var.services), count.index)], "registry_retention_days", var.ecr_default_retention_days)}"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  repository = "${element(aws_ecr_repository.this.*.name, count.index)}"

  policy = "${element(data.template_file.ecr-lifecycle.*.rendered, count.index)}"
}

# ECS CLUSTER

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-${terraform.workspace}-cluster"
}

# ECS TASKS DEFINITIONS

resource "aws_iam_role" "tasks" {
  name               = "${var.name}-${terraform.workspace}-task-execution-role"
  assume_role_policy = "${file("${path.module}/policies/ecs-task-execution-role.json")}"
}

resource "aws_iam_role_policy" "tasks" {
  name   = "${var.name}-${terraform.workspace}-task-execution-policy"
  policy = "${file("${path.module}/policies/ecs-task-execution-role-policy.json")}"
  role   = "${aws_iam_role.tasks.id}"
}

data "template_file" "tasks" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  template = "${file("${path.cwd}/${lookup(var.services[element(keys(var.services), count.index)], "task_definition")}")}"

  vars {
    container_name = "${element(keys(var.services), count.index)}"
    repository_url = "${element(aws_ecr_repository.this.*.repository_url, count.index)}"
    log_group      = "${aws_cloudwatch_log_group.this.name}"
    region         = "${var.region}"
  }
}

resource "aws_ecs_task_definition" "this" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  family                   = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}"
  container_definitions    = "${element(data.template_file.tasks.*.rendered, count.index)}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "${lookup(var.services[element(keys(var.services), count.index)], "cpu")}"
  memory                   = "${lookup(var.services[element(keys(var.services), count.index)], "memory")}"
  execution_role_arn       = "${aws_iam_role.tasks.arn}"
  task_role_arn            = "${aws_iam_role.tasks.arn}"
}

resource "aws_cloudwatch_log_group" "this" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  name = "ecs/${var.name}-${element(keys(var.services), count.index)}"

  retention_in_days = "${lookup(var.services[element(keys(var.services), count.index)], "logs_retention_days", var.cloudwatch_logs_default_retention_days)}"
}

# SECURITY GROUP. Should be global?

resource "aws_security_group" "this" {
  vpc_id = "${module.vpc.vpc_id}"
  name   = "${var.name}-${terraform.workspace}-web-sg"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000          # FIXME
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS SERVICES

# resource "aws_iam_role" "service" {
#   name               = "${var.name}-${terraform.workspace}-service-role"
#   assume_role_policy = "${file("${path.module}/policies/ecs-service-role.json")}"
# }

# resource "aws_iam_role_policy" "service" {
#   name   = "${var.name}-${terraform.workspace}-service-policy"
#   policy = "${file("${path.module}/policies/ecs-service-role-policy.json")}"
#   role   = "${aws_iam_role.service.id}"
# }

resource "aws_ecs_service" "this" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  name            = "${element(keys(var.services), count.index)}"
  cluster         = "${aws_ecs_cluster.this.name}"
  task_definition = "${element(aws_ecs_task_definition.this.*.arn, count.index)}"
  desired_count   = "${lookup(var.services[element(keys(var.services), count.index)], "replicas")}"
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # iam_role        = "${aws_iam_role.service.arn}" Not yet!

  network_configuration {
    security_groups  = ["${aws_security_group.this.id}"]
    subnets          = ["${module.vpc.public_subnets}"]
    assign_public_ip = true
  }
}

# CODEBUILD

resource "aws_s3_bucket" "this" {
  bucket        = "${var.name}-${terraform.workspace}-builds"
  acl           = "private"
  force_destroy = true
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.name}-${terraform.workspace}-codebuild-role"
  assume_role_policy = "${file("${path.module}/policies/codebuild-role.json")}"
}

data "template_file" "codebuild" {
  template = "${file("${path.module}/policies/codebuild-role-policy.json")}"

  vars {
    aws_s3_bucket_arn = "${aws_s3_bucket.this.arn}"
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.name}-${terraform.workspace}-codebuild-role-policy"
  role   = "${aws_iam_role.codebuild.id}"
  policy = "${data.template_file.codebuild.rendered}"
}

data "template_file" "buildspec" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  template = "${file("${path.module}/build/buildspec.yml")}"

  vars {
    container_name = "${element(keys(var.services), count.index)}"
    repository_url = "${element(aws_ecr_repository.this.*.repository_url, count.index)}"
    region         = "${var.region}"

    # cluster_name       = "${aws_ecs_cluster.this.name}"
    # subnets_id         = "${module.vpc.public_subnets}"
    # security_group_ids = "${aws_security_group.this.id}"
  }
}

resource "aws_codebuild_project" "this" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  name          = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-builds"
  build_timeout = "10"
  service_role  = "${aws_iam_role.codebuild.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"

    // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image           = "aws/codebuild/docker:17.09.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${element(data.template_file.buildspec.*.rendered, count.index)}"
  }
}

# CODEPIPELINE
resource "aws_iam_role" "codepipeline" {
  name = "${var.name}-${terraform.workspace}-codepipeline-role"

  assume_role_policy = "${file("${path.module}/policies/codepipeline-role.json")}"
}

data "template_file" "codepipeline" {
  template = "${file("${path.module}/policies/codepipeline-role-policy.json")}"

  vars {
    aws_s3_bucket_arn = "${aws_s3_bucket.this.arn}"
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${var.name}-${terraform.workspace}-codepipeline-role-policy"
  role   = "${aws_iam_role.codepipeline.id}"
  policy = "${data.template_file.codepipeline.rendered}"
}

resource "aws_codepipeline" "this" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  name     = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-pipeline"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store {
    location = "${aws_s3_bucket.this.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source"]

      configuration {
        Owner = "${var.repo_owner}"
        Repo  = "${var.repo_name}"

        # OAuthToken = "${var.repo_oauth_token}"
        Branch = "${terraform.workspace == "default" ? "master" : terraform.workspace}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["imagedefinitions"]

      configuration {
        ProjectName = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-builds"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"

      configuration {
        ClusterName = "${aws_ecs_cluster.this.name}"
        ServiceName = "${element(keys(var.services), count.index)}"
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
