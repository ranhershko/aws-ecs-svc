data "terraform_remote_state" "vpc-n-ecs" {
  backend = "s3"
  config = {
    bucket = "awsecs-terraform-remote-state"
    key    = "vpc-n-ecs-terraform.tfstate"
    region = "us-east-1"
  }
}
