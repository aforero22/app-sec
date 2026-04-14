# ──────────────────────────────────────────────
# Cloudflare Zero Trust — Access Application + Policy
# Task 7: Lock down tunnel.domain.com/secure
# ──────────────────────────────────────────────

# Allow policy: specific emails + anyone with a @cloudflare.com address.
# The "include" array uses OR logic — any matching rule grants access.
# This lets homework reviewers (Cloudflare staff) log in with their work
# email without needing to be added individually.
resource "cloudflare_zero_trust_access_policy" "allowed_users" {
  account_id = var.cloudflare_account_id
  name       = "Allow homework reviewers"
  decision   = "allow"

  include = concat(
    # Specific emails from var.allowed_emails (the author + any additions)
    [
      for email in var.allowed_emails : {
        email = {
          email = email
        }
      }
    ],
    # Domain rule: any @cloudflare.com email (reviewers, panel members)
    [
      {
        email_domain = {
          domain = "cloudflare.com"
        }
      }
    ]
  )
}

resource "cloudflare_zero_trust_access_application" "secure" {
  account_id       = var.cloudflare_account_id
  type             = "self_hosted"
  name             = "CSE Homework — Secure Area"
  domain           = "tunnel.${var.domain}/secure"
  session_duration = "24h"

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.allowed_users.id
      precedence = 1
    }
  ]
}
