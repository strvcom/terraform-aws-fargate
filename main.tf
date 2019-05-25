# Main Module file

terraform {
  required_version = ">= 0.12"
}

provider "random" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

# VPC CONFIGURATION

locals {
  vpc_id = !var.vpc_create ? var.vpc_external_id : module.vpc.vpc_id

  vpc_public_subnets = split(",",
    length(var.vpc_public_subnets) > 0
    || !var.vpc_create
    ? join(",", var.vpc_public_subnets)
    : join(",", list(
      cidrsubnet(var.vpc_cidr, 8, 1),
      cidrsubnet(var.vpc_cidr, 8, 2),
      cidrsubnet(var.vpc_cidr, 8, 3)
    ))
  )

  vpc_private_subnets = split(",",
    length(var.vpc_private_subnets) > 0
    || !var.vpc_create
    ? join(",", var.vpc_private_subnets)
    : join(",", list(
      cidrsubnet(var.vpc_cidr, 8, 101),
      cidrsubnet(var.vpc_cidr, 8, 102),
      cidrsubnet(var.vpc_cidr, 8, 103)
    ))
  )

  vpc_private_subnets_ids = split(",",
    !var.vpc_create
    ? join(",", var.vpc_external_private_subnets_ids)
    : join(",", module.vpc.private_subnets)
  )

  vpc_public_subnets_ids = split(",",
    !var.vpc_create
    ? join(",", var.vpc_external_public_subnets_ids)
    : join(",", module.vpc.public_subnets)
  )
}

data "aws_availability_zones" "this" {}

data "aws_region" "current" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.0.0"

  create_vpc = var.vpc_create

  name = "${var.name}-${terraform.workspace}-vpc"
  cidr = var.vpc_cidr
  azs  = data.aws_availability_zones.this.names

  public_subnets  = local.vpc_public_subnets
  private_subnets = local.vpc_private_subnets

  # NAT gateway for private subnets
  enable_nat_gateway = var.vpc_create_nat
  single_nat_gateway = var.vpc_create_nat

  # Every instance deployed within the VPC will get a hostname
  enable_dns_hostnames = true

  # Every instance will have a dedicated internal endpoint to communicate with S3
  enable_s3_endpoint = true
}

# ECR

resource "aws_ecr_repository" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name = "${element(keys(var.services), count.index)}-${terraform.workspace}"
}

data "template_file" "ecr-lifecycle" {
  count = length(var.services) > 0 ? length(var.services) : 0

  template = file("${path.module}/policies/ecr-lifecycle-policy.json")

  vars = {
    count = lookup(var.services[element(keys(var.services), count.index)], "registry_retention_count", var.ecr_default_retention_count)
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  repository = element(aws_ecr_repository.this.*.name, count.index)

  policy = element(data.template_file.ecr-lifecycle.*.rendered, count.index)
}

# ECS CLUSTER

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-${terraform.workspace}-cluster"
}

# ECS TASKS DEFINITIONS

resource "aws_iam_role" "tasks" {
  name               = "${var.name}-${terraform.workspace}-task-execution-role"
  assume_role_policy = file("${path.module}/policies/ecs-task-execution-role.json")
}

resource "aws_iam_role_policy" "tasks" {
  name   = "${var.name}-${terraform.workspace}-task-execution-policy"
  policy = file("${path.module}/policies/ecs-task-execution-role-policy.json")
  role   = aws_iam_role.tasks.id
}

data "template_file" "tasks" {
  count = length(var.services) > 0 ? length(var.services) : 0

  template = file("${path.cwd}/${lookup(var.services[element(keys(var.services), count.index)], "task_definition")}")

  vars = {
    container_name = element(keys(var.services), count.index)
    container_port = lookup(var.services[element(keys(var.services), count.index)], "container_port")
    repository_url = element(aws_ecr_repository.this.*.repository_url, count.index)
    log_group      = element(aws_cloudwatch_log_group.this.*.name, count.index)
    region         = var.region != "" ? var.region : data.aws_region.current.name
  }
}

resource "aws_ecs_task_definition" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  family                   = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}"
  container_definitions    = element(data.template_file.tasks.*.rendered, count.index)
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = lookup(var.services[element(keys(var.services), count.index)], "cpu")
  memory                   = lookup(var.services[element(keys(var.services), count.index)], "memory")
  execution_role_arn       = aws_iam_role.tasks.arn
  task_role_arn            = aws_iam_role.tasks.arn
}

