terraform {
  required_version = ">= 0.12.0"
  backend "s3" {
    encrypt = true
    bucket  = "awsecs-terraform-remote-state"
    key     = "vpc-n-ecs-terraform.tfstate"
    region  = "us-east-1"

    dynamodb_table = "vpc-n-ecs-terraform-remote-lock"
 } 
}
