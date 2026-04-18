#!/bin/bash
# zivpn source : zahidbd2
# udp custom  : EvroDEV
# script by lunatic.
# ========================================
# COLOR SYSTEM
# ========================================
NC='\e[0m'
WHITE='\033[1;97m'
CYAN='\033[38;5;51m'
CYAN_SOFT='\033[38;5;117m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
YELLOW='\033[1;33m'
ORANGE='\e[38;5;130m'
DIM='\033[2m'

clear

# ========================================
# HEADER
# ========================================
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${WHITE}        ZIVPN & UDP CUSTOM INSTALLER${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WHITE}System Overview:${NC}"
echo -e "   ${CYAN}•${NC} Engine        : ZIVPN UDP Core"
echo -e "   ${CYAN}•${NC} Mode          : High Performance UDP Tunnel"
echo -e "   ${CYAN}•${NC} Integration   : Kernel NAT & Custom UDP"
echo -e "   ${CYAN}•${NC} Security      : SSL + IP Filtering"
echo -e "   ${CYAN}•${NC} Status        : INITIALIZING"

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ========================================
# PERMISSION CHECK
# ========================================
echo -e " ${WHITE}Permission Validation:${NC}"

IP=$(wget -qO- ipinfo.io/ip || echo "")

if [[ -z "$IP" ]]; then
    echo -e "${RED}✖ Unable to detect server IP${NC}"
    exit 1
fi

DB_URL="https://raw.githubusercontent.com/diwanbhoikfost/permission/main/regist"
DB=$(wget -qO- $DB_URL || echo "")

EXP=$(echo "$DB" | grep -w "$IP" | awk '{print $2}' | head -n1)

if [[ -z "$EXP" ]]; then
    echo -e "${RED}✖ Permission Denied${NC}"
    echo -e " ${WHITE}IP${NC} : $IP not registered"
    exit 1
fi

NOW=$(date +%Y-%m-%d)

if [[ "$NOW" > "$EXP" ]]; then
    echo -e "${RED}✖ License Expired${NC}"
    echo -e " ${WHITE}Expired${NC} : $EXP"
    exit 1
fi

echo -e "${GREEN}✔ Permission Granted${NC}"
echo -e " ${WHITE}Expired${NC} : $EXP"

# ========================================
# ARCH DETECT
# ========================================
echo -e "\n ${WHITE}System Detection:${NC}"

ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
        ARCH_TYPE="AMD64"
        ;;
    aarch64|arm64)
        BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
        ARCH_TYPE="ARM64"
        ;;
    *)
        echo -e "${RED}✖ Unsupported Architecture${NC}"
        exit 1
        ;;
esac

echo -e " ${CYAN}•${NC} Architecture : ${WHITE}$ARCH_TYPE${NC}"

# ========================================
# CLEAN INSTALL
# ========================================
echo -e "\n ${WHITE}Preparing Environment:${NC}"

systemctl stop zivpn 2>/dev/null
rm -rf /etc/zivpn /usr/local/bin/zivpn

# ========================================
# INSTALL DEPENDENCY
# ========================================
echo -e " ${WHITE}Installing Dependencies:${NC}"
apt-get update -y >/dev/null
apt-get install -y wget curl openssl iptables-persistent >/dev/null

# ========================================
# INSTALL ZIVPN
# ========================================
echo -e " ${WHITE}Installing ZIVPN Core:${NC}"

mkdir -p /etc/zivpn
wget -qO /usr/local/bin/zivpn $BIN_URL
chmod +x /usr/local/bin/zivpn

# CONFIG
wget -qO /etc/zivpn/config.json https://raw.githubusercontent.com/diwanbhoikfost/v2/main/udp/config.json

# SSL
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
-subj "/C=US/ST=CA/O=LUNATIC/CN=zivpn" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt >/dev/null 2>&1

# ========================================
# CREATE DEFAULT USER
# ========================================
echo -e " ${WHITE}Initializing Database:${NC}"

DB="/etc/zivpn/users.db"
mkdir -p /etc/lunatic/zivpn/{ip,logip,detail}

EXP_UNIX=$(date -d "+9999 days" +%s)
echo "zi:${EXP_UNIX}" > $DB

# ========================================
# SERVICE
# ========================================
echo -e " ${WHITE}Configuring Service:${NC}"

cat >/etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=Lunatic ZIVPN UDP Engine
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn >/dev/null
systemctl restart zivpn

# ========================================
# NAT CONFIG
# ========================================
echo -e " ${WHITE}Applying Network Rules:${NC}"

IFACE=$(ip -4 route | awk '/default/ {print $5; exit}')
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to :5667 2>/dev/null

iptables-save > /etc/iptables/rules.v4


