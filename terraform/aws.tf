# ──────────────────────────────────────────────
# AWS — VPC, Security Group, EC2 Origin Server
# ──────────────────────────────────────────────

# Use the default VPC for simplicity (homework scope)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ── Security Group ────────────────────────────
# KEY DECISION: Zero inbound rules.
# cloudflared initiates outbound-only connections to Cloudflare's edge.
# This eliminates the origin's entire inbound attack surface.
resource "aws_security_group" "origin" {
  name        = "cse-homework-origin"
  description = "Origin server — outbound only (Cloudflare Tunnel)"
  vpc_id      = data.aws_vpc.default.id

  # No ingress rules — the whole point of using Tunnel

  egress {
    description = "Allow all outbound (cloudflared needs HTTPS/QUIC to CF edge)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "cse-homework-origin"
    Project = "cloudflare-cse-homework"
  }
}

# ── Latest Amazon Linux 2023 AMI ─────────────
data "aws_ami" "al2023" {
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

# ── EC2 Instance ──────────────────────────────
resource "aws_instance" "origin" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.origin.id]

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    tunnel_token = data.cloudflare_zero_trust_tunnel_cloudflared_token.origin.token
  })

  metadata_options {
    http_tokens   = "required" # IMDSv2 only — security best practice
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "cse-homework-origin"
    Project = "cloudflare-cse-homework"
  }
}
