terraform {
  required_version = "~> 0.11.11"
}

provider "aws" {
  version = "~> 1.54.0"
  profile = "test"
}

variable "name" {}

module "fargate" {
  source = "../fargate-module"

  vpc_create_nat = false

  name = "${var.name}"

  services = {
    api = {
      task_definition = "api.json"
      container_port  = 3000
      cpu             = "256"
      memory          = "512"
      replicas        = 3

      registry_retention_count = 15
      logs_retention_days      = 14
    }
  }

  codepipeline_events_enabled = true
}
