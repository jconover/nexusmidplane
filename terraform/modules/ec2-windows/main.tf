# EC2 Windows module — Windows Server 2022 host for IIS application server.
# Placed in private subnet; accessible via ALB (80/443) and SSM Session Manager.
# WinRM (5985/5986) and RDP (3389) restricted to VPC CIDR for Ansible management.

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── AMI ───────────────────────────────────────────────────────────────────────

data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── IAM: SSM + CloudWatch access ──────────────────────────────────────────────

resource "aws_iam_role" "iis" {
  name = "${local.name_prefix}-iis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-iis-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.iis.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.iis.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "iis" {
  name = "${local.name_prefix}-iis-profile"
  role = aws_iam_role.iis.name
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "iis" {
  name        = "${local.name_prefix}-iis-sg"
  description = "IIS application server security group"
  vpc_id      = var.vpc_id

  # HTTP from ALB / VPC
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # HTTPS from ALB / VPC
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # WinRM HTTP — restricted to VPC; used by Ansible
  ingress {
    description = "WinRM HTTP from VPC"
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # WinRM HTTPS — restricted to VPC; preferred for Ansible
  ingress {
    description = "WinRM HTTPS from VPC"
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # RDP — restricted to VPC; prefer SSM Session Manager instead
  ingress {
    description = "RDP from VPC"
    from_port   = 3389
    to_port     = 3389
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
    Name = "${local.name_prefix}-iis-sg"
  }
}

# ── User Data (PowerShell) ────────────────────────────────────────────────────

locals {
  user_data = <<-POWERSHELL
    <powershell>
    # Enable WinRM for Ansible management
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $false
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item WSMan:\localhost\Service\Auth\CredSSP -Value $true

    # Configure HTTPS listener (self-signed cert for initial setup)
    $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation cert:\LocalMachine\My
    New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbprint $cert.Thumbprint -Force

    Enable-PSRemoting -Force
    Set-Service WinRM -StartupType Automatic
    Start-Service WinRM

    # Open WinRM in Windows Firewall
    New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow

    # Install IIS with management tools and ASP.NET
    Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter -IncludeManagementTools

    # Install .NET 8 Hosting Bundle for modern ASP.NET Core apps
    $dotnetUrl = "https://dot.net/v1/dotnet-install.ps1"
    Invoke-WebRequest -Uri $dotnetUrl -OutFile C:\dotnet-install.ps1
    & C:\dotnet-install.ps1 -Channel 8.0 -Runtime dotnet

    # Create default IIS site directories
    New-Item -ItemType Directory -Path "C:\inetpub\dotnet-app" -Force

    # Install CloudWatch Agent
    $cwAgentUrl = "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
    Invoke-WebRequest -Uri $cwAgentUrl -OutFile C:\amazon-cloudwatch-agent.msi
    Start-Process msiexec.exe -ArgumentList "/i C:\amazon-cloudwatch-agent.msi /quiet /norestart" -Wait

    Write-Output "User data configuration complete"
    </powershell>
    <persist>true</persist>
  POWERSHELL
}

# ── EC2 Instance ──────────────────────────────────────────────────────────────

resource "aws_instance" "iis" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.iis.id]
  iam_instance_profile   = aws_iam_instance_profile.iis.name
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  user_data_base64            = base64encode(local.user_data)
  user_data_replace_on_change = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50 # Windows needs more space than Linux
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.name_prefix}-iis-root"
    }
  }

  monitoring = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${local.name_prefix}-iis"
    role = "iis"
    os   = "windows-server-2022"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
