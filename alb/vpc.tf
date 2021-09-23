resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name_prefix}-vpc"
  }

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "route0" {
  route_table_id            = aws_vpc.vpc.default_route_table_id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
  
  # vpc_peering_connection_id = "pcx-45ff3dc1"
  # depends_on                = [aws_route_table.testing]
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "subnets" {
  vpc_id            = aws_vpc.vpc.id
  count = "${length(data.aws_availability_zones.available.names)}"
  cidr_block        = var.cidr_blocks[count.index]
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-subnet${count.index}"
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.name_prefix}-ec2-sg"
#   description = "traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.name_prefix}-ec2-sg"
  }

  dynamic "ingress" {
    for_each = ["22", "80", "443", "3306"]
    content {
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      # cidr_blocks      = [aws_vpc.main.cidr_block]
      # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
      prefix_list_ids = []
      security_groups = []
      self = null
    }
  }

  egress = [
    {
      description      = "All traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = null
    }
  ]

}

resource "aws_security_group" "mysql_sg" {
#   description = "traffic"
  name        = "${var.name_prefix}-mysql-sg"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.name_prefix}-mysql-sg"
  }

  ingress = [
    {
      description      = "MySQL traffic"
      from_port        = 3306
      to_port          = 3306
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      # cidr_blocks      = [aws_vpc.main.cidr_block]
      # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
      prefix_list_ids = []
      security_groups = []
      self = null
    }
  ]
  egress = [
    {
      description      = "All traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = null
    }
  ]
}

resource "aws_security_group" "efs_sg" {
#   description = "traffic"
  name        = "${var.name_prefix}-efs-sg"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.name_prefix}-efs-sg"
  }

  ingress = [
    {
      description      = "Allow NFS traffic"
      from_port        = 2049
      to_port          = 2049
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      # cidr_blocks      = [aws_vpc.main.cidr_block]
      # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
      prefix_list_ids = []
      security_groups = []
      self = null
    }
  ]
  egress = [
    {
      description      = "All traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = null
    }
  ]
}

