terraform {
  required_version = ">= 0.11"
}

resource "aws_security_group_rule" "instance_in_alb" {
  type                     = "ingress"
  from_port                = 32768
  to_port                  = 61000
  protocol                 = "tcp"
  source_security_group_id = module.alb_sg_https.this_security_group_id
  security_group_id        = var.backend_sg_id
}

module "alb_sg_https" {
  source  = "../terraform-aws-security-group"
  #source  = "terraform-aws-modules/security-group/aws"
  #version = "~> 1.20.0"

  name   = "${var.name}-alb"
  vpc_id = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags = var.tags
}

module "alb" {
  source  = "../terraform-aws-alb"
  #source  = "terraform-aws-modules/alb/aws"
  #version = "~> 2.5.0"

  #alb_is_internal     = var.internal
  name_prefix            = "alb"
  #alb_name            = var.name
  name            = var.name
  #alb_protocols       = ["HTTPS"]
  #alb_security_groups = [module.alb_sg_https.this_security_group_id]
  security_groups = [module.alb_sg_https.this_security_group_id]

  #backend_port     = var.backend_port
  #backend_protocol = var.backend_protocol

  target_groups    = [{name=var.name, name_prefix="alb", backend_port=var.backend_port, backend_protocol=var.backend_protocol, healthy_threshold=var.health_check_healthy_threshold, interval=var.health_check_interval, matcher=var.health_check_matcher, path=var.health_check_path, port=var.health_check_port, timeout=var.health_check_timeout, unhealthy_threshold=var.health_check_unhealthy_threshold}]

  https_listeners = [{port="443", protocol="HTTPS", certificate_arn=var.certificate_arn}]
  #certificate_arn = var.certificate_arn

  #health_check_healthy_threshold   = var.health_check_healthy_threshold
  #health_check_interval            = var.health_check_interval
  #health_check_matcher             = var.health_check_matcher
  #health_check_path                = var.health_check_path
  #health_check_port                = var.health_check_port
  #health_check_timeout             = var.health_check_timeout
  #health_check_unhealthy_threshold = var.health_check_unhealthy_threshold

  access_logs = merge({enabled=var.create_log_bucket}, {bucket= var.log_bucket_name != "" ? var.log_bucket_name : format("%s-logs", var.name)}, {prefix="alb"})
  #create_log_bucket        = var.create_log_bucket
  #enable_logging           = var.enable_logging
  #force_destroy_log_bucket = var.force_destroy_log_bucket
  #access_logs               = merge(access_logs, {bucket= var.log_bucket_name != "" ? var.log_bucket_name : format("%s-logs", var.name)})
  #access_logs               = merge(access_logs, {prefix="alb"})
  #log_location_prefix      = "alb"

  subnets = var.vpc_subnets
  tags    = var.tags
  vpc_id  = var.vpc_id
}

resource "aws_route53_zone" "domain" {
  name = var.domain_name

  vpc {
    vpc_id = var.vpc_id
  }
}

#data "aws_route53_zone" "domain" {
  #name         = "${var.domain_name}."
  #private_zone = var.private_zone
#}

#resource "aws_route53_record" "hostname" {
#  zone_id = aws_route53_zone.domain.zone_id
#  name    = var.host_name != "" ? format("%s.%s", var.host_name, aws_route53_zone.domain.name) : format("%s", aws_route53_zone.domain.name)
#  type    = "A"
#  ttl     = "300"
#
#  #alias {
#    #name                   = module.alb.alb_dns_name
#    #zone_id                = module.alb.alb_zone_id
#    #evaluate_target_health = true
#  #}
#}
