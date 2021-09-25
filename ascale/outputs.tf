
# output "ec2_ip" {
#   value = aws_instance.ec2_inst.*.public_ip
# }

output "RDB_DNS_name" {
  value = aws_db_instance.rdb.address
}

output "Subnets" {
#   value = aws_subnet.subnets[count.index].cidr_block
  value = aws_subnet.subnets.*.cidr_block
}

# output "alb_dns_name" {
#   value = aws_lb.alb.dns_name
# }

output "EFS_DNS_Name" {
  value = aws_efs_mount_target.mount.mount_target_dns_name
}
output "EFS_IP_Address" {
  value = aws_efs_mount_target.mount.ip_address
}

# output "elb_dns_name" {
#   value = aws_elb.elb.dns_name
# }

output "ALB_DNS_Name" {
  value = aws_lb.alb.dns_name
}
