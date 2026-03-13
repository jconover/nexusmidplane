# EC2 Linux module — Amazon Linux 2023 host for WildFly application server.
# Placed in private subnet; accessible via ALB (8080/8443) and SSM Session Manager.
# Management port 9990 is restricted to VPC CIDR only (never exposed to internet).

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── AMI ───────────────────────────────────────────────────────────────────────

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── IAM: SSM + CloudWatch access ──────────────────────────────────────────────

resource "aws_iam_role" "wildfly" {
  name = "${local.name_prefix}-wildfly-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-wildfly-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.wildfly.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.wildfly.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "wildfly" {
  name = "${local.name_prefix}-wildfly-profile"
  role = aws_iam_role.wildfly.name
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "wildfly" {
  name        = "${local.name_prefix}-wildfly-sg"
  description = "WildFly application server security group"
  vpc_id      = var.vpc_id

  # HTTP from ALB / VPC
  ingress {
    description = "WildFly HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # HTTPS from ALB / VPC
  ingress {
    description = "WildFly HTTPS"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Management console — restricted to VPC CIDR only (never 0.0.0.0/0)
  ingress {
    description = "WildFly management console (restricted)"
    from_port   = 9990
    to_port     = 9990
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH — restricted to VPC CIDR; prefer SSM Session Manager instead
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-wildfly-sg"
  }
}

# ── User Data ─────────────────────────────────────────────────────────────────

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > >(tee /var/log/user-data.log) 2>&1

    echo "=== System update ==="
    dnf update -y

    echo "=== Install Java 17 (Corretto) ==="
    dnf install -y java-17-amazon-corretto java-17-amazon-corretto-devel

    echo "=== Install CloudWatch Agent ==="
    dnf install -y amazon-cloudwatch-agent

    echo "=== Create wildfly user ==="
    useradd -r -s /sbin/nologin wildfly

    echo "=== Download WildFly 31 ==="
    WILDFLY_VERSION="31.0.0.Final"
    WILDFLY_URL="https://github.com/wildfly/wildfly/releases/download/$${WILDFLY_VERSION}/wildfly-$${WILDFLY_VERSION}.tar.gz"
    curl -fsSL "$${WILDFLY_URL}" -o /tmp/wildfly.tar.gz
    tar -xzf /tmp/wildfly.tar.gz -C /opt
    ln -sf /opt/wildfly-$${WILDFLY_VERSION} /opt/wildfly
    chown -R wildfly:wildfly /opt/wildfly-$${WILDFLY_VERSION} /opt/wildfly

    echo "=== Configure WildFly systemd service ==="
    cat > /etc/systemd/system/wildfly.service <<'SERVICE'
    [Unit]
    Description=WildFly Application Server
    After=network.target

    [Service]
    User=wildfly
    Group=wildfly
    ExecStart=/opt/wildfly/bin/standalone.sh -b 0.0.0.0 -bmanagement 0.0.0.0
    ExecStop=/opt/wildfly/bin/jboss-cli.sh --connect command=:shutdown
    Restart=on-failure
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable wildfly
    systemctl start wildfly

    echo "=== Start CloudWatch Agent ==="
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s -c ssm:/nexusmidplane/cloudwatch-config || true

    echo "=== User data complete ==="
  EOF
}

# ── EC2 Instance ──────────────────────────────────────────────────────────────

resource "aws_instance" "wildfly" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.wildfly.id]
  iam_instance_profile   = aws_iam_instance_profile.wildfly.name
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  user_data_base64            = base64encode(local.user_data)
  user_data_replace_on_change = false # Avoid instance replacement on minor changes

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.name_prefix}-wildfly-root"
    }
  }

  # Enable detailed monitoring for CloudWatch metrics
  monitoring = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${local.name_prefix}-wildfly"
    role = "wildfly"
    os   = "amazon-linux-2023"
  }

  lifecycle {
    ignore_changes = [ami] # Don't replace on AMI updates; handle via patching pipeline
  }
}