data "aws_ecs_task_definition" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  task_definition = element(aws_ecs_task_definition.this.*.family, count.index)
}

resource "aws_cloudwatch_log_group" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name = "/ecs/${var.name}-${element(keys(var.services), count.index)}"

  retention_in_days = lookup(var.services[element(keys(var.services), count.index)], "logs_retention_days", var.cloudwatch_logs_default_retention_days)
}

# SECURITY GROUPS

resource "aws_security_group" "web" {
  vpc_id = local.vpc_id
  name   = "${var.name}-${terraform.workspace}-web-sg"
}

resource "aws_security_group_rule" "web_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.web.id}"
}

resource "aws_security_group_rule" "web_ingress_http" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.web.id}"
}

resource "aws_security_group_rule" "web_ingress_https" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.web.id}"
}

resource "aws_security_group" "services" {
  count = length(var.services) > 0 ? length(var.services) : 0

  vpc_id = local.vpc_id
  name   = "${var.name}-${element(keys(var.services), count.index)}-${terraform.workspace}-services-sg"
}

resource "aws_security_group_rule" "services_egress" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${element(aws_security_group.services.*.id, count.index)}"
}

resource "aws_security_group_rule" "services_ingress" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  type                     = "ingress"
  from_port                = "${lookup(var.services[element(keys(var.services), count.index)], "container_port")}"
  to_port                  = "${lookup(var.services[element(keys(var.services), count.index)], "container_port")}"
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.web.id}"

  security_group_id = "${element(aws_security_group.services.*.id, count.index)}"
}

# ALBs

resource "random_id" "target_group_sufix" {
  count = length(var.services) > 0 ? length(var.services) : 0

  keepers = {
    container_port = lookup(var.services[element(keys(var.services), count.index)], "container_port")
  }

  byte_length = 2
}

resource "aws_lb_target_group" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name        = "${var.name}-${element(keys(var.services), count.index)}-${element(random_id.target_group_sufix.*.hex, count.index)}"
  port        = element(random_id.target_group_sufix.*.keepers.container_port, count.index)
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    interval            = "${lookup(var.services[element(keys(var.services), count.index)], "health_check_interval", var.alb_default_health_check_interval)}"
    path                = "${lookup(var.services[element(keys(var.services), count.index)], "health_check_path", var.alb_default_health_check_path)}"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-299"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name            = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-alb"
  subnets         = slice(local.vpc_public_subnets_ids, 0, min(length(data.aws_availability_zones.this.names), length(local.vpc_public_subnets_ids)))
  security_groups = [aws_security_group.web.id]
}

resource "aws_lb_listener" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  load_balancer_arn = element(aws_lb.this.*.arn, count.index)
  port              = lookup(var.services[element(keys(var.services), count.index)], "acm_certificate_arn", "") != "" ? 443 : 80
  protocol          = lookup(var.services[element(keys(var.services), count.index)], "acm_certificate_arn", "") != "" ? "HTTPS" : "HTTP"
  ssl_policy        = lookup(var.services[element(keys(var.services), count.index)], "acm_certificate_arn", "") != "" ? "ELBSecurityPolicy-FS-2018-06" : ""
  certificate_arn   = lookup(var.services[element(keys(var.services), count.index)], "acm_certificate_arn", "")
  depends_on        = ["aws_lb_target_group.this"]

  default_action {
    target_group_arn = element(aws_lb_target_group.this.*.arn, count.index)
    type             = "forward"
  }
}

# ECS SERVICES

resource "aws_ecs_service" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name            = "${element(keys(var.services), count.index)}"
  cluster         = aws_ecs_cluster.this.name
  task_definition = "${element(aws_ecs_task_definition.this.*.family, count.index)}:${max("${element(aws_ecs_task_definition.this.*.revision, count.index)}", "${element(data.aws_ecs_task_definition.this.*.revision, count.index)}")}"
  desired_count   = lookup(var.services[element(keys(var.services), count.index)], "replicas")
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    security_groups = [element(aws_security_group.services.*.id, count.index)]

    subnets          = var.vpc_create_nat ? local.vpc_private_subnets_ids : local.vpc_public_subnets_ids
    assign_public_ip = ! var.vpc_create_nat
  }

  load_balancer {
    target_group_arn = element(aws_lb_target_group.this.*.arn, count.index)
    container_name   = element(keys(var.services), count.index)
    container_port   = lookup(var.services[element(keys(var.services), count.index)], "container_port")
  }

  depends_on = ["aws_lb_target_group.this", "aws_lb_listener.this"]

  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

