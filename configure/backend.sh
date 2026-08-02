#!/bin/bash

clear

cat > /etc/nginx/conf.d/xray.conf <<'EOF'
# ============================================================
  # Nginx internal — dipanggil oleh HAProxy
  # Port 8001 : HTTP  (dari HAProxy port 80/8080/8880/2082)
  # Port 8002 : HTTPS (dari HAProxy port 443/8443/2083)
  #
  # ALUR SSH WebSocket:
  #   Port 80/443 → HAProxy → Nginx 8001/8002 → ws.py:10015 → Dropbear:109
  #   SSH TIDAK masuk Xray (config.json) — hanya lewat Nginx → ws.py
  # ============================================================

  server {
      listen 8001;
      server_name _;
      # Cloudflare IP ranges
      set_real_ip_from 103.21.244.0/22;
      set_real_ip_from 103.22.200.0/22;
      set_real_ip_from 103.31.4.0/22;
      set_real_ip_from 104.16.0.0/13;
      set_real_ip_from 104.24.0.0/14;
      set_real_ip_from 108.162.192.0/18;
      set_real_ip_from 131.0.72.0/22;
      set_real_ip_from 141.101.64.0/18;
      set_real_ip_from 162.158.0.0/15;
      set_real_ip_from 172.64.0.0/13;
      set_real_ip_from 173.245.48.0/20;
      set_real_ip_from 188.114.96.0/20;
      set_real_ip_from 190.93.240.0/20;
      set_real_ip_from 197.234.240.0/22;
      set_real_ip_from 198.41.128.0/17;
      real_ip_header CF-Connecting-IP;
      real_ip_recursive on;

      # ================= VMess WS =================
      location /vmess {
          proxy_pass http://127.0.0.1:10002;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }

      # ================= VLess WS =================
      location /vless {
          proxy_pass http://127.0.0.1:10001;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }

      # ================= Trojan WS =================
      # Pastikan client setting: Security=None, Transport=WS, Path=/trojan-ws
      location /trojan-ws {
          proxy_pass http://127.0.0.1:10003;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }

      # ================= SSH WS (path eksplisit) =================
      # ws.py listen :10015 → Dropbear:109
      # Client SSH app set path = /ssh
      location /ssh {
          proxy_pass http://127.0.0.1:10015;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }

      # ================= Root / : SSH WS fallback (semua inject path) =================
      # Semua request ke / diteruskan ke ws.py — WS dan non-WS
      # inject tool: connect, kirim payload HTTP, terima 101, lanjut SSH
      # ws.py handle WS upgrade, HTTP CONNECT, dan raw inject dengan benar
      location / {
          proxy_pass http://127.0.0.1:10015;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }
  }

  server {
      listen 8002 ssl http2;
      server_name _;
      # Cloudflare IP ranges
      set_real_ip_from 103.21.244.0/22;
      set_real_ip_from 103.22.200.0/22;
      set_real_ip_from 103.31.4.0/22;
      set_real_ip_from 104.16.0.0/13;
      set_real_ip_from 104.24.0.0/14;
      set_real_ip_from 108.162.192.0/18;
      set_real_ip_from 131.0.72.0/22;
      set_real_ip_from 141.101.64.0/18;
      set_real_ip_from 162.158.0.0/15;
      set_real_ip_from 172.64.0.0/13;
      set_real_ip_from 173.245.48.0/20;
      set_real_ip_from 188.114.96.0/20;
      set_real_ip_from 190.93.240.0/20;
      set_real_ip_from 197.234.240.0/22;
      set_real_ip_from 198.41.128.0/17;
      real_ip_header CF-Connecting-IP;
      real_ip_recursive on;

      ssl_certificate     /etc/xray/xray.crt;
      ssl_certificate_key /etc/xray/xray.key;
      ssl_protocols       TLSv1.2 TLSv1.3;
      ssl_ciphers         HIGH:!aNULL:!MD5;
      ssl_session_cache   shared:SSL:10m;
      ssl_session_timeout 10m;

      # ================= VMess WS + TLS =================
      location /vmess {
          proxy_pass http://127.0.0.1:10002;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }

      # ================= VLess WS + TLS =================
      location /vless {
          proxy_pass http://127.0.0.1:10001;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }

      # ================= Trojan WS + TLS =================
      location /trojan-ws {
          proxy_pass http://127.0.0.1:10003;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }

      # ================= SSH WS + TLS (path eksplisit) =================
      # ws.py listen :10015 → Dropbear:109
      location /ssh {
          proxy_pass http://127.0.0.1:10015;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }

      # ================= VLess XHTTP =================
      location /xhttp {
          proxy_pass http://127.0.0.1:10009;
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header Connection "";
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
      }

      # ================= VLess gRPC =================
      location /vless-grpc {
          grpc_pass grpc://127.0.0.1:10005;
          grpc_set_header Host $host;
          grpc_set_header X-Real-IP $remote_addr;
      }

      # ================= VMess gRPC =================
      location /vmess-grpc {
          grpc_pass grpc://127.0.0.1:10006;
          grpc_set_header Host $host;
          grpc_set_header X-Real-IP $remote_addr;
      }

      # ================= Trojan gRPC =================
      location /trojan-grpc {
          grpc_pass grpc://127.0.0.1:10007;
          grpc_set_header Host $host;
          grpc_set_header X-Real-IP $remote_addr;
      }

      # ================= Root / : SSH WS TLS fallback (semua inject path) =================
      # Sama seperti HTTP — ws.py handle semua jenis koneksi inject + WS
      location / {
          proxy_pass http://127.0.0.1:10015;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
      }
  }
EOF

cat > /etc/haproxy/haproxy.cfg <<'EOF'
global
      daemon
      tune.ssl.default-dh-param 2048
      log /dev/log local0

  defaults
      mode tcp
      option dontlognull
      option tcp-smart-accept
      option tcp-smart-connect
      timeout connect 30s
      timeout client 300s
      timeout server 300s

  # =================================================================
  # HTTP FRONTEND — Port 80, 8080, 8880, 2082
  # VMess-WS, VLess-WS, Trojan-WS, SSH-WS
  # Forward semua ke Nginx:8001 — routing by path di Nginx
  # =================================================================
  frontend http_ws
      bind *:80
      bind *:8080
      bind *:8880
      bind *:2082
      mode tcp
      default_backend nginx_http

  # =================================================================
  # TLS FRONTEND — Port 443, 8443, 2083
  # VMess-TLS, VLess-TLS, Trojan-TLS, gRPC, XHTTP, SSH-WS-TLS
  # Forward raw TCP ke Nginx:8002 — Nginx handle SSL
  # TIDAK pakai inspect-delay — langsung forward agar SSH TLS tidak kena timeout drop
  # =================================================================
  frontend https_tls
      bind *:443
      bind *:8443
      bind *:2083
      mode tcp
      default_backend nginx_https

  # =================================================================
  # BACKENDS
  # =================================================================
  backend nginx_http
      mode tcp
      server nginx_http 127.0.0.1:8001

  backend nginx_https
      mode tcp
      server nginx_https 127.0.0.1:8002
EOF

systemctl daemon-reload
systemctl restart xray
systemctl restart nginx
systemctl restart haproxy