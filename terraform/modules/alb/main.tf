# ALB module — internet-facing load balancer with path-based routing.
# /java/*   → WildFly target group (port 8080)
# /dotnet/* → IIS target group (port 80)
# HTTP (80) → redirects to HTTPS (443)

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB security group -- allows HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound to reach targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# ── ALB ───────────────────────────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  # Enable access logs for audit/compliance
  # access_logs { bucket = "..." } # Uncomment and configure for production

  enable_deletion_protection = false # Set true for production

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# ── Target Groups ─────────────────────────────────────────────────────────────

# WildFly (Java) target group
resource "aws_lb_target_group" "java" {
  name     = "${local.name_prefix}-tg-java"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/java/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  tags = {
    Name = "${local.name_prefix}-tg-java"
    app  = "wildfly"
  }
}

# IIS (.NET) target group
resource "aws_lb_target_group" "dotnet" {
  name     = "${local.name_prefix}-tg-dotnet"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/dotnet/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  tags = {
    Name = "${local.name_prefix}-tg-dotnet"
    app  = "iis"
  }
}

# ── Target Group Attachments ──────────────────────────────────────────────────

resource "aws_lb_target_group_attachment" "java" {
  target_group_arn = aws_lb_target_group.java.arn
  target_id        = var.linux_instance_id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "dotnet" {
  target_group_arn = aws_lb_target_group.dotnet.arn
  target_id        = var.windows_instance_id
  port             = 80
}

# ── Listeners ─────────────────────────────────────────────────────────────────

# HTTP → HTTPS redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener with path-based routing (only when a certificate is available)
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # TLS 1.2+ with TLS 1.3 preferred
  certificate_arn   = var.certificate_arn

  # Default action returns 404 for unmatched paths
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# /java/* → WildFly
resource "aws_lb_listener_rule" "java" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.java.arn
  }

  condition {
    path_pattern {
      values = ["/java/*"]
    }
  }
}

# /dotnet/* → IIS
resource "aws_lb_listener_rule" "dotnet" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dotnet.arn
  }

  condition {
    path_pattern {
      values = ["/dotnet/*"]
    }
  }
}
