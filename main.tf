# Main Module file

terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = ">= 2.12.0"
  }
}

provider "random" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

# VPC CONFIGURATION

locals {
  vpc_id = ! var.vpc_create ? var.vpc_external_id : module.vpc.vpc_id

  vpc_public_subnets = (
    length(var.vpc_public_subnets) > 0 || ! var.vpc_create ?
    var.vpc_public_subnets :
    list(
      cidrsubnet(var.vpc_cidr, 8, 1),
      cidrsubnet(var.vpc_cidr, 8, 2),
      cidrsubnet(var.vpc_cidr, 8, 3)
    )
  )

  vpc_private_subnets = (
    length(var.vpc_private_subnets) > 0 || ! var.vpc_create ?
    var.vpc_private_subnets :
    list(
      cidrsubnet(var.vpc_cidr, 8, 101),
      cidrsubnet(var.vpc_cidr, 8, 102),
      cidrsubnet(var.vpc_cidr, 8, 103)
    )
  )

  vpc_private_subnets_ids = ! var.vpc_create ? var.vpc_external_private_subnets_ids : module.vpc.private_subnets

  vpc_public_subnets_ids = ! var.vpc_create ? var.vpc_external_public_subnets_ids : module.vpc.public_subnets

  services       = [for k, v in var.services : merge({ "name" : k }, v)]
  services_count = length(var.services)

  # ⚠️ remove when https://github.com/hashicorp/terraform/issues/22560 gets fixed
  services_with_sd = [for s in local.services : s if lookup(s, "service_discovery_enabled", false)]
}

data "aws_availability_zones" "this" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.9.0"

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
  count = local.services_count > 0 ? local.services_count : 0

  name = "${local.services[count.index].name}-${terraform.workspace}"
}

data "template_file" "ecr-lifecycle" {
  count = local.services_count > 0 ? local.services_count : 0

  template = file("${path.module}/policies/ecr-lifecycle-policy.json")

  vars = {
    count = lookup(local.services[count.index], "registry_retention_count", var.ecr_default_retention_count)
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  count = local.services_count > 0 ? local.services_count : 0

  repository = aws_ecr_repository.this[count.index].name

  policy = data.template_file.ecr-lifecycle[count.index].rendered
}

# ECS CLUSTER

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-${terraform.workspace}-cluster"
}

# ECS TASKS DEFINITIONS

resource "aws_iam_role" "tasks_execution" {
  name               = "${var.name}-${terraform.workspace}-task-execution-role"
  assume_role_policy = file("${path.module}/policies/ecs-task-execution-role.json")
}

resource "aws_iam_policy" "tasks_execution" {
  name = "${var.name}-${terraform.workspace}-task-execution-policy"

  policy = file("${path.module}/policies/ecs-task-execution-role-policy.json")
}

resource "aws_iam_role_policy_attachment" "tasks_execution" {
  role       = aws_iam_role.tasks_execution.name
  policy_arn = aws_iam_policy.tasks_execution.arn
}

data "template_file" "tasks_execution_ssm" {
  count = var.ssm_allowed_parameters != "" ? 1 : 0

  template = file("${path.module}/policies/ecs-task-execution-role-policy-ssm.json")

  vars = {
    ssm_parameters_arn = replace(var.ssm_allowed_parameters, "arn:aws:ssm", "") == var.ssm_allowed_parameters ? "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_allowed_parameters}" : var.ssm_allowed_parameters
  }
}

resource "aws_iam_policy" "tasks_execution_ssm" {
  count = var.ssm_allowed_parameters != "" ? 1 : 0

  name = "${var.name}-${terraform.workspace}-task-execution-ssm-policy"

  policy = data.template_file.tasks_execution_ssm[count.index].rendered
}

resource "aws_iam_role_policy_attachment" "tasks_execution_ssm" {
  count = var.ssm_allowed_parameters != "" ? 1 : 0

  role       = aws_iam_role.tasks_execution.name
  policy_arn = aws_iam_policy.tasks_execution_ssm[count.index].arn
}

data "template_file" "tasks" {
  count = local.services_count > 0 ? local.services_count : 0

  template = file("${path.cwd}/${local.services[count.index].task_definition}")

  vars = {
    container_name = local.services[count.index].name
    container_port = local.services[count.index].container_port
    repository_url = aws_ecr_repository.this[count.index].repository_url
    log_group      = aws_cloudwatch_log_group.this[count.index].name
    region         = var.region != "" ? var.region : data.aws_region.current.name
  }
}

resource "aws_ecs_task_definition" "this" {
  count = local.services_count > 0 ? local.services_count : 0

  family                   = "${var.name}-${terraform.workspace}-${local.services[count.index].name}"
  container_definitions    = data.template_file.tasks[count.index].rendered
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.services[count.index].cpu
  memory                   = local.services[count.index].memory
  execution_role_arn       = aws_iam_role.tasks_execution.arn
  task_role_arn            = lookup(local.services[count.index], "task_role_arn", null)
}

