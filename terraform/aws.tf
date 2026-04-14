# ──────────────────────────────────────────────
# AWS — VPC, Security Group, EC2 Origin Server
# ──────────────────────────────────────────────

# Default VPC for simplicity — in production, use a custom VPC
# with private subnets (no public IP needed with Tunnel).
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
# cloudflared initiates outbound-only QUIC connections to Cloudflare's edge.
# This eliminates the origin's entire inbound attack surface —
# the public IP exists but responds to nothing (no ping, no HTTP, no SSH).
resource "aws_security_group" "origin" {
  name        = "cse-homework-origin"
  description = "Origin server - outbound only via Cloudflare Tunnel"
  vpc_id      = data.aws_vpc.default.id

  # No ingress rules — the whole point of using Tunnel.
  # Verified: ping, HTTP/80, HTTPS/443, 8080 all timeout from the internet.

  egress {
    description = "Allow all outbound for cloudflared HTTPS/QUIC to CF edge"
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
# Automatically resolves to the latest AL2023 release.
# Lightweight, Node.js available via dnf, cloudflared installs via RPM.
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
  instance_type          = "t3.micro" # Free-tier eligible
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.origin.id]

  # Bootstrap: installs Node.js, cloudflared, clones repo, starts services.
  # The tunnel_token is injected by Terraform from the CF tunnel resource.
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    tunnel_token = data.cloudflare_zero_trust_tunnel_cloudflared_token.origin.token
  })

  # IMDSv2 required — prevents SSRF-based credential theft.
  # Attackers cannot reach the metadata endpoint without a session token
  # that requires a PUT request (not possible via simple GET SSRF).
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  # Encrypted root volume — data at rest protection.
  root_block_device {
    volume_size = 30     # AL2023 AMI requires >= 30GB
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "cse-homework-origin"
    Project = "cloudflare-cse-homework"
  }
}
