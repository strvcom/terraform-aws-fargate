# HTTPS enabled example

## Usage

To run this example you need to execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Notice that the Auto Scaling configuration set by this module will be listening only to the [CPU average utilization metric](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html).

If you want to configure Auto Scaling by using different metrics, you would need to set the Terraform resources [separately](https://www.terraform.io/docs/providers/aws/r/appautoscaling_policy.html).

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
