#!/bin/bash

echo "=== INSTALL DROPBEAR 2019.78 ==="
apt purge -y dropbear
rm -f /usr/sbin/dropbear
# STOP DROPBEAR LAMA
systemctl stop dropbear 2>/dev/null
apt remove -y dropbear 2>/dev/null

# DEPENDENCY
apt update -y
apt install -y build-essential zlib1g-dev

# DOWNLOAD SOURCE
cd /usr/local/src
rm -rf dropbear-2019.78*
wget https://matt.ucc.asn.au/dropbear/releases/dropbear-2019.78.tar.bz2
tar -xjf dropbear-2019.78.tar.bz2
cd dropbear-2019.78

# BUILD
./configure
make -j$(nproc)
make install

# HOSTKEY
mkdir -p /etc/dropbear
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key

# SERVICE
cat > /etc/systemd/system/dropbear.service <<EOL
[Unit]
Description=Dropbear SSH Server (2019)
After=network.target

[Service]
ExecStart=/usr/local/sbin/dropbear -EF -p 109 -p 143 -W 65536 -I 60 -b /etc/banner.txt
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# ENABLE
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable dropbear
systemctl restart dropbear

# CHECK
sleep 1
echo ""
echo "=== STATUS ==="
systemctl status dropbear --no-pager -l

echo ""
echo "=== PORT ==="
ss -tulpn | grep dropbear

echo ""
echo "=== VERSION ==="
/usr/local/sbin/dropbear -V

echo ""
echo "=== DONE ==="


ln -s /usr/local/sbin/dropbear /usr/sbin/dropbear