data "aws_ecs_task_definition" "this" {
  count = local.services_count > 0 ? local.services_count : 0

  task_definition = element(aws_ecs_task_definition.this[*].family, count.index)

  # This avoid fetching an unexisting task definition before its creation
  depends_on = [aws_ecs_task_definition.this]
}

resource "aws_cloudwatch_log_group" "this" {
  count = local.services_count > 0 ? local.services_count : 0

  name = "/ecs/${var.name}-${local.services[count.index].name}"

  retention_in_days = lookup(local.services[count.index], "logs_retention_days", var.cloudwatch_logs_default_retention_days)
}

# SECURITY GROUPS

resource "aws_security_group" "web" {
  vpc_id = local.vpc_id
  name   = "${var.name}-${terraform.workspace}-web-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "services" {
  count = local.services_count > 0 ? local.services_count : 0

  vpc_id = local.vpc_id
  name   = "${var.name}-${local.services[count.index].name}-${terraform.workspace}-services-sg"

  ingress {
    from_port       = local.services[count.index].container_port
    to_port         = local.services[count.index].container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Cross-service Security Groups
resource "aws_security_group" "services_dynamic" {
  count = local.services_count > 0 ? local.services_count : 0

  vpc_id = local.vpc_id
  name   = "${var.name}-${local.services[count.index].name}-${terraform.workspace}-services-sg-dynamic"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = [for k, v in var.services : k
      if k != local.services[count.index].name &&
    contains(lookup(local.services[count.index], "allow_connections_from", []), k)]

    content {
      from_port = local.services[count.index].container_port
      to_port   = local.services[count.index].container_port
      protocol  = "tcp"
      security_groups = [for s in aws_security_group.services : s.id
      if lookup(s, "name", "") == "${var.name}-${ingress.value}-${terraform.workspace}-services-sg"]
    }
  }
}

# ALBs

resource "random_id" "target_group_sufix" {
  count = local.services_count > 0 ? local.services_count : 0

  keepers = {
    container_port = local.services[count.index].container_port
  }

  byte_length = 2
}

resource "aws_lb_target_group" "this" {
  for_each = {
    for key, value in local.services :
    key => key
    if lookup(value, "alb_create", true)
  }

  name        = "${var.name}-${local.services[each.key].name}-${random_id.target_group_sufix[each.key].hex}"
  port        = random_id.target_group_sufix[each.key].keepers.container_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    interval            = lookup(local.services[each.key], "health_check_interval", var.alb_default_health_check_interval)
    path                = lookup(local.services[each.key], "health_check_path", var.alb_default_health_check_path)
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-299"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "this" {
  for_each = {
    for key, value in local.services :
    key => key
    if lookup(value, "alb_create", true)
  }

  name            = "${var.name}-${terraform.workspace}-${local.services[each.key].name}-alb"
  subnets         = slice(local.vpc_public_subnets_ids, 0, min(length(data.aws_availability_zones.this.names), length(local.vpc_public_subnets_ids)))
  security_groups = [aws_security_group.web.id]
}

resource "aws_lb_listener" "this" {
  for_each = aws_lb.this

  load_balancer_arn = aws_lb.this[each.key].arn
  port              = lookup(local.services[each.key], "acm_certificate_arn", "") != "" ? 443 : 80
  protocol          = lookup(local.services[each.key], "acm_certificate_arn", "") != "" ? "HTTPS" : "HTTP"
  ssl_policy        = lookup(local.services[each.key], "acm_certificate_arn", "") != "" ? "ELBSecurityPolicy-FS-2018-06" : null
  certificate_arn   = lookup(local.services[each.key], "acm_certificate_arn", null)
  depends_on        = [aws_lb_target_group.this]

  default_action {
    target_group_arn = aws_lb_target_group.this[each.key].arn
    type             = "forward"
  }
}

# SERVICE DISCOVERY

resource "aws_service_discovery_private_dns_namespace" "this" {
  count = length([for s in local.services : s if lookup(s, "service_discovery_enabled", false)]) > 0 ? 1 : 0

  name        = "${var.name}.${terraform.workspace}.local"
  description = "${var.name} private dns namespace"
  vpc         = local.vpc_id
}

resource "aws_service_discovery_service" "this" {
  # ⚠️ replace when https://github.com/hashicorp/terraform/issues/22560 gets fixed
  # for_each = [for s in local.services : s if lookup(s, "service_discovery_enabled", false)]
  count = length(local.services_with_sd) > 0 ? length(local.services_with_sd) : 0

  # name = each.value.name
  name = local.services_with_sd[count.index].name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this[0].id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ECS SERVICES

resource "aws_ecs_service" "this" {
  count = local.services_count > 0 ? local.services_count : 0

  name          = local.services[count.index].name
  cluster       = aws_ecs_cluster.this.name
  desired_count = local.services[count.index].replicas
  launch_type   = "FARGATE"

  task_definition = "${aws_ecs_task_definition.this[count.index].family}:${max(
    aws_ecs_task_definition.this[count.index].revision,
    length(data.aws_ecs_task_definition.this) >= count.index ? data.aws_ecs_task_definition.this[count.index].revision : 1
  )}"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    security_groups = [
      aws_security_group.services[count.index].id,
      aws_security_group.services_dynamic[count.index].id
    ]

    subnets          = var.vpc_create_nat ? local.vpc_private_subnets_ids : local.vpc_public_subnets_ids
    assign_public_ip = ! var.vpc_create_nat
  }

  dynamic load_balancer {
    for_each = lookup(local.services[count.index], "alb_create", true) ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[count.index].arn
      container_name   = local.services[count.index].name
      container_port   = local.services[count.index].container_port
    }
  }

  dynamic "service_registries" {
    for_each = [for s in aws_service_discovery_service.this : s if s.name == local.services[count.index].name]

    content {
      registry_arn = service_registries.value.arn
    }
  }

  depends_on = [aws_lb_target_group.this, aws_lb_listener.this]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_iam_role" "autoscaling" {
  name               = "${var.name}-${terraform.workspace}-appautoscaling-role"
  assume_role_policy = file("${path.module}/policies/appautoscaling-role.json")
}

