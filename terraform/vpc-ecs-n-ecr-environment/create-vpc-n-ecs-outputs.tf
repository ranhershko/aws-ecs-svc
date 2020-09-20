#output "vpc_subnets" {
#  value = aws_security_group.awsecs_private.id
#}

output "lb_target_group_arn" {
  value = module.ecs-alb.target_group_arn
}

output "ecs_cluster_id" {
  value = module.ecs_cluster.cluster_id
}
