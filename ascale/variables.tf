variable "aws_region" {
  default = "eu-central-1"
}

variable "common_tags" {
  default = {
    Environment = ""
    Owner       = ""
    Project     = ""
  }
}
variable "name_prefix" {}

variable "vpc_cidr" {
  default = "10.11.0.0/16"
}
variable "cidr_blocks" {
  default = ["10.11.0.0/24", 
             "10.11.1.0/24",
             "10.11.2.0/24",
             "10.11.3.0/24",
             "10.11.4.0/24",
             "10.11.5.0/24",
            ]
}

variable "ec2_ami" {
  default = "ami-0245697ee3e07e755" # debian 10
}
variable "ec2_instance_type" {
  default = "t2.micro"
}
variable "ec2_username" {
  default = "admin"
}
variable "db_instance_class" {
  default = "db.t2.micro"
}

variable "db_name" {}
variable "db_user" {}
variable "db_password" {}

