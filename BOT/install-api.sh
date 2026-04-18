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

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}       VPS API SERVER INSTALLER${NC}"
echo -e "${DIM}    Untuk VPS tambahan (tanpa bot)${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " ${DIM}Installer ini hanya memasang API Server.${NC}"
echo -e " ${DIM}Bot tidak diperlukan di VPS ini.${NC}"
echo -e " ${DIM}Setelah install, tambahkan server ini di bot.${NC}"
echo ""

run_step "Updating package repository"
apt update -y &> /dev/null

run_step "Installing required dependencies"
apt install -y curl openssl jq &> /dev/null

if ! command -v node &> /dev/null; then
    run_step "Installing Node.js v20"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - &> /dev/null
    apt install -y nodejs &> /dev/null
else
    run_step "Node.js already installed ($(node -v))"
fi

API_TOKEN=${API_TOKEN:-$(openssl rand -hex 24)}
API_PORT=${API_PORT:-3456}
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

run_step "Setting up VPS API Server"
mkdir -p /root/vps-api/shell_script

cat > /root/vps-api/package.json << 'PKGEOF'
{
  "name": "vps-bot-api",
  "version": "1.0.0",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.21.0" }
}
PKGEOF

cat > /root/vps-api/server.js << 'SRVEOF'
const express = require('express');
const { execFile } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json({ limit: '5mb' }));

const PORT = process.env.API_PORT || 3456;
const TOKEN = process.env.API_TOKEN || '';

if (!TOKEN) {
  console.error('[API] API_TOKEN belum diset!');
  process.exit(1);
}

const SCRIPT_DIR = path.join(__dirname, 'shell_script');

function authMiddleware(req, res, next) {
  const token = req.headers['x-api-token'] || req.body.token;
  if (!token || token !== TOKEN) {
    return res.status(401).json({ error: 'Unauthorized', message: 'Token tidak valid' });
  }
  next();
}

app.use('/api', authMiddleware);

app.get('/api/ping', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.post('/api/exec', (req, res) => {
  const { script, args } = req.body;
  if (!script) return res.status(400).json({ error: 'BAD_REQUEST', message: 'Parameter "script" wajib diisi' });
  if (!/^[a-zA-Z0-9_]+$/.test(script)) return res.status(400).json({ error: 'BAD_REQUEST', message: 'Nama script tidak valid' });

  const scriptPath = path.join(SCRIPT_DIR, script);
  if (!fs.existsSync(scriptPath)) return res.status(404).json({ error: 'SCRIPT_NOT_FOUND', message: `Script "${script}" tidak ditemukan` });

  const safeArgs = (args || []).map(a => String(a));
  execFile('bash', [scriptPath, ...safeArgs], { timeout: 30000 }, (err, stdout, stderr) => {
    if (err) {
      if (err.killed) return res.status(504).json({ error: 'TIMEOUT', message: 'Script timeout (30 detik)', output: stdout || '' });
      return res.json({ success: false, exitCode: err.code, output: ((stdout || '') + (stderr || '')).trim() });
    }
    res.json({ success: true, exitCode: 0, output: ((stdout || '') + (stderr || '')).trim() });
  });
});

app.post('/api/sync', (req, res) => {
  const { scripts } = req.body;
  if (!scripts || !Array.isArray(scripts) || scripts.length === 0) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Parameter "scripts" wajib diisi' });
  }
  if (!fs.existsSync(SCRIPT_DIR)) fs.mkdirSync(SCRIPT_DIR, { recursive: true });

  const results = [];
  for (const item of scripts) {
    if (!item.name || !item.content) { results.push({ name: item.name || '?', status: 'skipped', reason: 'nama atau isi kosong' }); continue; }
    if (!/^[a-zA-Z0-9_]+$/.test(item.name)) { results.push({ name: item.name, status: 'skipped', reason: 'nama tidak valid' }); continue; }
    try {
      const filePath = path.join(SCRIPT_DIR, item.name);
      fs.writeFileSync(filePath, item.content, 'utf8');
      fs.chmodSync(filePath, '755');
      results.push({ name: item.name, status: 'ok' });
    } catch (e) { results.push({ name: item.name, status: 'error', reason: e.message }); }
  }
  const ok = results.filter(r => r.status === 'ok').length;
  const failed = results.filter(r => r.status !== 'ok').length;
  res.json({ success: true, synced: ok, failed, details: results });
});

