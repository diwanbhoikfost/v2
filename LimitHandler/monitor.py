#!/usr/bin/env python3
import os, subprocess, time, json, requests
from pathlib import Path
from datetime import datetime

# ================= CONFIG =================
SERVICES = {
    "vmess": "/etc/lunatic/vmess",
    "vless": "/etc/lunatic/vless",
    "trojan": "/etc/lunatic/trojan",
    "ssh": "/etc/lunatic/ssh"
}

XRAY_LOG = "/var/log/xray/access.log"
XRAY_CONFIG = "/etc/xray/config.json"
TELEGRAM = "/etc/lunatic/telegram.json"

CHECK_INTERVAL = 3

# ================= UTIL =================
def run(cmd):
    subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def load_json(path):
    try: return json.load(open(path))
    except: return {}

# ================= TELEGRAM =================
def send(title, user, service, info="", ips=None):
    try:
        conf = load_json(TELEGRAM)
        key = conf.get("monitor", {}).get("bot_key")
        chat = conf.get("monitor", {}).get("chat_id")

        if not key or not chat:
            return

        ip_text = ""
        if ips:
            ip_text = "\n🌐 IP : " + ", ".join(ips)

        msg = f"""
<b>━━━━━━━━━━━━━━━━━━</b>
<b>{title}</b>
<b>━━━━━━━━━━━━━━━━━━</b>

👤 User    : <code>{user}</code>
📡 Service : <b>{service.upper()}</b>{ip_text}

💥 Action  : <b>KILLED + DELETED</b>
📊 Info    : <b>{info}</b>

⏰ Time    : {datetime.now().strftime('%d %b %Y %H:%M:%S')}
<b>━━━━━━━━━━━━━━━━━━</b>
"""
        requests.post(
            f"https://api.telegram.org/bot{key}/sendMessage",
            data={"chat_id": chat, "text": msg, "parse_mode": "HTML"},
            timeout=5
        )
    except:
        pass

# ================= XRAY USAGE QUOTA =================
def update_usage():
    try:
        stats = subprocess.check_output(
            ["xray","api","statsquery","--server=127.0.0.1:10085"],
            stderr=subprocess.DEVNULL
        ).decode()
    except:
        return

    for proto in ["vmess","vless","trojan"]:
        base = Path(f"/etc/lunatic/{proto}/quota")

        (base/"used").mkdir(parents=True, exist_ok=True)

        try:
            users = subprocess.check_output([
                "jq","-r",
                f'.inbounds[] | select(.protocol=="{proto}") | .settings.clients[]?.email',
                XRAY_CONFIG
            ]).decode().split()
        except:
            continue

        for user in set(users):
            try:
                up = subprocess.getoutput(f"echo '{stats}' | jq -r '.stat[] | select(.name==\"user>>>{user}>>>traffic>>>uplink\") | .value'")
                down = subprocess.getoutput(f"echo '{stats}' | jq -r '.stat[] | select(.name==\"user>>>{user}>>>traffic>>>downlink\") | .value'")

                up = int(up) if up.isdigit() else 0
                down = int(down) if down.isdigit() else 0

                total = up + down

                (base/"used"/user).write_text(str(total))

            except:
                continue

# ================= SSH DETECTION =================
def get_ssh_ips(user):
    ips = set()
    log = "/var/log/auth.log" if os.path.exists("/var/log/auth.log") else "/var/log/secure"

    if os.path.exists(log):
        data = subprocess.getoutput(
            f"tail -n 200 {log} | grep -E 'Accepted password|Accepted publickey' | grep {user}"
        )
        for line in data.splitlines():
            try:
                ip = line.split()[line.split().index("from")+1]
                ips.add(ip)
            except:
                pass

    return list(ips)

# ================= XRAY DETECTION =================
def get_xray_ips(user):
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

# ================= FORCE DC =================
def force_dc(user, service, ips):
    for ip in ips:
        run(f"iptables -I INPUT -s {ip} -j DROP")
        run(f"iptables -I OUTPUT -d {ip} -j DROP")

    run(f"pkill -9 -u {user}")
    run(f"pkill -9 -f {user}")

    if service == "ssh":
        run("systemctl restart ssh")
        run("systemctl restart sshd")
        run("systemctl restart dropbear")
        run("systemctl restart ws")
    else:
        run("systemctl restart xray")

    for ip in ips:
        run(f"iptables -D INPUT -s {ip} -j DROP")
        run(f"iptables -D OUTPUT -d {ip} -j DROP")

# ================= DELETE =================
def delete_user(user, service):
    base = SERVICES[service]

    if service == "ssh":
        run(f"userdel -r {user}")
    else:
        run(f"jq '(.inbounds[].settings.clients) |= map(select(.email != \"{user}\" and .password != \"{user}\"))' {XRAY_CONFIG} > /tmp/xray.json && mv /tmp/xray.json {XRAY_CONFIG}")

    for p in [
        f"{base}/ip/{user}",
        f"{base}/detail/{user}.txt",
        f"{base}/quota/usage/{user}",
        f"{base}/quota/used/{user}",
        f"{base}/quota/today/{user}",
        f"{base}/quota/last/{user}",
    ]:
        run(f"rm -f {p}")

# ================= CHECK =================
def check():
    for service, base in SERVICES.items():

        ip_dir = Path(f"{base}/ip")
        usage_dir = Path(f"{base}/quota/usage")
        used_dir = Path(f"{base}/quota/used")

        if not ip_dir.exists():
            continue

        for file in ip_dir.iterdir():
            user = file.name

            try:
                limit_ip = int(file.read_text())
            except:
                continue

            ips = get_ssh_ips(user) if service == "ssh" else get_xray_ips(user)

            # MULTI LOGIN
            if limit_ip > 0 and len(ips) > limit_ip:
                force_dc(user, service, ips)
                delete_user(user, service)
                send("🚨 MULTI LOGIN", user, service, f"{len(ips)}/{limit_ip}", ips)
                continue

            # QUOTA
            if usage_dir.exists() and (usage_dir/user).exists():
                try:
                    quota = int((usage_dir/user).read_text())
                    used = int((used_dir/user).read_text())
                except:
                    continue

                if quota > 0 and used >= quota:
                    force_dc(user, service, ips)
                    delete_user(user, service)
                    send("🔥 QUOTA EXCEEDED", user, service, f"{used}/{quota}", ips)

# ================= MAIN =================
if __name__ == "__main__":
    while True:
        update_usage()   # 🔥 INI KUNCI NYA
        check()
        time.sleep(CHECK_INTERVAL)