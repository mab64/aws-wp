provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.common_tags
  } 
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.name_prefix}-ssh-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_vpc" "vpc" {
  # cidr_block           = var.vpc_cidr
  cidr_block           = "${var.vpc_net_prefix}0.0/16"
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
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "subnets" {
  vpc_id            = aws_vpc.vpc.id
  count = "${length(data.aws_availability_zones.available.names)}"
  # cidr_block        = var.cidr_blocks[count.index]
  cidr_block        = "${var.vpc_net_prefix}${count.index}.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-subnet${count.index}"
  }
}

