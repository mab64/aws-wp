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

