
output "EC2_IPs" {
  value = aws_instance.ec2_inst.*.public_ip
}
# output "ec2_ip1" {
#   value = aws_instance.ec2_inst.1.public_ip
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
