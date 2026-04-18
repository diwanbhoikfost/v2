#!/bin/bash

# ============================================================
# dirmeluna.sh — Setup Script untuk SSH WebSocket Proxy
# ============================================================

apt update -y
apt install python3 -y
apt install python3-pip -y

dirmeluna="/etc/whoiamluna"

mkdir -p $dirmeluna

repo="https://raw.githubusercontent.com/yansyntax/autolunatic/main/"

wget -q -O $dirmeluna/ws.py "${repo}configure/ws.py"
chmod +x $dirmeluna/ws.py


# ============================================================
# Service 1: SSH WebSocket (port 10015 → SSH port 109)
# ============================================================
cat > /etc/systemd/system/ws.service << END
[Unit]
Description=SSH WebSocket Proxy
Documentation=https://google.com
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/python3 -O $dirmeluna/ws.py 10015
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable ws.service
systemctl start ws.service
systemctl restart ws.service


# ============================================================
# Service 2: OpenVPN WebSocket (port 10012 → OpenVPN)
# ============================================================
cat > /etc/systemd/system/ws-ovpn.service << END
[Unit]
Description=OpenVPN WebSocket Proxy
Documentation=https://google.com
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/python3 -O $dirmeluna/ws.py 10012
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable ws-ovpn.service
systemctl start ws-ovpn.service
systemctl restart ws-ovpn.service


echo ""
echo "=== Setup Selesai ==="
echo "ws.service      : $(systemctl is-active ws.service)"
echo "ws-ovpn.service : $(systemctl is-active ws-ovpn.service)"
echo ""
