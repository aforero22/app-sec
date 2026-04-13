# ──────────────────────────────────────────────
# Variables — Cloudflare CSE Homework
# ──────────────────────────────────────────────

# ── Cloudflare ────────────────────────────────
variable "cloudflare_api_token" {
  description = "Scoped API token for Cloudflare"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain"
  type        = string
}

variable "domain" {
  description = "Root domain managed in Cloudflare (e.g. ossfia.ai)"
  type        = string
}

# ── AWS ───────────────────────────────────────
variable "aws_region" {
  description = "AWS region for the origin server"
  type        = string
  default     = "eu-south-2"
}

# ── Zero Trust ────────────────────────────────
variable "allowed_emails" {
  description = "Email addresses allowed through Zero Trust Access"
  type        = list(string)
  default     = []
}
