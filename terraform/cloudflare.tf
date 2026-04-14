# ──────────────────────────────────────────────
# Cloudflare — Tunnel, DNS, SSL/TLS, Headers
# ──────────────────────────────────────────────

# ── Tunnel ────────────────────────────────────
# Named tunnel (persistent, survives restarts, managed via Terraform).
# config_src = "cloudflare" means ingress rules are managed from the
# CF dashboard/API — no local config.yml needed on the origin server.
# (In provider v4, you had to generate a random secret manually.)
resource "cloudflare_zero_trust_tunnel_cloudflared" "origin" {
  account_id = var.cloudflare_account_id
  name       = "cse-homework"
  config_src = "cloudflare"
}

# Retrieve the tunnel token — passed to EC2 user_data for cloudflared auth.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "origin" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.origin.id
}

# Ingress rules: route tunnel.ossfia.ai to the local origin server.
# The last entry MUST be a catch-all with no hostname — cloudflared
# refuses to start without it.
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
        # Mandatory catch-all — returns 404 for unmatched hostnames
        service = "http_status:404"
      }
    ]
  }
}

# ── DNS ───────────────────────────────────────
# CNAME pointing tunnel.ossfia.ai to the tunnel's internal address.
# Proxied = true ensures traffic flows through Cloudflare's edge
# (required for Worker, Transform Rules, and Zero Trust to work).
resource "cloudflare_dns_record" "tunnel" {
  zone_id = var.cloudflare_zone_id
  name    = "tunnel"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.origin.id}.cfargotunnel.com"
  ttl     = 1       # "Automatic" when proxied
  proxied = true
}

# ── SSL/TLS Settings ─────────────────────────

# Task 2: Full (Strict) — Cloudflare validates the origin certificate
# against its own CA. With Tunnel, this is automatic (cloudflared
# presents a valid CF-issued cert). Without Tunnel, you'd use Origin CA.
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "strict"
}

# Task 3: Minimum TLS 1.2 — blocks TLS 1.0/1.1 which are vulnerable
# to POODLE, BEAST, and other downgrade attacks. Aligns with PCI-DSS
# and modern browser defaults.
resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}

# Bonus: TLS 1.3 — faster handshakes (1-RTT vs 2-RTT),
# improved Perfect Forward Secrecy, mandatory encryption of SNI.
resource "cloudflare_zone_setting" "tls_1_3" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "tls_1_3"
  value      = "on"
}

# Bonus: Automatically rewrite http:// to https:// in page content,
# preventing mixed-content warnings.
resource "cloudflare_zone_setting" "https_rewrites" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "automatic_https_rewrites"
  value      = "on"
}

# ── Security Response Headers (Transform Rule) ─
# Applied at the EDGE, not the origin — ensures headers are present
# on all responses including cached pages and error pages.
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
      expression  = "true"   # Apply to all requests
      action      = "rewrite"
      enabled     = true

      action_parameters = {
        # v5 provider uses map-of-objects (header name = key)
        headers = {
          # Restrict resource loading to same-origin only.
          # default-src 'none' = deny everything by default (least privilege).
          # frame-ancestors 'none' = prevent clickjacking (supersedes X-Frame-Options).
          "Content-Security-Policy" = {
            operation = "set"
            value     = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
          }
          # 1-year max-age (minimum for HSTS preload list submission).
          # includeSubDomains protects all subdomains.
          "Strict-Transport-Security" = {
            operation = "set"
            value     = "max-age=31536000; includeSubDomains; preload"
          }
          # Prevent page from being embedded in frames (clickjacking protection).
          # Redundant with CSP frame-ancestors but kept for legacy browser support.
          "X-Frame-Options" = {
            operation = "set"
            value     = "DENY"
          }
          # Prevent browsers from MIME-sniffing the content-type.
          "X-Content-Type-Options" = {
            operation = "set"
            value     = "nosniff"
          }
          # Send origin (not full URL) on cross-origin requests.
          # Balances analytics utility with privacy.
          "Referrer-Policy" = {
            operation = "set"
            value     = "strict-origin-when-cross-origin"
          }
          # Restrict access to browser APIs (camera, mic, geolocation).
          "Permissions-Policy" = {
            operation = "set"
            value     = "camera=(), microphone=(), geolocation=()"
          }
        }
      }
    }
  ]
}
