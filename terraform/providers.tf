# ──────────────────────────────────────────────
# Providers — AWS + Cloudflare
# ──────────────────────────────────────────────

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Reads CLOUDFLARE_API_TOKEN env var automatically.
# Falls back to var.cloudflare_api_token if set in tfvars.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
