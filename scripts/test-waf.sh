#!/usr/bin/env bash
# ──────────────────────────────────────────────
# WAF Evidence Collection Script
# Demonstrates SQLi and XSS blocking by the Worker
# ──────────────────────────────────────────────
set -euo pipefail

BASE_URL="${1:?Usage: $0 <base-url>  (e.g. https://tunnel.ossfia.ai)}"

echo "========================================"
echo " WAF Evidence Collection"
echo " Target: ${BASE_URL}"
echo "========================================"
echo ""

# ── Test 1: Normal request (should 200) ───────
echo "--- Test 1: Normal request (expect 200) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "${BASE_URL}/"
echo ""

# ── Test 2: cURL redirect (should 302) ────────
echo "--- Test 2: cURL redirect (expect 302) ---"
curl -s -o /dev/null -w "HTTP %{http_code} → %{redirect_url}\n" "${BASE_URL}/"
echo ""

# ── Test 3: Cookie bypass (should 200, not 302) ─
echo "--- Test 3: Cookie bypass (expect 200, no redirect) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -b "cf-noredir=true" "${BASE_URL}/"
echo ""

# ── Test 4: SQLi — authentication bypass ──────
echo "--- Test 4: SQLi — OR 1=1 (expect 403) ---"
curl -s -w "\nHTTP %{http_code}\n" "${BASE_URL}/login?user=admin'%20OR%201=1--"
echo ""

# ── Test 5: SQLi — UNION SELECT ───────────────
echo "--- Test 5: SQLi — UNION SELECT (expect 403) ---"
curl -s -w "\nHTTP %{http_code}\n" "${BASE_URL}/products?id=1%20UNION%20SELECT%20username,password%20FROM%20users--"
echo ""

# ── Test 6: XSS — script injection ───────────
echo "--- Test 6: XSS — <script> tag (expect 403) ---"
curl -s -w "\nHTTP %{http_code}\n" "${BASE_URL}/search?q=%3Cscript%3Ealert(1)%3C/script%3E"
echo ""

# ── Test 7: XSS — event handler ──────────────
echo "--- Test 7: XSS — onerror handler (expect 403) ---"
curl -s -w "\nHTTP %{http_code}\n" "${BASE_URL}/page?img=%3Cimg%20src=x%20onerror=alert(1)%3E"
echo ""

# ── Test 8: Security headers check ───────────
echo "--- Test 8: Security response headers ---"
curl -s -D - -o /dev/null -b "cf-noredir=true" "${BASE_URL}/" | grep -iE "^(content-security|strict-transport|x-frame|x-content-type|referrer-policy|permissions-policy)"
echo ""

echo "========================================"
echo " Evidence collection complete"
echo "========================================"
