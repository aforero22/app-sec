#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# EC2 Bootstrap — Origin Server + cloudflared
# ──────────────────────────────────────────────

LOG="/var/log/user_data.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== Bootstrap started at $(date -u) ==="

# ── 1. System packages ───────────────────────
dnf update -y -q
dnf install -y -q nodejs npm git

# ── 2. Install cloudflared ───────────────────
rpm -i https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-x86_64.rpm

# ── 3. Clone and start origin server ─────────
git clone https://github.com/aforero22/app-sec.git /opt/app-sec
cd /opt/app-sec/origin
npm install --production

# Create systemd service for the origin server
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
cloudflared service install ${tunnel_token}

echo "=== Bootstrap completed at $(date -u) ==="
