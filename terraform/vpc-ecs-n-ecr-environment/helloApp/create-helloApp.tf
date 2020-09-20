
resource "aws_ecs_task_definition" "app" {
  family = "ecs-alb-single-svc"

  container_definitions = <<EOF
[
  {
    "name": "nginx",
    "image": "nginx:1.13-alpine",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "ecs-alb-single-svc-nginx",
        "awslogs-region": "us-east-1"
      }
    },
    "memory": 128,
    "cpu": 100
  }
]
EOF
}

module "ecs_service_app" {
  source = "../../modules/service"

  name                 = "ecs-alb-single-svc"
  alb_target_group_arn = tostring(data.terraform_remote_state.vpc-n-ecs.outputs.lb_target_group_arn[0])
  cluster              = data.terraform_remote_state.vpc-n-ecs.outputs.ecs_cluster_id
  container_name       = "nginx"
  container_port       = "80"
  log_groups           = ["ecs-alb-single-svc-nginx"]
  task_definition_arn  = aws_ecs_task_definition.app.arn

  tags = {
    Owner       = "user"
    Environment = "me"
  }
}
