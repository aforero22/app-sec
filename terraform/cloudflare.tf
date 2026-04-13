# ──────────────────────────────────────────────
# Cloudflare — Tunnel, DNS, SSL/TLS, Headers
# ──────────────────────────────────────────────

# ── Tunnel ────────────────────────────────────
resource "cloudflare_zero_trust_tunnel_cloudflared" "origin" {
  account_id = var.cloudflare_account_id
  name       = "cse-homework"
  config_src = "cloudflare"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "origin" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.origin.id
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "origin" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.origin.id

  config = {
    ingress = [
      {
        hostname = "tunnel.${var.domain}"
        service  = "http://localhost:8080"
      },
      {
        # Mandatory catch-all
        service = "http_status:404"
      }
    ]
  }
}

# ── DNS ───────────────────────────────────────
resource "cloudflare_dns_record" "tunnel" {
  zone_id = var.cloudflare_zone_id
  name    = "tunnel"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.origin.id}.cfargotunnel.com"
  ttl     = 1       # automatic when proxied
  proxied = true
}

# ── SSL/TLS Settings ─────────────────────────
# Task 2: Full (Strict) — validates origin cert against CF CA
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "strict"
}

# Task 3: Minimum TLS 1.2 for visitor <-> CF edge
resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}

# Bonus: Enable TLS 1.3
resource "cloudflare_zone_setting" "tls_1_3" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "tls_1_3"
  value      = "on"
}

# Bonus: Automatic HTTPS Rewrites
resource "cloudflare_zone_setting" "https_rewrites" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "automatic_https_rewrites"
  value      = "on"
}

# ── Security Response Headers (Transform Rule) ─
resource "cloudflare_ruleset" "security_headers" {
  zone_id     = var.cloudflare_zone_id
  name        = "Security Response Headers"
  description = "Add security headers to all proxied responses"
  kind        = "zone"
  phase       = "http_response_headers_transform"

  rules = [
    {
      ref         = "security_headers_rule"
      description = "Set security headers"
      expression  = "true"
      action      = "rewrite"
      enabled     = true

      action_parameters = {
        headers = [
          {
            name      = "Content-Security-Policy"
            operation = "set"
            value     = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
          },
          {
            name      = "Strict-Transport-Security"
            operation = "set"
            value     = "max-age=31536000; includeSubDomains; preload"
          },
          {
            name      = "X-Frame-Options"
            operation = "set"
            value     = "DENY"
          },
          {
            name      = "X-Content-Type-Options"
            operation = "set"
            value     = "nosniff"
          },
          {
            name      = "Referrer-Policy"
            operation = "set"
            value     = "strict-origin-when-cross-origin"
          },
          {
            name      = "Permissions-Policy"
            operation = "set"
            value     = "camera=(), microphone=(), geolocation=()"
          }
        ]
      }
    }
  ]
}
