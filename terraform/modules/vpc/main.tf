resource "aws_vpc" "awsecs" {
  cidr_block = var.aws_vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.default_tags, map(
      "Name", "awsecs-${var.project_name}-vpc"
    ))
}

resource "aws_eip" "awsecs" {
  count = (length(var.aws_public_subnets_cidr) <= length(var.aws_avail_zones) ? length(var.aws_public_subnets_cidr) : length(var.aws_avail_zones))
  vpc   = true

  tags = merge(var.default_tags, map(
    "Name", "awsecs-${var.project_name}-nat${count.index + 1}-eip"
  ))
}

resource "aws_internet_gateway" "awsecs" {
  vpc_id = aws_vpc.awsecs.id

  tags = merge(var.default_tags, map(
    "Name", "awsecs-${var.project_name}-igw"
  ))
}

resource "aws_subnet" "awsecs_public" {
  vpc_id            = aws_vpc.awsecs.id
  count             = length(var.aws_public_subnets_cidr)
  availability_zone = element(var.aws_avail_zones, count.index)
  cidr_block        = element(var.aws_public_subnets_cidr, count.index)

  tags = merge(var.default_tags, map(
      "Name", "awsecs-${var.project_name}-pub-sub${count.index + 1}-${element(var.aws_avail_zones, count.index)}"
    )
  )
}

resource "aws_nat_gateway" "awsecs" {
  count         = length(aws_eip.awsecs)
  allocation_id = element(aws_eip.awsecs.*.id, count.index)
  subnet_id     = element(aws_subnet.awsecs_public.*.id, count.index)

  tags = merge(var.default_tags, map(
    "Name", "awsecs-${var.project_name}-natgw${count.index + 1}"
  ))
}

resource "aws_subnet" "awsecs_private" {
  vpc_id            = aws_vpc.awsecs.id
  count             = length(var.aws_private_subnets_cidr)
  availability_zone = element(var.aws_avail_zones, count.index)
  cidr_block        = element(var.aws_private_subnets_cidr, count.index)

  tags = merge(var.default_tags, map(
      "Name", "awsecs-${var.project_name}-priv-sub${count.index + 1}-${element(var.aws_avail_zones, count.index)}"
    )
  )
}

resource "aws_route_table" "awsecs_public" {
  vpc_id = aws_vpc.awsecs.id
  route {
    cidr_block = var.internet_default_route_cidr
    gateway_id = aws_internet_gateway.awsecs.id
  }

  tags = merge(var.default_tags, map(
      "Name", "awsecs-${var.project_name}-public-rt"
    ))
}

resource "aws_route_table" "awsecs_private" {
  count  = length(var.aws_public_subnets_cidr)
  vpc_id = aws_vpc.awsecs.id
  route {
    cidr_block     = var.internet_default_route_cidr
    nat_gateway_id = element(aws_nat_gateway.awsecs.*.id, count.index % length(aws_nat_gateway.awsecs))
  }

  tags = merge(var.default_tags, map(
      "Name", "awsecs-${var.project_name}-private-rt${count.index + 1}"
    ))
}

resource "aws_route_table_association" "awsecs_public" {
  count          = length(aws_subnet.awsecs_public)
  subnet_id      = element(aws_subnet.awsecs_public.*.id, count.index)
  route_table_id = aws_route_table.awsecs_public.id
}

resource "aws_route_table_association" "awsecs_private" {
  count          = length(aws_subnet.awsecs_private)
  subnet_id      = element(aws_subnet.awsecs_private.*.id, count.index)
  route_table_id = element(aws_route_table.awsecs_private.*.id, count.index % length(aws_nat_gateway.awsecs))
}

resource "aws_security_group" "awsecs_private" {
  name   = "awsecs-${var.project_name}-private-sg"
  vpc_id = aws_vpc.awsecs.id

  tags = merge(var.default_tags, { 
      "Name" = "awsecs-${var.project_name}-private-sg"#,
      }
    )
}

resource "aws_security_group_rule" "allow-worker-ingress-using-nat-ips" {
  count             = length(aws_eip.awsecs)
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["${element(aws_eip.awsecs.*.public_ip, count.index)}/32"]
  security_group_id = aws_security_group.awsecs_private.id
}

resource "aws_security_group_rule" "allow-all-ingress-inside-vpc" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  self              = true
  security_group_id = aws_security_group.awsecs_private.id
}

resource "aws_security_group_rule" "allow-worker-all-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = [var.internet_default_route_cidr]
  security_group_id = aws_security_group.awsecs_private.id
}

resource "aws_security_group_rule" "allow-management-connections" {
  type              = "ingress"
  from_port         = 0
  #from_port         = var.ssh_port
  #to_port           = var.ssh_port
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["${chomp(data.http.myip.body)}/32"]
  security_group_id = aws_security_group.awsecs_private.id
}

resource "aws_security_group" "awsecs_public" {
  name   = "awsecs-${var.project_name}-public-sg"
  vpc_id = aws_vpc.awsecs.id

  tags = merge(var.default_tags, {
      "Name" = "awsecs-${var.project_name}-public-sg"#,
      }
  )
}

resource "aws_security_group_rule" "allow-ecs-ingress-https-from-manage-ip" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.awsecs_public.id
  cidr_blocks              = ["${chomp(data.http.myip.body)}/32"]
}

resource "aws_security_group_rule" "allow-ecs-all-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = [var.internet_default_route_cidr]
  security_group_id = aws_security_group.awsecs_public.id
}
