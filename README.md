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
- ECR repository (Container registry)
- ECS Cluster + Task definition
- Application Load Balancer (optional SSL/TLS endpoint)
- CodePipeline (triggered by new pushed Docker images)
- CodePipeline SNS' events (cam be used to trigger something else!)
- CloudWatch Logs group
- CloudWatch Metrics Dashboard

![Diagram][diagram]

## Roadmap

- [x] Automatically deploy Docker containers when pushed to ECR
- [x] Send container logs to CloudWatch
- [x] Basic health information in CloudWatch Logs/Metrics
- [x] Optional NAT Gateway
- [x] App Auto Scaling
- [ ] Optional Application Load Balancer
- [ ] External Docker image deployment - No ECR registry for that service
- [ ] Predefined alarms about container status
- [ ] Predefined Docker images to simplify some aspects of deployment/runtime (ie. the image will be able to collect Node.js runtime metrics etc.)

## Usage

- [Basic][basic-usage]
- [HTTPS enabled][https-usage]
- [AutoScaling][autoscaling-usage]

## LICENSE

See the [LICENSE][license] file for information.

[travis-badge]: https://travis-ci.com/strvcom/terraform-aws-fargate.svg?branch=master
[travis-home]: https://travis-ci.com/strvcom/terraform-aws-fargate
[license]: LICENSE
[diagram]: diagram.png
[basic-usage]: examples/basic
[https-usage]: examples/https_enabled
[autoscaling-usage]: examples/autoscaling
