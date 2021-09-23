
output "ec2_ip" {
  value = aws_instance.ec2_inst.*.public_ip
}
# output "ec2_ip1" {
#   value = aws_instance.ec2_inst.1.public_ip
# }


output "rdb_addr" {
  value = aws_db_instance.rdb.address
}

output "subnets" {
#   value = aws_subnet.subnets[count.index].cidr_block
  value = aws_subnet.subnets.*.cidr_block
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "efs_dns_name" {
  value = aws_efs_mount_target.mount.dns_name
}
output "efs_ip_addr" {
  value = aws_efs_mount_target.mount.ip_address
}
