#!/bin/bash

##### BASE : LUNATIC TUNNELING x GPT #####
reset_ui() {    
    tput cup 0 0 && printf "\033c"    
    printf "\033[H"
    sleep 0.05
    tput clear    
}

set -e
reset_ui

NC='\e[0m'
WHITE='\033[1;97m'
CYAN='\033[38;5;51m'
CYAN_SOFT='\033[38;5;117m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
YELLOW='\033[38;5;226m'
DIM='\033[2m'

run_step() {
    local text="$1"
    local spin='|/-\'
    local i=0

    tput civis
    for ((j=0; j<14; j++)); do
        i=$(( (i+1) %4 ))
        printf "\r ${CYAN}%c${NC} ${WHITE}%-50s${DIM}...${NC}" \
        "${spin:$i:1}" "$text"
        sleep 0.12
    done

    printf "\r ${GREEN}✔${NC} ${WHITE}%-50s${NC}\n" "$text"
    tput cnorm
}

# ========================================
# HEADER
# ========================================
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}     TELEGRAM BOT + VPS API INSTALLER${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ========================================
# USER INPUT DULU (semua di awal)
# ========================================
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}             BOT CONFIGURATION${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -rp " Bot Token      : " BOT_TOKEN < /dev/tty
read -rp " Owner ID       : " OWNER_ID < /dev/tty
read -rp " Pakasir Slug   : " PAKASIR_SLUG < /dev/tty
read -rp " Pakasir API Key: " PAKASIR_API_KEY < /dev/tty
read -rp " Bot Name       : " BOT_NAME < /dev/tty

if [[ -z "$BOT_TOKEN" || -z "$OWNER_ID" ]]; then
    echo -e "\n${RED}✖ Bot Token dan Owner ID wajib diisi!${NC}"
    exit 1
fi

echo ""
echo -e " ${GREEN}✔${NC} ${WHITE}Konfigurasi diterima. Memulai instalasi...${NC}"
echo ""
sleep 1

# ========================================
# INSTALL BASE
# ========================================
run_step "Updating package repository"
apt update -y &> /dev/null

run_step "Installing required dependencies"
apt install -y unzip wget curl openssl jq &> /dev/null

run_step "Removing previous Node.js installation"
apt purge -y nodejs npm &> /dev/null || true
rm -rf /usr/lib/node_modules ~/.npm /usr/bin/node /usr/bin/npm &> /dev/null || true

run_step "Installing Node.js v20"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - &> /dev/null
apt install -y nodejs &> /dev/null

# ========================================
# DOWNLOAD BOT
# ========================================
run_step "Downloading bot package"
wget -q -O bot.zip https://raw.githubusercontent.com/diwanbhoikfost/v2/main/BOT/bot.zip

if [[ ! -f "bot.zip" ]]; then
    echo -e "${RED}✖ Failed to download bot package${NC}"
    exit 1
fi

run_step "Extracting bot files"
rm -rf /tmp/bot_EXTRACT
mkdir -p /tmp/bot_EXTRACT
unzip -o bot.zip -d /tmp/bot_EXTRACT &> /dev/null

BOT_FOLDER=$(find /tmp/bot_EXTRACT -maxdepth 1 -type d ! -name "*EXTRACT" | head -n 1)
[[ -z "$BOT_FOLDER" ]] && { echo -e "${RED}✖ Bot folder not found${NC}"; exit 1; }

run_step "Deploying bot to system"
rm -rf /root/bot
mv "$BOT_FOLDER" /root/bot
chmod +x /root/bot/shell_script/* 2>/dev/null || true

# ========================================
# DETECT BOT IP
# ========================================
BOT_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

# ========================================
# SAVE CONFIG (pakai node untuk JSON aman)
# ========================================
mkdir -p /root/bot/data

run_step "Saving bot configuration"
node -e "
const fs = require('fs');
const data = {
  token: process.argv[1],
  owner_id: process.argv[2],
  pakasir_slug: process.argv[3],
  pakasir_api_key: process.argv[4],
  bot_name: process.argv[5]
};
fs.writeFileSync('/root/bot/data/.avars.json', JSON.stringify(data, null, 2));
" "$BOT_TOKEN" "$OWNER_ID" "$PAKASIR_SLUG" "$PAKASIR_API_KEY" "$BOT_NAME"

run_step "Configuring empty server list"
cat > /root/bot/data/server.js << 'SRVEOF'
const servers = [];

module.exports = servers;
SRVEOF

# ========================================
# INSTALL BOT MODULES + REBUILD SQLITE3
# ========================================
cd /root/bot

run_step "Installing bot modules"
npm install &> /dev/null

run_step "Installing additional modules"
npm install node-telegram-bot-api axios qrcode sql.js ssh2 &> /dev/null

run_step "Removing old sqlite3 (if exists)"
npm uninstall sqlite3 better-sqlite3 &> /dev/null || true

# ========================================
# CREATE BOT SERVICE
# ========================================
run_step "Creating bot service"
cat > /etc/systemd/system/bot.service << EOF
[Unit]
Description=Telegram VPN Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/bot
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

run_step "Starting bot service"
systemctl daemon-reload
systemctl enable bot &> /dev/null
systemctl restart bot

# ========================================
# CLEANUP
# ========================================
run_step "Cleaning temporary files"
cd ~
rm -f bot.zip
rm -rf /tmp/bot_EXTRACT

# ========================================
# VERIFY
# ========================================
sleep 3
BOT_STATUS=$(systemctl is-active bot 2>/dev/null || echo "failed")

# ========================================
# SAVE CREDENTIALS
# ========================================
SAVE_FILE="/root/bot-credentials.txt"
cat > "$SAVE_FILE" << CREDEOF
============================================
  BOT CREDENTIALS
  Tanggal: $(date '+%Y-%m-%d %H:%M:%S')
============================================

BOT TOKEN     : $BOT_TOKEN
OWNER ID      : $OWNER_ID
BOT NAME      : $BOT_NAME
BOT IP        : $BOT_IP

PAKASIR SLUG  : $PAKASIR_SLUG
PAKASIR API   : $PAKASIR_API_KEY

============================================
  SIMPAN FILE INI! /root/bot-credentials.txt
============================================
CREDEOF
chmod 600 "$SAVE_FILE"

# ========================================
# RESULT
# ========================================
reset_ui
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✔ Installation completed successfully${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ "$BOT_STATUS" == "active" ]]; then
    echo -e " ${WHITE}Bot Service${NC} (${BOT_IP})"
    echo -e "   ${DIM}Status  :${NC} ${GREEN}Running ✔${NC}"
else
    echo -e " ${WHITE}Bot Service${NC} (${BOT_IP})"
    echo -e "   ${DIM}Status  :${NC} ${RED}Error ✖${NC}"
    echo -e "   ${DIM}Debug   :${NC} journalctl -u bot --no-pager -n 20"
fi
echo -e "   ${DIM}Manage  :${NC} systemctl [start|stop|restart|status] bot"
echo -e "   ${DIM}Log     :${NC} journalctl -u bot -f"
echo ""
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${YELLOW}⚠  LANGKAH SELANJUTNYA:${NC}"
echo -e ""
echo -e "   ${WHITE}Buka Telegram → /admin → 📌 Add Server${NC}"
echo -e "   ${DIM}Masukkan IP + password root VPS VPN.${NC}"
echo -e "   ${DIM}Bot otomatis install API & sync scripts.${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " ${DIM}Credentials disimpan di:${NC} ${WHITE}/root/bot-credentials.txt${NC}"
echo ""
