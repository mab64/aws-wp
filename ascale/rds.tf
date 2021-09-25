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

