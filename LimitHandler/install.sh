#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
set -e

# ========================================
# COLOR SYSTEM
# ========================================
NC='\e[0m'
WHITE='\033[1;97m'
CYAN='\033[38;5;51m'
CYAN_SOFT='\033[38;5;117m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
DIM='\033[2m'

clear

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${WHITE}        INSTALL LUNATIC MONITOR SERVICE${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WHITE}System Overview:${NC}"
echo -e "   ${CYAN}•${NC} Engine        : Python Monitor Core"
echo -e "   ${CYAN}•${NC} Mode          : Real-time Protection"
echo -e "   ${CYAN}•${NC} Integration   : Xray / SSH / Trojan / VMESS / VLESS"
echo -e "   ${CYAN}•${NC} Security      : Anti Abuse & Auto Enforcement"
echo -e "   ${CYAN}•${NC} Status        : INSTALLING"

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ========================================
# DOWNLOAD
# ========================================
echo -e " ${WHITE}Downloading Core:${NC}"

wget -q -O /usr/bin/monitor.py https://raw.githubusercontent.com/diwanbhoikfost/v2/main/LimitHandler/monitor.py
wget -q -O /usr/bin/triall_clean.py https://raw.githubusercontent.com/diwanbhoikfost/v2/main/LimitHandler/triall_clean.py

chmod +x /usr/bin/monitor.py
chmod +x /usr/bin/triall_clean.py
# ========================================
# LOG FILE
# ========================================
touch /var/log/lunatic_monitor.log
chmod 644 /var/log/lunatic_monitor.log

# ========================================
# CREATE SERVICE
# ========================================
echo -e " ${WHITE}Configuring Service:${NC}"

cat > /etc/systemd/system/monitor.service <<EOF
[Unit]
Description=Lunatic Unified Monitor (Realtime Anti Abuse Engine)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/bin/monitor.py
Restart=always
RestartSec=1
User=root

# Performance Boost
LimitNOFILE=65535
Nice=-20

# Logging
StandardOutput=append:/var/log/lunatic_monitor.log
StandardError=append:/var/log/lunatic_monitor.log

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/triall.service <<EOF
[Unit]
Description=Auto Trial Cleaner
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/bin/triall_clean.py
EOF

cat > /etc/systemd/system/triall.timer <<EOF
[Unit]
Description=Run Trial Cleaner every minute

[Timer]
OnBootSec=30
OnUnitActiveSec=60

[Install]
WantedBy=timers.target
EOF

# ========================================
# ENABLE SERVICE
# ========================================
echo -e " ${WHITE}Activating Service:${NC}"

systemctl daemon-reexec
systemctl daemon-reload

systemctl enable monitor
systemctl restart monitor
systemctl enable triall.timer
systemctl start triall.timer

sleep 1

STATUS=$(systemctl is-active lunatic-monitor)

# ========================================
# RESULT
# ========================================
clear

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✔ INSTALLATION COMPLETED${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""

echo -e " ${WHITE}Service Information:${NC}"
echo -e "   ${CYAN}•${NC} Name        : monitor.service"
echo -e "   ${CYAN}•${NC} Status      : ${GREEN}${STATUS^^}${NC}"
echo -e "   ${CYAN}•${NC} Mode        : Realtime Protection"
echo -e "   ${CYAN}•${NC} Log File    : /var/log/lunatic_monitor.log"

echo ""
echo -e " ${WHITE}Protection Modules:${NC}"
echo -e "   ${CYAN}•${NC} Multi Login Detection"
echo -e "   ${CYAN}•${NC} Quota Enforcement"
echo -e "   ${CYAN}•${NC} Expired Account Removal"
echo -e "   ${CYAN}•${NC} Trial Auto Kill System"
echo -e "   ${CYAN}•${NC} IP Blocking Engine"

echo ""
echo -e " ${WHITE}System Status:${NC}"
echo -e "   ${CYAN}•${NC} Monitor Engine   : ACTIVE"
echo -e "   ${CYAN}•${NC} Auto Protection  : ENABLED"
echo -e "   ${CYAN}•${NC} Enforcement Mode : AGGRESSIVE"

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

sleep 2