resource "aws_iam_role" "autoscaling" {
  name               = "${var.name}-${terraform.workspace}-appautoscaling-role"
  assume_role_policy = "${file("${path.module}/policies/appautoscaling-role.json")}"
}

resource "aws_iam_role_policy" "autoscaling" {
  name   = "${var.name}-${terraform.workspace}-appautoscaling-policy"
  policy = "${file("${path.module}/policies/appautoscaling-role-policy.json")}"
  role   = "${aws_iam_role.autoscaling.id}"
}

resource "aws_appautoscaling_target" "this" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  max_capacity       = "${lookup(var.services[element(keys(var.services), count.index)], "auto_scaling_max_replicas", lookup(var.services[element(keys(var.services), count.index)], "replicas"))}"
  min_capacity       = "${lookup(var.services[element(keys(var.services), count.index)], "replicas")}"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${element(keys(var.services), count.index)}"
  role_arn           = "${aws_iam_role.autoscaling.arn}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = ["aws_ecs_service.this"]
}

resource "aws_appautoscaling_policy" "this" {
  count = "${length(var.services) > 0 ? length(var.services) : 0}"

  name               = "${element(keys(var.services), count.index)}-autoscaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "${element(aws_appautoscaling_target.this.*.resource_id, count.index)}"
  scalable_dimension = "${element(aws_appautoscaling_target.this.*.scalable_dimension, count.index)}"
  service_namespace  = "${element(aws_appautoscaling_target.this.*.service_namespace, count.index)}"

  target_tracking_scaling_policy_configuration {
    target_value = "${lookup(var.services[element(keys(var.services), count.index)], "auto_scaling_max_cpu_util", 100)}"

    scale_in_cooldown  = 300
    scale_out_cooldown = 300

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }

  depends_on = ["aws_appautoscaling_target.this"]
}

# CODEBUILD

resource "aws_s3_bucket" "this" {
  bucket        = "${var.name}-${terraform.workspace}-builds"
  acl           = "private"
  force_destroy = true
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.name}-${terraform.workspace}-codebuild-role"
  assume_role_policy = file("${path.module}/policies/codebuild-role.json")
}

data "template_file" "codebuild" {
  template = file("${path.module}/policies/codebuild-role-policy.json")

  vars = {
    aws_s3_bucket_arn = aws_s3_bucket.this.arn
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.name}-${terraform.workspace}-codebuild-role-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.template_file.codebuild.rendered
}

data "template_file" "buildspec" {
  count = length(var.services) > 0 ? length(var.services) : 0

  template = file("${path.module}/build/buildspec.yml")

  vars = {
    container_name = element(keys(var.services), count.index)
  }
}

resource "aws_codebuild_project" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name          = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-builds"
  build_timeout = "10"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"

    // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image           = "aws/codebuild/ubuntu-base:14.04"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = element(data.template_file.buildspec.*.rendered, count.index)
  }
}

# CODEPIPELINE
resource "aws_iam_role" "codepipeline" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-codepipeline-role"

  assume_role_policy = file("${path.module}/policies/codepipeline-role.json")
}

data "template_file" "codepipeline" {
  count = length(var.services) > 0 ? length(var.services) : 0

  template = file("${path.module}/policies/codepipeline-role-policy.json")

  vars = {
    aws_s3_bucket_arn  = aws_s3_bucket.this.arn
    ecr_repository_arn = element(aws_ecr_repository.this.*.arn, count.index)
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name   = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-codepipeline-role-policy"
  role   = element(aws_iam_role.codepipeline.*.id, count.index)
  policy = element(data.template_file.codepipeline.*.rendered, count.index)
}

resource "aws_codepipeline" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name     = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-pipeline"
  role_arn = element(aws_iam_role.codepipeline.*.arn, count.index)

  artifact_store {
    location = aws_s3_bucket.this.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        RepositoryName = element(aws_ecr_repository.this.*.name, count.index)
        ImageTag       = "latest"
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

      configuration = {
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

      configuration = {
        ClusterName = aws_ecs_cluster.this.name
        ServiceName = element(keys(var.services), count.index)
        FileName    = "imagedefinitions.json"
      }
    }
  }

  depends_on = ["aws_iam_role_policy.codebuild", "aws_ecs_service.this"]
}

