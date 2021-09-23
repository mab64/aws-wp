resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id = var.ec2_ami
  instance_type = var.ec2_instance_type
  key_name = aws_key_pair.ssh_key.id

  security_groups = [ aws_security_group.ec2_sg.id ]
  associate_public_ip_address = true

  user_data = <<-USER_DATA
    #!/bin/bash
    apt update
    apt -y install net-tools stress nfs-common docker docker.io docker-compose
    # systemctl start nginx
    systemctl start docker
    docker run -dit -p 8080:80 --name nginx nginx
    mkdir /efs
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "${aws_efs_mount_target.mount.ip_address}":/ /efs
    [ -d /efs/wordpress ] && echo wordpress dir exists || sudo mkdir /efs/wordpress
    docker run -dit -p 80:80 \
      --mount type=bind,source=/efs/wordpress,destination=/var/www/html \
      -e WORDPRESS_DB_HOST="${aws_db_instance.rdb.address}" \
      -e WORDPRESS_DB_NAME="${var.db_name}" \
      -e WORDPRESS_DB_USER="${var.db_user}" \
      -e WORDPRESS_DB_PASSWORD="${var.db_password}" \
      --name wordpress wordpress
    curl http://169.254.169.254/latest/meta-data/local-ipv4 > /efs/wordpress/index.html
  USER_DATA

  # lifecycle {
  #   create_before_destroy = true
  # }
}


resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 3
  
  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]

  launch_configuration = aws_launch_configuration.web.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = aws_subnet.subnets.*.id

  # Required to redeploy without an outage.
  # lifecycle {
  #   create_before_destroy = true
  # }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }
  
  depends_on = [
    aws_db_instance.rdb
  ]
}

resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 60
  autoscaling_group_name = aws_autoscaling_group.web.name
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
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.web_policy_up.arn ]
}

resource "aws_autoscaling_policy" "web_policy_down" {
  name = "web_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 60
  autoscaling_group_name = aws_autoscaling_group.web.name
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
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.web_policy_down.arn ]
}


resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.ec2_sg.id
  ]
  subnets = aws_subnet.subnets.*.id

  cross_zone_load_balancing   = true

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:8080/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}