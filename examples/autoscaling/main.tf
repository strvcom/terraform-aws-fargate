terraform {
  required_version = "~> 0.11.11"
}

provider "aws" {
  version = "~> 1.54.0"
  region  = "us-east-1"
  profile = "playground"
}

module "fargate" {
  source = "../../"

  name = "autoscaling-example"

  services = {
    api = {
      task_definition = "../basic/api.json"
      container_port  = 3000
      cpu             = "256"
      memory          = "512"
      replicas        = 3

      auto_scaling_max_replicas     = 5  // Will scale out up to 5 replicas
      auto_scaling_max_cpu_util = 60 // If Avg CPU Utilization reaches 60%, scale up operations gets triggered
    }
  }
}
