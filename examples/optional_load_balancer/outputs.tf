//# VPC
//output "vpc" {
//  value = "${module.fargate.vpc}"
//}
//
//# ECR
//output "ecr" {
//  value = "${module.fargate.ecr_repository}"
//}
//
//# ECS Cluster
//output "ecs_cluster" {
//  value = "${module.fargate.ecs_cluster}"
//}
//
//# ALBs
//output "application_load_balancers" {
//  value = "${module.fargate.application_load_balancers}"
//}
//
//# Security Groups
//output "web_security_group" {
//  value = "${module.fargate.web_security_group}"
//}
//
//output "services_security_groups" {
//  value = "${module.fargate.services_security_groups}"
//}
//
//# CloudWatch
//output "cloudwatch_log_groups" {
//  value = "${module.fargate.cloudwatch_log_groups}"
//}
