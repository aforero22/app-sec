# ──────────────────────────────────────────────
# Cloudflare Zero Trust — Access Application + Policy
# Task 7: Lock down tunnel.domain.com/secure
# ──────────────────────────────────────────────

resource "cloudflare_zero_trust_access_policy" "allowed_users" {
  account_id = var.cloudflare_account_id
  name       = "Allow homework reviewers"
  decision   = "allow"

  include = [
    for email in var.allowed_emails : {
      email = {
        email = email
      }
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "secure" {
  account_id             = var.cloudflare_account_id
  type                   = "self_hosted"
  name                   = "CSE Homework — Secure Area"
  domain                 = "tunnel.${var.domain}/secure"
  session_duration       = "24h"

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.allowed_users.id
      precedence = 1
    }
  ]
}
