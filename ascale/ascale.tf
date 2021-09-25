resource "aws_launch_configuration" "launch_conf" {
  # name_prefix = "${var.name_prefix}-"
  name = "${var.name_prefix}-launch_conf"

  image_id = var.ec2_ami
  instance_type = var.ec2_instance_type
  key_name = aws_key_pair.ssh_key.id

  security_groups = [ aws_security_group.ec2_sg.id ]
  associate_public_ip_address = true

  user_data = <<-USER_DATA
    #!/bin/bash
    apt update
    apt -y install net-tools stress-ng nfs-common docker docker.io # docker-compose
    systemctl start docker
    docker run -dit -p 8080:80 --name nginx nginx
    mkdir /efs
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "${aws_efs_mount_target.mount.ip_address}":/ /efs
    mkdir -p /efs/wordpress
    docker run -dit -p 80:80 \
      --mount type=bind,source=/efs/wordpress,destination=/var/www/html \
      -e WORDPRESS_DB_HOST="${aws_db_instance.rdb.address}" \
      -e WORDPRESS_DB_NAME="${var.db_name}" \
      -e WORDPRESS_DB_USER="${var.db_user}" \
      -e WORDPRESS_DB_PASSWORD="${var.db_password}" \
      --restart always --name wordpress wordpress
    # curl http://169.254.169.254/latest/meta-data/local-ipv4 > /efs/wordpress/index.html
  USER_DATA

  # lifecycle {
  #   create_before_destroy = true
  # }
}


resource "aws_autoscaling_group" "asg" {
  name = "${var.name_prefix}-asg"
  launch_configuration = aws_launch_configuration.launch_conf.name

  min_size             = 1
  desired_capacity     = 2
  max_size             = 3
  health_check_type    = "ELB"
  health_check_grace_period = 300
  # load_balancers = [ aws_elb.elb.id ]
  target_group_arns = [ aws_lb_target_group.alb_tg.arn ]

  vpc_zone_identifier  = aws_subnet.subnets.*.id

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-asg-ec2"
    propagate_at_launch = true
  }

  # enabled_metrics = [
  #   "GroupMinSize",
  #   "GroupMaxSize",
  #   "GroupDesiredCapacity",
  #   "GroupInServiceInstances",
  #   "GroupTotalInstances"
  # ]

  # redeploy without an outage.
  # lifecycle {
  #   create_before_destroy = true
  # }
  # tags = {
  #   Name = "${var.name_prefix}-asg-ec2"
  # }
  
  depends_on = [
    aws_db_instance.rdb
  ]
}

resource "aws_autoscaling_policy" "scale_up" {
  name = "${var.name_prefix}-scale-up-policy"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 120
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.scale_up.arn ]
}

resource "aws_autoscaling_policy" "scale_down" {
  name = "${var.name_prefix}-scale-down-policy"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 120
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.scale_down.arn ]
}


resource "aws_elb" "elb" {
  name = "${var.name_prefix}-elb"
  security_groups = [ aws_security_group.ec2_sg.id ]
  subnets = aws_subnet.subnets.*.id

  cross_zone_load_balancing   = true

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
  listener {
    lb_port = 443
    lb_protocol = "https"
    ssl_certificate_id = aws_acm_certificate.ssl_cert.arn
    instance_port = "80"
    instance_protocol = "http"
  }
}

resource "aws_acm_certificate" "ssl_cert" {
  private_key=file("../.cert/privkey.pem")
  certificate_body = file("../.cert/cert.pem")
  certificate_chain=file("../.cert/chain.pem")
}
