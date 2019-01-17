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

  name = "basic-example"

  services = {
    api = {
      task_definition = "api.json"
      container_port  = 3000
      cpu             = "256"
      memory          = "512"
      replicas        = 3

      registry_retention_count = 15 # Optional. 20 by default
      logs_retention_days      = 14 # Optional. 30 by default

      # To activate SSL Listener (HTTPS) set the ARN of the ACM certificate here! 🔑
      # acm_certificate_arn = "arn:......"
    }
  }

  # ChatOps Lambda function

  slack_chatops_enabled = true
  slack_config         = {
    webhook_url = "https://slack.webhook.url"
    channel     = "some_devops_channel"
    username    = "reporter"
  }
}
