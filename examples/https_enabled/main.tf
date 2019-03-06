terraform {
  required_version = "~> 0.11.11"
}

provider "aws" {
  version = "~> 1.54.0"
  region  = "us-east-1"
  profile = "playground"
}

## Domain Aliases and SSL config

data "aws_route53_zone" "this" {
  name         = "https-example.dev."
  private_zone = false
}

resource "aws_acm_certificate" "this" {
  domain_name       = "this-is-my.https-example.dev"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.this.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.this.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.this.id}"
  records = ["${aws_acm_certificate.this.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = "${aws_acm_certificate.this.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}

resource "aws_route53_record" "subdomain" {
  name    = "this-is-my.https-example.dev"
  zone_id = "${data.aws_route53_zone.this.id}"
  type    = "A"

  alias {
    name                   = "${module.fargate.application_load_balancers_dns_names[0]}" # Position 0 because we only have one Fargate service (api)
    zone_id                = "${module.fargate.application_load_balancers_zone_ids[0]}"  # Same here
    evaluate_target_health = true
  }
}

# Module definition here!

module "fargate" {
  source = "../../"

  name = "https-example"

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
      acm_certificate_arn = "${aws_acm_certificate.this.arn}"
    }
  }
}

## After all of this, you should be able to visit make requests to the service hitting https://this-is-my.https-example.dev
## Ofc, if you were the owner of "https-exampke.dev" domain 😅

