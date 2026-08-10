data "aws_network_interfaces" "network-interface" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "requester-id"
    values = ["amazon-elasticsearch"]
  }
  filter {
    name   = "status"
    values = ["in-use"]
  }
  filter {
    name   = "attachment.status"
    values = ["attached"]
  }
}
output "kibana_network-interface" {
  value = data.aws_network_interfaces.network-interface.ids
}
data "aws_network_interface" "network-interface" {
  count = length(data.aws_network_interfaces.network-interface.ids)
  id    = data.aws_network_interfaces.network-interface.ids[count.index]
}
resource "aws_lb_target_group" "kibana-target-group" {
  name        = "${var.project}-kibana-tg-${var.environment}"
  port        = 443
  protocol    = "HTTPS"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    interval            = 10
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTPS"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-403"
  }
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_lb" "kibana-alb" {
  # name               = "${var.project}-kibana-alb-${var.environment}"
  name               = "${var.project}-kibana-alb-prod"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [var.kibana_alb_sg_id]
  ip_address_type    = "ipv4"

  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_lb_listener" "kibana-alb_listener" {
  load_balancer_arn = aws_lb.kibana-alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.kibana_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kibana-target-group.arn
  }
  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_lb_target_group_attachment" "kibana-target-group-attach" {
  # for_each = toset(var.target_ips)
  count            = length(data.aws_network_interface.network-interface)
  target_group_arn = aws_lb_target_group.kibana-target-group.arn
  target_id        = data.aws_network_interface.network-interface[count.index].private_ip
}