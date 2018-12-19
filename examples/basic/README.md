# Basic example

## Usage

First update both `repo_name` and `repo_owner` with a Github repository and valid username respectively

> This probably will change in the future by setting the source as the [ECR repository](https://aws.amazon.com/about-aws/whats-new/2018/11/the-aws-developer-tools-improve-continuous-delivery-support-for-aws-fargate-and-amazon-ecs/) instead of a Github repository

And then, to run this example you need to execute:

```bash
$ terraform init
$ terraform plan
$ GITHUB_TOKEN=<token> terraform apply
```

Note that this example create resources which can cost money (AWS Fargate Services, for example). Run `terraform destroy` when you don't need these resources.

## Outputs

| Name | Description |
|------|-------------|
| vpc | VPC created for ECS cluster |
| ecr | ECR Docker registry for Docker images |
| ecs_cluster | ECS cluster |
| application_load_balancers | ALBs which expose ECS services |
| web_security_group | Security groups attached to ALBs |
| services_security_groups | Security groups attached to ECS services |
| cloudwatch_log_groups | CloudWatch groups for ECS services |
