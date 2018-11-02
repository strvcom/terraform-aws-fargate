# Fargate Backend

[![Build Status][travis-badge]][travis-home]

> This is a collaborative attempt to provide alternative deployment target to Heroku, by using Fargate instead. Since deploying to AWS in general is much more complex to set up compared to Heroku, this repository's goal is to provide a simple, easy to use setup & deployment pipeline to make it easier for general use.

## About

The goal of this effort is to provide tools/configuration files/scripts/other to make it easy to prepare AWS infrastructure for deploying Docker containers to Fargate. At the same time it should not get in the way to allow the deployment runtime to utilise other AWS resources relatively easily.

The expectations currently are that Terraform will be used for setting up some kind of deployment pipeline and then the actual deployment of Docker images will be handled by some other, currently unknown tool (because deploying code with Terraform generally sucks 💩)

## Why re-implement Heroku via AWS/Terraform

- Cost savings
- More control over infrastructure
- Gain knowledge about AWS/DevOps experience
- Sell this to clients as a service!
- Only a single cloud provider, all under one roof -> less configuration hassle

## Ideal developer deployment lifecycle

- Deploy this thing with Terraform to prepare all the infrastructure
- Build a Docker image (not part of this project)
- Push the Docker image to ECR
- Docker image is picked up by AWS and deployed automatically

### v1

- Automatically deploy Docker containers when pushed to ECR (at worst, manually trigger a lambda function or similar to start the deployment process)
- Send container logs to CloudWatch

### v2

- Predefined alarms about container status
- Basic health information in CloudWatch Logs/Metrics
- Autoscaling group

### v3

- Predefined Docker images to simplify some aspects of deployment/runtime (ie. the image will be able to collect Node.js runtime metrics etc.)

## Technical architecture - bird's view

- VPC
- ECR (Container registry)
- Cluster + Service + Task Definition
- Application Load Balancer
- Trigger to deploy newly pushed Docker images to the ECS (lambda? CloudDeploy? CloudPipeline? Other?)
- CloudWatch Logs

## LICENSE

See the [LICENSE](LICENSE) file for information.

[travis-badge]: https://travis-ci.com/strvcom/fargate-backend.svg?token=xwhuCSHsE2sXJPqUYAsC&branch=master
[travis-home]: https://travis-ci.com/strvcom/fargate-backend