resource "aws_iam_role_policy" "autoscaling" {
  name   = "${var.name}-${terraform.workspace}-appautoscaling-policy"
  policy = file("${path.module}/policies/appautoscaling-role-policy.json")
  role   = aws_iam_role.autoscaling.id
}

resource "aws_appautoscaling_target" "this" {
  count = local.services_count > 0 ? local.services_count : 0

  max_capacity       = lookup(local.services[count.index], "auto_scaling_max_replicas", local.services[count.index].replicas)
  min_capacity       = local.services[count.index].replicas
  resource_id        = "service/${aws_ecs_cluster.this.name}/${local.services[count.index].name}"
  role_arn           = aws_iam_role.autoscaling.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.this]
}

resource "aws_appautoscaling_policy" "this" {
  count = local.services_count > 0 ? local.services_count : 0

  name               = "${local.services[count.index].name}-autoscaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.this[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = lookup(local.services[count.index], "auto_scaling_max_cpu_util", 100)

    scale_in_cooldown  = 300
    scale_out_cooldown = 300

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }

  depends_on = [aws_appautoscaling_target.this]
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
  count = local.services_count > 0 ? local.services_count : 0

  template = file("${path.module}/build/buildspec.yml")

  vars = {
    container_name = local.services[count.index].name
  }
}

resource "aws_codebuild_project" "this" {
  count = local.services_count > 0 ? local.services_count : 0

  name          = "${var.name}-${terraform.workspace}-${local.services[count.index].name}-builds"
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
    buildspec = element(data.template_file.buildspec[*].rendered, count.index)
  }
}

# CODEPIPELINE
resource "aws_iam_role" "codepipeline" {
  count = local.services_count > 0 ? local.services_count : 0

  name = "${var.name}-${terraform.workspace}-${local.services[count.index].name}-codepipeline-role"

  assume_role_policy = file("${path.module}/policies/codepipeline-role.json")
}

data "template_file" "codepipeline" {
  count = local.services_count > 0 ? local.services_count : 0

  template = file("${path.module}/policies/codepipeline-role-policy.json")

  vars = {
    aws_s3_bucket_arn  = aws_s3_bucket.this.arn
    ecr_repository_arn = aws_ecr_repository.this[count.index].arn
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  count = local.services_count > 0 ? local.services_count : 0

  name   = "${var.name}-${terraform.workspace}-${local.services[count.index].name}-codepipeline-role-policy"
  role   = aws_iam_role.codepipeline[count.index].id
  policy = data.template_file.codepipeline[count.index].rendered
}

resource "aws_codepipeline" "this" {
  count = local.services_count > 0 ? local.services_count : 0

  name     = "${var.name}-${terraform.workspace}-${local.services[count.index].name}-pipeline"
  role_arn = aws_iam_role.codepipeline[count.index].arn

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
        RepositoryName = aws_ecr_repository.this[count.index].name
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
        ProjectName = "${var.name}-${terraform.workspace}-${local.services[count.index].name}-builds"
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
        ServiceName = local.services[count.index].name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  depends_on = [aws_iam_role_policy.codebuild, aws_ecs_service.this]
}

# CODEPIPELINE STATUS SNS

data "template_file" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  template = file("${path.module}/cloudwatch/codepipeline-source-event.json")

  vars = {
    codepipeline_names = jsonencode(aws_codepipeline.this[*].name)
  }
}

