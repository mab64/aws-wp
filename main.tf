provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.common_tags
  } 
}

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


resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.name_prefix}-ssh-key"
  public_key = file("~/.ssh/id_rsa.pub")
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
      description      = "NFS traffic"
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


resource "aws_instance" "ec2_inst" {
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type
  count = 2

  tags = {
    Name = "${var.name_prefix}-ec2-${count.index}"
  }

  key_name = aws_key_pair.ssh_key.id
  # security_groups = [""]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id = aws_subnet.subnets[count.index].id

#   network_interface {
#     network_interface_id = aws_network_interface.ec2_ip.id
#     device_index         = 0
#   }

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = file("~/.ssh/id_rsa")
    host        = "${self.public_dns}"
    agent = false
  }

  provisioner "file" {
    source      = "docker-compose.yml"
    destination = "docker-compose.yml"
  }

#   user_data = file("init.sh")

  provisioner "remote-exec" {
    inline = [
      "sudo apt update > /dev/null",
      "sudo apt install -y nfs-common docker docker.io docker-compose > /dev/null",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ${var.ec2_username}",
      "echo WORDPRESS_DB_HOST=${aws_db_instance.rdb.address} > .env",
      "echo WORDPRESS_DB_NAME=${var.db_name} >> .env",
      "echo WORDPRESS_DB_USER=${var.db_user} >> .env",
      "echo WORDPRESS_DB_PASSWORD=${var.db_password} >> .env",
      "sudo mkdir /efs",
      "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_mount_target.mount.ip_address}:/ /efs",
      "sudo mkdir /efs/wordpress",
      "sudo docker-compose up -d > /dev/null"
    ]
  }

  depends_on = [aws_db_instance.rdb, aws_efs_file_system.efs]
}


resource "aws_db_subnet_group" "db_subnet_gr" {
  name       = "${var.name_prefix}-db-subnet-gr"
  subnet_ids = aws_subnet.subnets.*.id

  tags = {
    Name = "${var.name_prefix}-db-subnet-gr"
  }
}

resource "aws_db_instance" "rdb" {
  allocated_storage    = 5
  engine               = "MariaDB"
  engine_version       = "10.4"
  identifier           = "wp-db"
  instance_class       = var.db_instance_class
  name                 = var.db_name
  username             = var.db_user
  password             = var.db_password
  # parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.db_subnet_gr.name
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
}


resource "aws_lb" "alb" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = aws_subnet.subnets.*.id

#   enable_deletion_protection = true

#   access_logs {
#     bucket  = aws_s3_bucket.lb_logs.bucket
#     prefix  = "test-lb"
#     enabled = true
#   }

  tags = {
    Name = "${var.name_prefix}_alb"
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name     = "${var.name_prefix}-alb-tg"
  port     = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.vpc.id
  stickiness {
    enabled = true
    type = "lb_cookie"
  }
  depends_on = [aws_lb.alb]
}

resource "aws_lb_listener" "aws_lb_lstn" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn

  }
}

resource "aws_lb_target_group_attachment" "alb_tg_atch" {
  target_group_arn = aws_lb_target_group.alb_tg.arn
#   for_each = toset(aws_instance.ec2_inst.*.id)
  count = length(aws_instance.ec2_inst)
#   target_id        = each.key
  target_id        = aws_instance.ec2_inst[count.index].id
  port             = 80
  depends_on = [aws_instance.ec2_inst]
}

#########
# sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.11.0.214:/ /mnt/efs/

resource "aws_efs_file_system" "efs" {
  creation_token = "${var.name_prefix}-efs"
  tags = {
    Name = "${var.name_prefix}-efs"
  }
}

resource "aws_efs_mount_target" "mount" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.subnets[0].id
  security_groups = [aws_security_group.efs_sg.id]
}

