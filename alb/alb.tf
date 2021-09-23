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
#   target_id        = each.key
  count = length(aws_instance.ec2_inst)
  target_id        = aws_instance.ec2_inst[count.index].id
  port             = 80
  depends_on = [aws_instance.ec2_inst]
}