# ========================================
# UDP CUSTOM HARUS KE INSTALL KE 2
# ========================================
set -e

cd
mkdir -p /usr/bin/udp

echo "[+] Set timezone Asia/Jakarta"
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# ===============================
# DOWNLOAD UDP CUSTOM
# ===============================
echo "[+] Download udp-custom binary"
wget -q --show-progress --load-cookies /tmp/cookies.txt \
"https://docs.google.com/uc?export=download&confirm=$(wget --quiet \
--save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate \
'https://docs.google.com/uc?export=download&id=1ixz82G_ruRBnEEp4vLPNF2KZ1k8UfrkV' \
-O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p')&id=1ixz82G_ruRBnEEp4vLPNF2KZ1k8UfrkV" \
-O /usr/bin/udp-custom && rm -f /tmp/cookies.txt
chmod +x /usr/bin/udp-custom

echo "[+] Download config.json"
wget -q --show-progress --load-cookies /tmp/cookies.txt \
"https://docs.google.com/uc?export=download&confirm=$(wget --quiet \
--save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate \
'https://docs.google.com/uc?export=download&id=1klXTiKGUd2Cs5cBnH3eK2Q1w50Yx3jbf' \
-O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p')&id=1klXTiKGUd2Cs5cBnH3eK2Q1w50Yx3jbf" \
-O /usr/bin/udp/config.json && rm -f /tmp/cookies.txt
chmod 644 /usr/bin/udp/config.json

# ===============================
# UDP KERNEL TUNING
# ===============================
echo "[+] Apply UDP sysctl tuning"
cat >/etc/sysctl.d/99-udp-custom.conf <<EOF
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF
sysctl --system >/dev/null

# ===============================
# PORT & NAT SETUP
# ===============================
UDP_PORT="7300"
DNAT_MIN="6000"
DNAT_MAX="19999"

DEF_IF=$(ip -4 route | awk '/default/ {print $5; exit}')
if [ -z "$DEF_IF" ]; then
  echo "❌ Tidak bisa deteksi interface default"
  exit 1
fi

echo "[+] Setup DNAT UDP ${DNAT_MIN}-${DNAT_MAX} -> ${UDP_PORT}"
iptables -t nat -C PREROUTING -i "$DEF_IF" -p udp --dport ${DNAT_MIN}:${DNAT_MAX} \
-j DNAT --to-destination :${UDP_PORT} 2>/dev/null || \
iptables -t nat -A PREROUTING -i "$DEF_IF" -p udp --dport ${DNAT_MIN}:${DNAT_MAX} \
-j DNAT --to-destination :${UDP_PORT}

iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

# ===============================
# FIREWALL
# ===============================
if command -v ufw >/dev/null 2>&1; then
  echo "[+] Allow UDP ports in UFW"
  ufw allow ${DNAT_MIN}:${DNAT_MAX}/usr/bin/udp >/dev/null || true
  ufw allow ${UDP_PORT}/usr/bin/udp >/dev/null || true
fi

# ===============================
# SYSTEMD SERVICE
# ===============================
echo "[+] Create systemd service"
cat >/etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Custom Server
After=network-online.target
Wants=network-online.target

[Service]
User=root
Type=simple
WorkingDirectory=/usr/bin/udp
ExecStart=/usr/bin/udp-custom server
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom >/dev/null
systemctl restart udp-custom

# ========================================
# RESULT
# ========================================
STATUS=$(systemctl is-active zivpn)
STAUDC=$(systemctl is-active udp-custom)

clear

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}              INSTALLATION SUCCESSFUL${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e " ${WHITE}Service Information:${NC}"
echo -e "   ${CYAN}•${NC} Service     : ZIVPN UDP,CUSTOM-udp Engine"
echo -e "   ${CYAN}•${NC} ZIVPN      : ${GREEN}${STATUS^^}${NC}"
echo -e "   ${CYAN}•${NC} UdpCustom : ${GREEN}${STAUDC^^}${NC}"
echo -e "   ${CYAN}•${NC} Mode        : High Performance Tunnel"

echo ""
echo -e " ${WHITE}Network Configuration:${NC}"
echo -e "   ${CYAN}•${NC} Interface   : $IFACE"
echo -e "   ${CYAN}•${NC} UDP Range   : 6000 - 19999"
echo -e "   ${CYAN}•${NC} Forward Zivpn: 5667"
echo -e "   ${CYAN}•${NC} Forward Zivpn: 7300"

echo ""
echo -e " ${WHITE}Security Layer:${NC}"
echo -e "   ${CYAN}•${NC} Encryption  : SSL/TLS"
echo -e "   ${CYAN}•${NC} Protocol    : UDP Tunnel"
echo -e "   ${CYAN}•${NC} Access      : Controlled"

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
