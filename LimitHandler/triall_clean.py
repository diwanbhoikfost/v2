#!/usr/bin/env python3

import json, os, time, subprocess
from datetime import datetime

FILES = {
    "zivpn": "/etc/lunatic/triall/ziv-triall.json",
    "vmess": "/etc/lunatic/triall/vme-triall.json",
    "vless": "/etc/lunatic/triall/vle-triall.json",
    "trojan": "/etc/lunatic/triall/tro-triall.json",
    "ssh": "/etc/lunatic/triall/ssh-triall.json"
}

XRAY = "/etc/xray/config.json"
ZIV_DB = "/etc/zivpn/users.db"
ZIV_CFG = "/etc/zivpn/config.json"
TELE_JSON = "/etc/lunatic/telegram.json"
XRAY_LOG = "/var/log/xray/access.log"

# ===============================
# BASIC
# ===============================
def run(cmd):
    subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def now():
    return int(time.time())

def parse(t):
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return int(datetime.strptime(t, fmt).timestamp())
        except:
            continue
    return 0

def load(path):
    if not os.path.exists(path): return []
    try: return json.load(open(path))
    except: return []

def save(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)

# ===============================
# TELEGRAM
# ===============================
def notif(msg):
    try:
        d = load(TELE_JSON)
        key = d.get("main", {}).get("bot_key", "")
        chat = d.get("main", {}).get("chat_id", "")
        if not key or not chat: return

        run(f'curl -s -X POST https://api.telegram.org/bot{key}/sendMessage '
            f'-d chat_id={chat} -d parse_mode=HTML -d text="{msg}"')
    except:
        pass

# ===============================
# XRAY IP TRACK
# ===============================
def get_ips(user):
    ips = set()
    if os.path.exists(XRAY_LOG):
        for line in open(XRAY_LOG):
            if user in line:
                try:
                    ip = line.split()[2].split(":")[0].replace("tcp://","")
                    ips.add(ip)
                except:
                    pass
    return list(ips)

# ===============================
# FORCE DISCONNECT
# ===============================
def force_dc(user, proto):
    ips = get_ips(user)

    for ip in ips:
        run(f"iptables -I INPUT -s {ip} -j DROP")
        run(f"iptables -I OUTPUT -d {ip} -j DROP")

    run(f"pkill -f {user}")

    if proto == "ssh":
        run("systemctl restart ssh")
        run("systemctl restart dropbear")
        run("systemctl restart ws")
    elif proto != "zivpn":
        run("systemctl restart xray")

    return ips

# ===============================
# CLEANERS
# ===============================
def clean_xray(user):
    data = load(XRAY)
    for i in data.get("inbounds", []):
        if "clients" in i.get("settings", {}):
            i["settings"]["clients"] = [
                c for c in i["settings"]["clients"]
                if c.get("email") != user and c.get("password") != user
            ]
    save(XRAY, data)

def clean_zivpn(user):
    if os.path.exists(ZIV_DB):
        lines = open(ZIV_DB).readlines()
        open(ZIV_DB, "w").writelines([l for l in lines if not l.startswith(user + ":")])

    if os.path.exists(ZIV_CFG):
        data = load(ZIV_CFG)
        if "auth" in data:
            data["auth"]["config"] = [x for x in data["auth"]["config"] if x != user]
            save(ZIV_CFG, data)

def clean_ssh(user):
    run(f"userdel -r {user}")

# ===============================
# MAIN
# ===============================
deleted = []

for proto, path in FILES.items():
    data = load(path)
    new = []

    for u in data:
        exp = parse(u.get("expired", ""))
        user = u.get("username") or u.get("password")
        limit = int(u.get("limit_ip", 0))

        # ===== EXPIRED
        if exp and exp < now():
            force_dc(user, proto)

            if proto == "zivpn":
                clean_zivpn(user)
            elif proto == "ssh":
                clean_ssh(user)
            else:
                clean_xray(user)

            deleted.append(f"{user} ({proto})")
            continue

        # ===== MULTI LOGIN (SKIP ZIVPN)
        if proto != "zivpn":
            ips = get_ips(user)

            if limit > 0 and len(ips) > limit:
                force_dc(user, proto)

                if proto == "ssh":
                    clean_ssh(user)
                else:
                    clean_xray(user)

                deleted.append(f"{user} ({proto}) [MULTI {len(ips)}/{limit}]")
                continue

        new.append(u)

    save(path, new)

# ===============================
# NOTIF
# ===============================
if deleted:
    msg = "<b>🔥 TRIAL GUARD</b>\n━━━━━━━━━━━━━━\n\n"
    for x in deleted:
        msg += f"• <code>{x}</code>\n"
    msg += "\n━━━━━━━━━━━━━━\n"
    msg += f"<b>Time :</b> <code>{datetime.now()}</code>"

    notif(msg)