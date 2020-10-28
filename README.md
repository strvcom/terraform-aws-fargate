# AWS Fargate Terraform module

[![Build Status][travis-badge]][travis-home]

> This is a collaborative attempt to provide alternative deployment target to Heroku, by using Fargate instead. Since deploying to AWS in general is much more complex to set up compared to Heroku, this repository's goal is to provide a simple, easy to use setup & deployment pipeline to make it easier for general use.

## About

The goal of this effort is to provide tools/configuration files/scripts/other to make it easy to prepare AWS infrastructure for deploying Docker containers to Fargate. At the same time it should not get in the way to allow the deployment runtime to utilise other AWS resources relatively easily.

## Why "re-implement" Heroku via AWS/Terraform

- Cost savings
- More control over infrastructure
- Gain knowledge about AWS/DevOps experience
- Only a single cloud provider, all under one roof -> less configuration hassle

## Ideal developer deployment lifecycle

- Deploy this module to prepare all the infrastructure
- Build a Docker image (not part of this project)
- Push the Docker image to ECR
- ECR triggers a new deployment via CodePipeline automatically

## Technical architecture

- VPC (with public/private subnets, NAT gateway for private subnet)
- ECR repository (Docker Container Registry)
- ECS Cluster + Task definitions
- Application Load Balancer (optional SSL/TLS endpoint)
- CodePipeline (triggered by new pushed Docker images)
- CodePipeline SNS' events (can be used to trigger something else!)
- CloudWatch Logs group
- CloudWatch Metrics Dashboard

## Note: This module is compatible only with Terraform version >=0.12. Last TF 0.11.x version compatible is, well, module's version [0.11.4][0.11-compatible].

![Diagram][diagram]

## Usage

```HCL
module "fargate" {
  source  = "strvcom/fargate/aws"
  version = "0.17.0"

  name = "usage-example" # String, Required: this name will be used for many components of your infrastructure (vpc, loadbalancer, ecs cluster, etc...)

  vpc_create = true # Boolean, Optional: variable that tells the module whether or not to create its own VPC. default = true
  vpc_external_id = "vpc-xxxxxxx" # String, Optional: tells the module to use an already create vpc to ingrate with the ecs cluster. vpc_create MUST be false otherwise this value is ignored

  vpc_cidr = "10.0.0.0/16" # String, Optional: the vpc's CIDR to be used when vpc_create is true. default = "10.0.0.0/16"

  vpc_public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] # List[String], Optional: public subnets' CIDRs. default = [10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24].
  vpc_private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"] # List[String], Optional: private subnets' CIDRs. default = [10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24].

  vpc_external_public_subnets_ids = ["subnet-xxxxxx"] # List[String], Optional: lists of ids of external public subnets. var.vpc_create must be false, otherwise, this variable will be ignored.
  vpc_external_private_subnets_ids = ["subnet-xxxxxx"] # List[String], Optional: lists of ids of external private subnets. var.vpc_create must be false, otherwise, this variable will be ignored.

  codepipeline_events_enabled = true # Boolean, Optional: sns topic that exposes codepipeline events such as STARTED, FAILED, SUCCEEDED, CANCELED for new deployments. default = false.

  ssm_allowed_parameters = "backend_*" # String, Optional: SSM parameter prefix. Allows the tasks to pull and use SSM parameters during task bootstrap. In case of requiring parameters from a different region, specify the full ARN string.

  services = { # Map, Required: the main object containing all information regarding fargate services
    name_of_your_service = { # Map, Required at least one: object containing specs of a specific Fargate service.
      task_definition = "api.json" # String, Required: string matching a valid ECS Task definition json file. This is a relative path ⚠️.
      container_port  = 3000 # Number, Required: tcp port that the tasks will be listening to.
      cpu             = "256" # String, Required: CPU units used by the tasks
      memory          = "512" # String, Required: memory used by the tasks
      replicas        = 5 # Number, Required: amount of task replicas needed for the ecs service

      registry_retention_count = 15 # Number, Optional: sets how many images does the ecr registry will retain before recycling old ones. default = 20
      logs_retention_days      = 14 # Number, Optional: sets how many days does the cloud watch log group will retain logs entries before deleting old ones. default = 30

      alb_create            = true #  Boolean, Optional: enables application load balancer. default = true
      health_check_interval = 100 # Number, Optional: sets the interval in seconds for the health check operation. default = 30
      health_check_path     = "/healthz" # String, Optional: sets the path that the tasks are exposing to perform health checks. default = "/"

      task_role_arn = "arn:...." # String(valid ARN), Optional: sets a IAM role to the running ecs task.

      acm_certificate_arn = "arn:...." # String(valid ARN), Optional: turns on the HTTPS listener on the ALB. This certificate should be an already allocated in ACM.

      auto_scaling_max_replicas = 5 # Number, Optional: sets the max replicas that this service can scale up. default = same as replicas
      auto_scaling_max_cpu_util = 60 # Number, Optional: the avg CPU utilization needed to trigger a auto scaling operation

      allow_connections_from = ["api2"] # List[String], Optional: By default all services can only accept connections from their ALB. To explicitly allow connections from one service to another, use this label. This means that THIS service can be reached by service `api2`

      service_discovery_enabled = true # Boolean, Optional: enables service discovery by creating a private Route53 zone. <service_name>.<cluster_name>.<terraform_workspace>.local

  }

    another_service = {
      ...
    }
  }
}
```