data "template_file" "codepipeline_events_sns" {
  count = var.codepipeline_events_enabled ? 1 : 0

  template = file("${path.module}/policies/sns-cloudwatch-events-policy.json")

  vars = {
    sns_arn = aws_sns_topic.codepipeline_events[count.index].arn
  }
}

resource "aws_cloudwatch_event_rule" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  name        = "${var.name}-${terraform.workspace}-pipeline-events"
  description = "Amazon CloudWatch Events rule to automatically post SNS notifications when CodePipeline state changes."

  event_pattern = data.template_file.codepipeline_events[count.index].rendered
}

resource "aws_sns_topic" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  name         = "${var.name}-${terraform.workspace}-codepipeline-events"
  display_name = "${var.name}-${terraform.workspace}-codepipeline-events"
}

resource "aws_sns_topic_policy" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  arn = aws_sns_topic.codepipeline_events[count.index].arn

  policy = data.template_file.codepipeline_events_sns[count.index].rendered
}

resource "aws_cloudwatch_event_target" "codepipeline_events" {
  count = var.codepipeline_events_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.codepipeline_events[count.index].name
  target_id = "${var.name}-${terraform.workspace}-codepipeline"
  arn       = aws_sns_topic.codepipeline_events[count.index].arn
}

### CLOUDWATCH BASIC DASHBOARD

data "template_file" "metric_dashboard" {
  for_each = aws_lb.this

  template = file("${path.module}/metrics/basic-dashboard.json")

  vars = {
    region         = var.region != "" ? var.region : data.aws_region.current.name
    alb_arn_suffix = aws_lb.this[each.key].arn_suffix
    cluster_name   = aws_ecs_cluster.this.name
    service_name   = local.services[each.key].name
  }
}

resource "aws_cloudwatch_dashboard" "this" {
  for_each = data.template_file.metric_dashboard

  dashboard_name = "${var.name}-${terraform.workspace}-${local.services[each.key].name}-metrics-dashboard"

  dashboard_body = data.template_file.metric_dashboard[each.key].rendered
}

data "template_file" "metric_dashboard_no_alb" {
  for_each = {
    for key, value in local.services :
    key => key
    if ! lookup(value, "alb_create", true)
  }

  template = file("${path.module}/metrics/basic-dashboard-no-alb.json")

  vars = {
    region       = var.region != "" ? var.region : data.aws_region.current.name
    cluster_name = aws_ecs_cluster.this.name
    service_name = local.services[each.key].name
  }
}

resource "aws_cloudwatch_dashboard" "this_no_alb" {
  for_each = data.template_file.metric_dashboard_no_alb

  dashboard_name = "${var.name}-${terraform.workspace}-${local.services[each.key].name}-metrics-dashboard"

  dashboard_body = data.template_file.metric_dashboard_no_alb[each.key].rendered
}

resource "aws_iam_role" "events" {
  count = local.services_count > 0 ? local.services_count : 0

  name = "${var.name}-${terraform.workspace}-${local.services[count.index].name}-events-role"

  assume_role_policy = file("${path.module}/policies/events-role.json")
}

data "template_file" "events" {
  count = local.services_count > 0 ? local.services_count : 0

  template = file("${path.module}/policies/events-role-policy.json")

  vars = {
    codepipeline_arn = aws_codepipeline.this[count.index].arn
  }
}

resource "aws_iam_role_policy" "events" {
  count = local.services_count > 0 ? local.services_count : 0

  name   = "${var.name}-${terraform.workspace}-${local.services[count.index].name}-events-role-policy"
  role   = aws_iam_role.events[count.index].id
  policy = data.template_file.events[count.index].rendered
}

data "template_file" "ecr_event" {
  count = local.services_count > 0 ? local.services_count : 0

  template = file("${path.module}/cloudwatch/ecr-source-event.json")

  vars = {
    ecr_repository_name = aws_ecr_repository.this[count.index].name
  }
}

resource "aws_cloudwatch_event_rule" "events" {
  count = local.services_count > 0 ? local.services_count : 0

  name        = "${var.name}-${terraform.workspace}-${local.services[count.index].name}-ecr-event"
  description = "Amazon CloudWatch Events rule to automatically start your pipeline when a change occurs in the Amazon ECR image tag."

  event_pattern = data.template_file.ecr_event[count.index].rendered

  depends_on = [aws_codepipeline.this]
}

resource "aws_cloudwatch_event_target" "events" {
  count = local.services_count > 0 ? local.services_count : 0

  rule      = aws_cloudwatch_event_rule.events[count.index].name
  target_id = "${var.name}-${terraform.workspace}-${local.services[count.index].name}-codepipeline"
  arn       = aws_codepipeline.this[count.index].arn
  role_arn  = aws_iam_role.events[count.index].arn
}
