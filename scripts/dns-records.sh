#!/usr/bin/env bash
# ──────────────────────────────────────────────
# Task 5: List all DNS records using a scoped API token
#
# Token scope: Zone → DNS → Read (single zone)
# Auth method: Bearer token (NOT the legacy X-Auth-Key)
# ──────────────────────────────────────────────
set -euo pipefail

# ── Configuration ─────────────────────────────
# Set these as environment variables or replace the placeholders:
#   export CF_API_TOKEN="your-scoped-token"
#   export CF_ZONE_ID="your-zone-id"
CF_API_TOKEN="${CF_API_TOKEN:?Missing CF_API_TOKEN — create a scoped token with Zone:DNS:Read}"
CF_ZONE_ID="${CF_ZONE_ID:?Missing CF_ZONE_ID — find it in the Cloudflare dashboard Overview page}"

API_BASE="https://api.cloudflare.com/client/v4"

# ── 1. Verify token is valid ──────────────────
echo "==> Verifying API token..."
curl -s "${API_BASE}/user/tokens/verify" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" | jq .

echo ""

# ── 2. List all DNS records ───────────────────
echo "==> Fetching DNS records for zone ${CF_ZONE_ID}..."
curl -s "${API_BASE}/zones/${CF_ZONE_ID}/dns_records?per_page=100" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" | jq '{
    success: .success,
    total_records: .result_info.total_count,
    records: [.result[] | {
      type:    .type,
      name:    .name,
      content: .content,
      proxied: .proxied,
      ttl:     .ttl
    }]
  }'
