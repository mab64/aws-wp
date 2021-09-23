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
      "[ -d /efs/wordpress ] && echo wordpress dir exists || sudo mkdir /efs/wordpress",
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

