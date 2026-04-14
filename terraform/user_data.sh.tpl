#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# EC2 Bootstrap — Origin Server + cloudflared
#
# This script runs once on first boot via EC2 user_data.
# It installs Node.js, cloudflared, clones the repo,
# and starts both services as systemd units.
# ──────────────────────────────────────────────

# Log all output for debugging (viewable via /var/log/user_data.log)
LOG="/var/log/user_data.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== Bootstrap started at $(date -u) ==="

# ── 1. System packages ───────────────────────
# AL2023 uses dnf (not yum). Node.js 18+ is available in the default repos.
dnf update -y -q
dnf install -y -q nodejs npm git

# ── 2. Install cloudflared ───────────────────
# Latest stable release from Cloudflare's GitHub.
# This is the recommended install method for RPM-based distros.
rpm -i https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-x86_64.rpm

# ── 3. Clone and start origin server ─────────
# Source of truth: public GitHub repo (aforero22/app-sec).
git clone https://github.com/aforero22/app-sec.git /opt/app-sec
cd /opt/app-sec/origin
npm install --production

# Run the origin server as a systemd service for automatic restart.
# User=nobody drops privileges — the server doesn't need root.
cat > /etc/systemd/system/origin-server.service <<'EOF'
[Unit]
Description=Origin Header Echo Server
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/opt/app-sec/origin
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=5
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now origin-server

# ── 4. Install cloudflared as a service ──────
# The tunnel token is injected by Terraform (templatefile) from the
# cloudflare_zero_trust_tunnel_cloudflared_token data source.
# It authenticates this instance to the named tunnel in Cloudflare.
cloudflared service install ${tunnel_token}

echo "=== Bootstrap completed at $(date -u) ==="