app.get('/api/scripts', (req, res) => {
  if (!fs.existsSync(SCRIPT_DIR)) return res.json({ scripts: [] });
  const files = fs.readdirSync(SCRIPT_DIR).filter(f => fs.statSync(path.join(SCRIPT_DIR, f)).isFile());
  res.json({ scripts: files });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[API] VPS Bot API running on port ${PORT}`);
  console.log(`[API] Script directory: ${SCRIPT_DIR}`);
});
SRVEOF

cd /root/vps-api
run_step "Installing API modules"
npm install &> /dev/null

run_step "Creating API service"
cat > /etc/systemd/system/vps-api.service << EOF
[Unit]
Description=VPS Bot API Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/vps-api
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
Environment=API_TOKEN=${API_TOKEN}
Environment=API_PORT=${API_PORT}

[Install]
WantedBy=multi-user.target
EOF

run_step "Starting API service"
systemctl daemon-reload
systemctl enable vps-api &> /dev/null
systemctl restart vps-api

SAVE_FILE="/root/api-credentials.txt"
cat > "$SAVE_FILE" << EOF
============================================
  VPS API CREDENTIALS
  Tanggal: $(date '+%Y-%m-%d %H:%M:%S')
============================================

SERVER IP     : $SERVER_IP
API PORT      : $API_PORT
API TOKEN     : $API_TOKEN
API URL       : http://${SERVER_IP}:${API_PORT}

============================================
  TAMBAHKAN KE server.js DI BOT:

  {
    "name": "GANTI_NAMA",
    "ip": "${SERVER_IP}",
    "apiUrl": "http://${SERVER_IP}:${API_PORT}",
    "apiToken": "${API_TOKEN}",
    "limit": 90,
    "used": 0
  }

============================================
  SIMPAN FILE INI! /root/api-credentials.txt
============================================
EOF
chmod 600 "$SAVE_FILE"

reset_ui
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✔ API Server installed successfully${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " ${WHITE}API Service${NC}"
echo -e "   ${DIM}URL     :${NC} ${CYAN}http://${SERVER_IP}:${API_PORT}${NC}"
echo -e "   ${DIM}Token   :${NC} ${YELLOW}${API_TOKEN}${NC}"
echo -e "   ${DIM}Manage  :${NC} systemctl [start|stop|restart|status] vps-api"
echo -e "   ${DIM}Log     :${NC} journalctl -u vps-api -f"
echo ""
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${YELLOW}⚠  Tambahkan server ini di bot:${NC}"
echo ""
echo -e "   ${DIM}Edit file${NC} ${WHITE}data/server.js${NC} ${DIM}di bot, tambahkan:${NC}"
echo ""
echo -e "   ${CYAN}{${NC}"
echo -e "     ${WHITE}\"name\": \"GANTI_NAMA\",${NC}"
echo -e "     ${WHITE}\"ip\": \"${SERVER_IP}\",${NC}"
echo -e "     ${WHITE}\"apiUrl\": \"http://${SERVER_IP}:${API_PORT}\",${NC}"
echo -e "     ${WHITE}\"apiToken\": \"${API_TOKEN}\",${NC}"
echo -e "     ${WHITE}\"limit\": 90, \"used\": 0${NC}"
echo -e "   ${CYAN}}${NC}"
echo ""
echo -e " ${DIM}Lalu sync scripts lewat Telegram: Admin > Sync Scripts${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " ${DIM}Credentials disimpan di:${NC} ${WHITE}/root/api-credentials.txt${NC}"
echo ""
echo -e " ${DIM}Test API:${NC}"
echo -e " curl -H 'X-Api-Token: ${API_TOKEN}' http://localhost:${API_PORT}/api/ping"
echo ""
