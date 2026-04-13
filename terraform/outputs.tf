# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────

output "origin_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.origin.id
}

output "tunnel_url" {
  description = "Public URL via Cloudflare Tunnel"
  value       = "https://tunnel.${var.domain}"
}

output "secure_url" {
  description = "Zero Trust protected URL"
  value       = "https://tunnel.${var.domain}/secure"
}

output "tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.origin.id
}

output "security_group_ingress_rules" {
  description = "Inbound rules count (should be 0 — Tunnel only)"
  value       = "Zero inbound rules — all traffic via Cloudflare Tunnel"
}
