# HTTPS enabled example

## Usage

To run this example you need to execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Also, you will need a valid ACM certificate (SSL/TLS) and associate it to the Fargate service you would like to enable HTTPS.

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
