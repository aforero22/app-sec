# Technical Report — Cloudflare CSE Homework

**Author:** Alejandro Forero  
**Date:** April 2026

---

## 1. Implementation Summary

### Architecture Overview

I built a header-echo origin server on AWS EC2 (eu-west-1, Ireland) connected to Cloudflare exclusively through a Cloudflare Tunnel. The origin has **zero inbound firewall rules** — all traffic flows through the tunnel's outbound-only QUIC connection to Cloudflare's edge. I verified this directly: the EC2's public IP does not respond to ping, HTTP, HTTPS, or the origin port — every direct connection attempt times out. The only viable path into the origin is through the tunnel.

The entire infrastructure is defined as code using **Terraform with two providers** (AWS + Cloudflare), making the setup fully reproducible with a single `terraform apply`.

### Task-by-Task Summary

| Task | Approach |
|------|----------|
| **1. Origin + headers** | Hono (Node.js) server echoing all request headers as JSON or HTML based on content negotiation. Security headers applied via Cloudflare Transform Rules at the edge. |
| **2. SSL Full-Strict** | Configured via Terraform (`cloudflare_zone_setting`, setting_id `ssl`, value `strict`). The tunnel itself provides a valid origin certificate, satisfying the strict validation requirement. |
| **3. TLS 1.2+** | Set via Terraform (`min_tls_version = "1.2"`). Also enabled TLS 1.3 as a bonus. |
| **4. Tunnel** | Named tunnel created via Terraform, `cloudflared` installed on EC2 as a systemd service via user_data bootstrap. DNS CNAME `tunnel.ossfia.ai` points to the tunnel. |
| **5. API token** | Created a scoped token with Zone:DNS:Read permission on a single zone. Script uses Bearer auth and outputs formatted JSON via `jq`. See [`evidence/dns-records.txt`](../evidence/dns-records.txt). |
| **6. Worker** | Fixed 4 bugs in the provided script. Implemented using ES modules format. Added cookie bypass (`cf-noredir=true`) and WAF-like detection with 10 rules (5 SQLi + 5 XSS). See [`evidence/waf-tests.txt`](../evidence/waf-tests.txt). |
| **7. Zero Trust** | Access Application on `tunnel.ossfia.ai/secure` with email-based allow policy, using Cloudflare's built-in One-Time PIN authentication. |

### Bugs Fixed in the Worker Script

1. **`req` → `request`** — The function parameter was `request`, but the body referenced `req` (undefined variable → ReferenceError).
2. **`.matches('curl').true`** — JavaScript strings have no `.matches()` method with a `.true` property. Replaced with `/curl/i.test(ua)`.
3. **Missing null guard** — `headers.get('user-agent')` can return `null`. Added `|| ""` fallback.
4. **Incomplete redirect URL** — The target was just the hostname, missing the `/workers/learning/` path.

---

## 2. What I Learned

- **Cloudflare Tunnel eliminates the need for public IPs on origin servers.** This was the most impactful realization — combined with a security group that has zero inbound rules, the origin becomes invisible to the internet. This is a fundamentally different security posture than traditional reverse proxy setups.

- **The Cloudflare Terraform provider v5 has significant schema changes from v4.** Resource names like `cloudflare_record` → `cloudflare_dns_record`, and the shift from nested HCL blocks to object/list syntax for Zero Trust resources required careful attention to the migration guide.

- **Transform Rules are powerful for security header management.** Setting headers at the edge (rather than the origin) means they apply to all responses, including cached and error responses, without needing to modify application code.

---

## 3. How I Filled Knowledge Gaps

