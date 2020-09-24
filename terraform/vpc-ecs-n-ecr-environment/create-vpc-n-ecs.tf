module "vpc" {
  source             = "../modules/vpc"
  aws_avail_zones = data.aws_availability_zones.available.names
  aws_private_subnets_cidr = var.aws_private_subnets_cidr
  aws_public_subnets_cidr = var.aws_public_subnets_cidr
  aws_vpc_cidr_block = var.aws_vpc_cidr_block
  default_tags = var.default_tags
  project_name = var.project_name
}

resource "tls_private_key" "awsecs" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "awsecs" {
  key_name   = replace(var.project_name, "-", "")
  public_key = tls_private_key.awsecs.public_key_openssh
}

resource "local_file" "awsecs" {
  sensitive_content = tls_private_key.awsecs.private_key_pem
  filename          = "${path.module}/../../../.ssh/${aws_key_pair.awsecs.key_name}.pem"
  file_permission   = "0600"
  #directory_permission = "0700"
}

resource "local_file" "awsecs_pub_key" {
  sensitive_content = tls_private_key.awsecs.public_key_openssh
  filename          = "${path.module}/../../../.ssh/${aws_key_pair.awsecs.key_name}.pem.pub"
  file_permission   = "0600"
  directory_permission = "0700"
}

module "ecs_cluster" {
  source = "../modules/aws-ecs"

  name = "ecs-cluster-dev"
  vpc_id                = module.vpc.aws_vpc_id
  workers_vpc_subnets   = module.vpc.awsecs_private_subnet_ids
  #workers_vpc_subnets  = [module.vpc.awsecs_private_subnet_ids]
  tags = {
    Owner = "DevOps team"
    Environment = "dev"
    Terraform   = true
  }
}

module "ecr" {
  source = "../modules/aws-ecr"
  name         = "hello-app"

  # Tags
  tags = {
    Owner       = "DevOps team"
    Environment = "dev"
    Terraform   = true
  }

}

resource "aws_acm_certificate" "cert" {
  private_key       = file("../../docker/certs/ran-devops-net.key")
  certificate_body  = file("../../docker/certs/ran-devops-net.crt")
  certificate_chain = file("../../docker/certs/castore.pem")
}

module "ecs-alb" {
  source = "../modules/ecs-alb"

  name            = "ecs-cluster"
  host_name       = "ran"
  domain_name     = "devops.net"
  certificate_arn = aws_acm_certificate.cert.arn
  backend_sg_id   = module.ecs_cluster.instance_sg_id
  tags            = {
    Environment = "dev"
    Owner       = "DevOps team"
    Terraform   = true
  }
  vpc_id      = module.vpc.aws_vpc_id
  vpc_subnets = module.vpc.awsecs_public_subnet_ids
}

# Build AWS CodeCommit git repo
resource "aws_codecommit_repository" "repo" {
  repository_name = var.repository_name
  description     = "CodeCommit Terraform repo for demo"
}

#resource "aws_codecommit_trigger" "test" {
  #repository_name = aws_codecommit_repository.repo.repository_name
#
  #trigger {
    #name            = "all"
    #events          = ["all"]
    #destination_arn = aws_sns_topic.test.arn
  #}
#}
