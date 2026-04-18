# Konfigurasi Port Tunneling — FIXED

## Arsitektur Baru

```
[Client]
    │
    ├─ Port 80/8080/8880/2082 (HTTP/WS)
    │       └─► HAProxy (http_ws frontend)
    │               ├─ WebSocket → Nginx port 8001 → Xray inbounds
    │               └─ Non-WS   → Dropbear SSH port 109
    │
    └─ Port 443/8443/2083 (TLS/SSL)
            └─► HAProxy (https_tls frontend)
                    └─ Semua TLS → Nginx port 8002 (SSL termination oleh Nginx)
                            ├─ /vless       → Xray port 10001 (VLess WS)
                            ├─ /vmess       → Xray port 10002 (VMess WS)
                            ├─ /trojan-ws   → Xray port 10003 (Trojan WS)
                            ├─ /ssh         → ws.py port 10015 → SSH port 109
                            ├─ /xhttp       → Xray port 10009 (VLess XHTTP)
                            ├─ /vless-grpc  → Xray port 10005 (VLess gRPC)
                            ├─ /vmess-grpc  → Xray port 10006 (VMess gRPC)
                            └─ /trojan-grpc → Xray port 10007 (Trojan gRPC)
```

## Ringkasan Port

| Protokol      | Transport | Port Publik              | Port Internal |
|---------------|-----------|--------------------------|---------------|
| SSH           | WS        | 80, 8080, 8880, 2082     | 10015 → 109   |
| SSH           | TLS/WS    | 443, 8443, 2083 (/ssh)   | 10015 → 109   |
| VMess         | WS        | 80, 8080, 8880, 2082     | 10002         |
| VMess         | TLS/WS    | 443, 8443, 2083 (/vmess) | 10002         |
| VMess         | gRPC      | 443, 8443, 2083          | 10006         |
| VLess         | WS        | 80, 8080, 8880, 2082     | 10001         |
| VLess         | TLS/WS    | 443, 8443, 2083 (/vless) | 10001         |
| VLess         | gRPC      | 443, 8443, 2083          | 10005         |
| VLess         | XHTTP     | 443, 8443, 2083 (/xhttp) | 10009         |
| Trojan        | WS        | 80, 8080, 8880, 2082     | 10003         |
| Trojan        | TLS/WS    | 443, 8443, 2083          | 10003         |
| Trojan        | gRPC      | 443, 8443, 2083          | 10007         |

## Perbaikan yang Dilakukan

### 1. haproxy.cfg
- **DIPERBAIKI:** Frontend TLS sekarang bind `*:443`, `*:8443`, `*:2083` (sebelumnya hanya 2083)
- **DIPERBAIKI:** Backend `xray_ws` yang mengarah ke port 10000 (tidak ada) diganti dengan `nginx_http` → `127.0.0.1:8001`
- **DIPERBAIKI:** Ditambah backend `nginx_https` → `127.0.0.1:8002` untuk TLS
- **DIPERBAIKI:** Tidak ada lagi konflik port 443 dengan Nginx

### 2. xray.conf (Nginx virtual host)
- **DIPERBAIKI:** Nginx dipindah dari `listen 443 ssl` ke port internal:
  - `listen 8001` — untuk HTTP WS (dari port 80/8080/8880/2082 via HAProxy)
  - `listen 8002 ssl http2` — untuk HTTPS/gRPC/XHTTP (dari port 443/8443/2083 via HAProxy)
- **DITAMBAH:** gRPC headers (`grpc_set_header`)
- **DITAMBAH:** location `/ssh` di block HTTP (8001) juga

### 3. nginx.conf
- Tidak ada perubahan signifikan, sudah benar
- Comment diperbarui untuk kejelasan

### 4. config.json (Xray)
- **TIDAK ADA PERUBAHAN** pada inbound protokol utama (sudah benar)
- Tag `ssh-ws` pada inbound 10015 diperbarui (sebelumnya tidak ada tag yang jelas)

### 5. dropbear.conf
- Tidak ada perubahan, sudah benar (port 109 dan 143)

### 6. ws.py
- Ditambah fungsi `main()` yang lebih informatif
- Diperbaiki handling untuk port yang tidak valid
- Logic inti tidak berubah

### 7. dirmeluna.sh
- Diperbarui untuk menyalin ws.py lokal daripada download dari GitHub
- Ditambah `RestartSec=3s` untuk service recovery lebih cepat
- Ditambah status check di akhir script

## Cara Deploy ke VPS

```bash
# 1. Copy semua file ke VPS
scp -r fixed_tunneling/ root@IP_VPS:/tmp/

# 2. Di VPS:
cd /tmp/fixed_tunneling

# 3. Copy konfigurasi
cp haproxy.cfg /etc/haproxy/haproxy.cfg
cp nginx.conf /etc/nginx/nginx.conf
cp xray.conf /etc/nginx/conf.d/xray.conf
cp config.json /usr/local/etc/xray/config.json
cp dropbear.conf /etc/default/dropbear

# 4. Install ws.py dan buat systemd service
bash dirmeluna.sh

# 5. Restart semua service
systemctl restart haproxy
systemctl restart nginx
systemctl restart xray
systemctl restart dropbear

# 6. Cek status
systemctl status haproxy
systemctl status nginx
systemctl status xray
```

## Catatan Penting

- SSL Certificate untuk Nginx: `/etc/xray/xray.crt` dan `/etc/xray/xray.key`
- SSL Certificate untuk HAProxy (opsional): `/etc/haproxy/hap.pem` (tidak lagi dipakai oleh HAProxy karena Nginx yang handle SSL)
- HAProxy di versi baru ini hanya melakukan **TCP passthrough** ke Nginx, sehingga Nginx yang handle SSL termination
