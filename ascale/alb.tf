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
  deregistration_delay = 70
  stickiness {
    enabled = true
    type = "lb_cookie"
  }
  depends_on = [aws_lb.alb]
}

resource "aws_lb_listener" "alb_lstn_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}
# For HTTPS access
# Genetate SSL certificate for your dommain name
# Create CNAME record on your domain DNS server
resource "aws_lb_listener" "alb_lstn_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.ssl_cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

# resource "aws_lb_listener_certificate" "alb_lstn_https_cert" {
#   listener_arn    = aws_lb_listener.alb_lstn_https.arn
#   certificate_arn = aws_acm_certificate.ssl_cert.arn
# }