And a very basic example of how an `api.json` file should look like

```json
[
  {
    "portMappings": [
      {
        "hostPort": ${container_port},
        "protocol": "tcp",
        "containerPort": ${container_port}
      }
    ],
    "image": "${repository_url}:latest",
    "name": "${container_name}",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${log_group}",
        "awslogs-region": "${region}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
```

### Template variables
Notice that `hostPort`/`containerPort` gets populated by the `container_port` variable set on the module definition. This is to avoid repeating ourselves and keep one single source of truth.

Other variables:

- `repository_url` is the generated URL for the ECR registry for this specific service
- `container_name` is exactly the name you gave to the service in the module definition.
- `log_group` is a name generated during the module execution. If you have an already created log group you can put it here.
- `region` is the chosen AWS region for the module execution

> Note that the format of this `api.json` example is not made up by this module at all, this follows AWS Task definition (Container definition) format which you can check properly [here](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#container_definitions)

Here are the examples for different use cases 😊

- [Basic][basic-usage]
- [HTTPS enabled][https-usage]
- [AutoScaling][autoscaling-usage]
- [External VPC][external-vpc-usage]
- [Cross security groups between services][cross-sg-services]

## Roadmap

- [x] Automatically deploy Docker containers when pushed to ECR
- [x] Send container logs to CloudWatch
- [x] Basic health information in CloudWatch Logs/Metrics
- [x] Optional NAT Gateway
- [x] App Auto Scaling
- [x] Optional Application Load Balancer
- [ ] External Docker image deployment - No ECR registry for that service
- [ ] Predefined alarms about container status
- [ ] Predefined Docker images to simplify some aspects of deployment/runtime (ie. the image will be able to collect Node.js runtime metrics etc.)

## LICENSE

See the [LICENSE][license] file for information.

[travis-badge]: https://travis-ci.com/strvcom/terraform-aws-fargate.svg?branch=master
[travis-home]: https://travis-ci.com/strvcom/terraform-aws-fargate
[license]: LICENSE
[diagram]: diagram.png
[basic-usage]: examples/basic
[https-usage]: examples/https_enabled
[autoscaling-usage]: examples/autoscaling
[external-vpc-usage]: examples/external_vpc
[cross-sg-services]: examples/cross-sg-services
[0.11-compatible]: https://github.com/strvcom/terraform-aws-fargate/tree/0.11.4
