# Cloudflare CSE Technical Project

> Application Security homework — origin server, Cloudflare Tunnel, Workers, Zero Trust

## Architecture

```
                     TLS 1.2+                     Tunnel (QUIC)
[Visitor] ──────────────────> [Cloudflare Edge] ─────────────────> [EC2 eu-south-2]
                                │                                   │
                                ├─ Worker (cURL redirect + WAF)     ├─ Hono server (:8080)
                                ├─ Transform Rules (sec headers)    ├─ cloudflared daemon
                                ├─ SSL Full-Strict                  └─ SG: 0 inbound rules
                                └─ Zero Trust Access (/secure)
```

## Live Endpoints

| Endpoint | Purpose | Test command |
|----------|---------|-------------|
| `https://tunnel.ossfia.ai` | Echo HTTP request headers | `curl https://tunnel.ossfia.ai` |
| `https://tunnel.ossfia.ai/secure` | Zero Trust protected | Open in browser (OTP auth) |
| `https://tunnel.ossfia.ai/health` | Health check | `curl https://tunnel.ossfia.ai/health` |

## Quick Test Commands

```bash
# 1. Echo headers (JSON)
curl -s https://tunnel.ossfia.ai | jq .

# 2. cURL redirect — should return 302
curl -I https://tunnel.ossfia.ai

# 3. Cookie bypass — should return 200 (no redirect)
curl -I -b "cf-noredir=true" https://tunnel.ossfia.ai

# 4. SQLi block — should return 403
curl "https://tunnel.ossfia.ai/login?user=admin'%20OR%201=1--"

# 5. XSS block — should return 403
curl "https://tunnel.ossfia.ai/search?q=%3Cscript%3Ealert(1)%3C/script%3E"

# 6. Security headers inspection
curl -sD - -o /dev/null -b "cf-noredir=true" https://tunnel.ossfia.ai

# 7. Full WAF evidence collection
./scripts/test-waf.sh https://tunnel.ossfia.ai
```

## Project Structure

```
app-sec/
├── terraform/              # Infrastructure as Code (AWS + Cloudflare)
│   ├── providers.tf        # AWS and Cloudflare provider config
│   ├── variables.tf        # Input variables
│   ├── aws.tf              # VPC, Security Group (0 inbound), EC2
│   ├── cloudflare.tf       # Tunnel, DNS, SSL, TLS, security headers
│   ├── access.tf           # Zero Trust application + policy
│   ├── outputs.tf          # Useful output values
│   └── user_data.sh.tpl    # EC2 bootstrap script
├── origin/                 # Origin server (Hono on Node.js)
│   ├── index.js            # Header echo endpoint
│   └── package.json
├── worker/                 # Cloudflare Worker
│   ├── src/index.js        # cURL redirect + cookie bypass + WAF
│   ├── wrangler.toml       # Worker configuration
│   └── package.json
├── scripts/
│   ├── dns-records.sh      # Task 5: API call with scoped token
│   └── test-waf.sh         # WAF evidence collection
├── evidence/               # Screenshots and test output
├── docs/
│   └── REPORT.md           # Written report (deliverable)
└── .github/workflows/
    └── ci.yml              # Terraform validate + Worker deploy
```

## Infrastructure as Code

All infrastructure is managed with Terraform using two providers:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars  # fill in your values
terraform init
terraform plan
terraform apply
```

### What Terraform manages

| Resource | Provider | Purpose |
|----------|----------|---------|
| VPC + Security Group | AWS | Zero inbound rules (Tunnel only) |
| EC2 instance | AWS | Origin server with auto-bootstrap |
| Tunnel + config | Cloudflare | Secure connectivity to origin |
| DNS CNAME | Cloudflare | `tunnel.ossfia.ai` → tunnel |
| SSL mode | Cloudflare | Full (Strict) |
| Min TLS version | Cloudflare | 1.2 |
| Transform Rules | Cloudflare | Security response headers |
| Access app + policy | Cloudflare | Zero Trust on `/secure` |

### What Wrangler manages

The Worker is deployed separately via `wrangler deploy` (and CI/CD) because Wrangler is Cloudflare's native tool for Worker development — it provides local dev, tail, and the best deployment experience.

## Security Decisions

- **Zero inbound firewall rules** — The EC2 security group has no inbound rules. All traffic flows through Cloudflare Tunnel (outbound-only QUIC connections). This eliminates the origin's entire inbound attack surface.

- **IMDSv2 required** — EC2 metadata endpoint requires token-based access, preventing SSRF-based credential theft.

- **Scoped API tokens** — Every token follows least-privilege: DNS read-only for listing, Workers deploy for CI/CD.

- **Security headers at the edge** — Static headers (HSTS, CSP, X-Frame-Options) are set via Cloudflare Transform Rules, ensuring they apply even to cached responses.

## API Token Scopes

| Token | Permissions | Used by |
|-------|------------|---------|
| Terraform | Zone:Edit, DNS:Edit, SSL:Edit, Workers:Edit, Access:Edit, Tunnel:Edit | `terraform apply` |
| DNS Read | Zone:DNS:Read | `scripts/dns-records.sh` |
| Workers Deploy | Workers:Edit | GitHub Actions CI/CD |

## Author

Alejandro Forero — [aforero.spain@gmail.com](mailto:aforero.spain@gmail.com)