- **Cloudflare Developer Docs** — Primary source for Tunnel setup, Workers API, and Transform Rules syntax.
- **Terraform Registry** — Provider documentation for exact resource attributes and v4-to-v5 migration notes.
- **Cloudflare Community Forums** — Troubleshooting specific issues like the `cloudflare_zone_setting` value/enabled schema confusion (GitHub issue #5653).
- **Mozilla MDN** — Reference for security header best practices (CSP directives, HSTS preload requirements).
- **OWASP** — SQL injection and XSS pattern references for the WAF rule design.

---

## 4. Product Experience

### Cloudflare Tunnels

**In simple language:** A Cloudflare Tunnel is a private, outbound-only connection from your server to Cloudflare. Instead of opening your server to the internet and hoping your firewall holds, the tunnel lets your server call out to Cloudflare — like making a phone call instead of leaving your front door open.

**Issues encountered:**
- The `config_src` parameter in Terraform was initially confusing — in v4 you needed to generate a random secret, in v5 you use `config_src = "cloudflare"` and the platform manages the credentials.
- The catch-all ingress rule is mandatory but easy to miss — `cloudflared` refuses to start without it.

**Use cases:**
- Replacing VPNs for internal application access
- Exposing local development environments for testing
- Securing legacy applications that cannot handle their own TLS
- Multi-cloud connectivity without firewall rule management

### Cloudflare Workers

**In simple language:** Workers are small programs that run on Cloudflare's network, as close to your users as possible. Instead of sending every request all the way to your server, a Worker can handle it right at the edge — making decisions, modifying responses, or blocking bad traffic in milliseconds.

**Issues encountered:**
- The legacy `addEventListener("fetch")` format vs. the modern ES modules `export default` — chose the modern format since it is Cloudflare's current recommendation and required for newer features like Durable Objects.
- URL decoding for WAF patterns — attackers encode characters (e.g., `%27` for `'`), so the WAF must inspect both raw and decoded URLs.

**Use cases:**
- Security middleware (WAF rules, bot detection, rate limiting)
- A/B testing and feature flags at the edge
- Geographic routing and localization
- API gateway logic (auth, caching, transformation)

### Cloudflare Zero Trust

**In simple language:** Zero Trust Access is like having a security guard who checks everyone's ID before letting them into a building — regardless of whether they are inside or outside the company network. Every request must prove the user's identity; no one gets in just because they are on the "right" network.

**Issues encountered:**
- The relationship between Access Applications and Policies changed in Terraform provider v5 — policies are now "reusable" account-level resources referenced by applications, rather than being children of applications.
- The One-Time PIN authentication method is simple but relies on email delivery — for production, integrating with an identity provider (Google, Okta, SAML) would be more reliable.

**Use cases:**
- Replacing corporate VPNs with identity-aware access
- Contractor and partner access to specific applications
- Protecting admin panels and internal tools
- Compliance requirements where every access must be authenticated and logged

---

## 5. Target Customer Experience

**Onboarding is remarkably smooth for DNS-based features** — adding a domain and changing nameservers is familiar to anyone who has managed a website. The dashboard guides you through each step clearly.

**Tunnels lower the barrier for security-conscious deployments.** A customer who previously had to manage SSL certificates, configure firewalls, and expose public IPs can now skip all of that. The `cloudflared` install is a single command, and the tunnel token handles authentication automatically.

**Workers could benefit from clearer migration guidance.** The coexistence of the legacy Service Worker format and the modern ES modules format creates confusion, especially when Stack Overflow answers reference the old syntax. A prominent deprecation notice or auto-migration tool would help.

**Zero Trust's free tier (50 users) is a strong acquisition strategy.** Small teams can adopt identity-aware access at no cost, and the natural expansion path to paid tiers aligns with company growth. However, the relationship between Access Applications and Access Policies could be better visualized in the dashboard — new users may not immediately understand that policies are reusable across applications.

**For enterprise customers**, the combination of Terraform support, API-first design, and integrated observability (via `wrangler tail` for Workers, dashboard analytics for Tunnel) makes Cloudflare a strong platform for infrastructure-as-code workflows. The dual-provider Terraform setup (AWS + Cloudflare in one plan) is a compelling story for multi-cloud organizations.
