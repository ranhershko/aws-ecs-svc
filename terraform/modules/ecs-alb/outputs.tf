output "listener_https_arn" {
  description = "The ARN of the HTTPS ALB Listener that can be used to add rules"
  value       = module.alb.https_listener_arns
  #value       = module.alb.alb_listener_https_arns
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.alb.target_group_arns
}
