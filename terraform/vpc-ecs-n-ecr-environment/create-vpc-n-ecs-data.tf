data "aws_availability_zones" "available" {}

data "http" "myip" {
  url = "https://api.ipify.org/"
}