# CODEPIPELINE STATUS SNS

data "template_file" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  template = file("${path.module}/cloudwatch/codepipeline-source-event.json")

  vars = {
    codepipeline_names = jsonencode(aws_codepipeline.this.*.name)
  }
}

data "template_file" "codepipeline_events_sns" {
  count = var.codepipeline_events_enabled ? 1 : 0

  template = file("${path.module}/policies/sns-cloudwatch-events-policy.json")

  vars = {
    sns_arn = element(aws_sns_topic.codepipeline_events.*.arn, count.index)
  }
}

resource "aws_cloudwatch_event_rule" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  name        = "${var.name}-${terraform.workspace}-pipeline-events"
  description = "Amazon CloudWatch Events rule to automatically post SNS notifications when CodePipeline state changes."

  event_pattern = element(data.template_file.codepipeline_events.*.rendered, count.index)
}

resource "aws_sns_topic" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  name         = "${var.name}-${terraform.workspace}-codepipeline-events"
  display_name = "${var.name}-${terraform.workspace}-codepipeline-events"
}

resource "aws_sns_topic_policy" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  arn = element(aws_sns_topic.codepipeline_events.*.arn, count.index)

  policy = element(data.template_file.codepipeline_events_sns.*.rendered, count.index)
}

resource "aws_cloudwatch_event_target" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  rule      = element(aws_cloudwatch_event_rule.codepipeline_events.*.name, count.index)
  target_id = "${var.name}-${terraform.workspace}-codepipeline"
  arn       = element(aws_sns_topic.codepipeline_events.*.arn, count.index)
}

### CLOUDWATCH BASIC DASHBOARD

data "template_file" "metric_dashboard" {
  count = length(var.services) > 0 ? length(var.services) : 0

  template = file("${path.module}/metrics/basic-dashboard.json")

  vars = {
    region         = var.region != "" ? var.region : data.aws_region.current.name
    alb_arn_suffix = element(aws_lb.this.*.arn_suffix, count.index)
    cluster_name   = aws_ecs_cluster.this.name
    service_name   = element(keys(var.services), count.index)
  }
}

resource "aws_cloudwatch_dashboard" "this" {
  count = length(var.services) > 0 ? length(var.services) : 0

  dashboard_name = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-metrics-dashboard"

  dashboard_body = element(data.template_file.metric_dashboard.*.rendered, count.index)
}

### Remove after ECR as CodePipeline Source gets fully integrated with AWS Provider

resource "aws_iam_role" "events" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-events-role"

  assume_role_policy = file("${path.module}/policies/events-role.json")
}

data "template_file" "events" {
  count = length(var.services) > 0 ? length(var.services) : 0

  template = file("${path.module}/policies/events-role-policy.json")

  vars = {
    codepipeline_arn = element(aws_codepipeline.this.*.arn, count.index)
  }
}

resource "aws_iam_role_policy" "events" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name   = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-events-role-policy"
  role   = element(aws_iam_role.events.*.id, count.index)
  policy = element(data.template_file.events.*.rendered, count.index)
}

data "template_file" "ecr_event" {
  count = length(var.services) > 0 ? length(var.services) : 0

  template = file("${path.module}/cloudwatch/ecr-source-event.json")

  vars = {
    ecr_repository_name = element(aws_ecr_repository.this.*.name, count.index)
  }
}

resource "aws_cloudwatch_event_rule" "events" {
  count = length(var.services) > 0 ? length(var.services) : 0

  name        = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-ecr-event"
  description = "Amazon CloudWatch Events rule to automatically start your pipeline when a change occurs in the Amazon ECR image tag."

  event_pattern = element(data.template_file.ecr_event.*.rendered, count.index)

  depends_on = ["aws_codepipeline.this"]
}

resource "aws_cloudwatch_event_target" "events" {
  count = length(var.services) > 0 ? length(var.services) : 0

  rule      = element(aws_cloudwatch_event_rule.events.*.name, count.index)
  target_id = "${var.name}-${terraform.workspace}-${element(keys(var.services), count.index)}-codepipeline"
  arn       = element(aws_codepipeline.this.*.arn, count.index)
  role_arn  = element(aws_iam_role.events.*.arn, count.index)
}

### End Remove

