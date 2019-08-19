# ⚠️ Only for TF version >=0.12

terraform {
  required_version = "~> 0.12.0"
}

provider "aws" {
  version = "~> 2.12.0"
  region  = "us-east-1"
  profile = "playground"
}

module "fargate" {
  source = "../../"

  name = "cross-sg-example"

  services = {
    api = {
      task_definition = "../basic/api.json"
      container_port  = 3000
      cpu             = "256"
      memory          = "512"
      replicas        = 3
    }

    api2 = {
      task_definition = "../basic/api.json" # Does not need to be the same service ofc
      container_port  = 3000
      cpu             = "512"
      memory          = "1024"
      replicas        = 1

      # To explicitly allow connections from one service to another, use this label "allow_connections_from: array[string]"
      # Service "api" will be able to reach "api2" thru HTTP
      allow_connections_from = ["api"]
    }
  }
}
