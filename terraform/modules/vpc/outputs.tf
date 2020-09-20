output "aws_vpc_id" {
  value = aws_vpc.awsecs.id
}

output "awsecs_private_subnet_ids" {
  value = tolist(aws_subnet.awsecs_private.*.id)
}

output "awsecs_public_subnet_ids" {
  value = tolist(aws_subnet.awsecs_public.*.id)
}

output "awsecs_private_security_group" {
  value = aws_security_group.awsecs_private.id
}

output "awsecs_public_security_group" {
  value = aws_security_group.awsecs_public.id
}

output "aws_vpc_nat_public_ips" {
  value = aws_eip.awsecs.*.public_ip
}

output "default_tags" {
  value = var.default_tags
}
