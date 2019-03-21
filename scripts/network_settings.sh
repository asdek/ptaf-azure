#!/bin/bash

HOSTNAME=$1
LICENSE=$2

#delete azcesd if exists
if [ -n "$(apt-cache search azure-security)" ]; then
    apt-get purge -y azure-security
fi


WSC_MGMT_INTERFACE=eth0 WSC_WAN_INTERFACE=eth0 WSC_LAN_INTERFACE=eth1 \
/usr/local/bin/wsc -e <<EOF

host add 127.0.1.1 $HOSTNAME
hostname $HOSTNAME

if mode eth0 dhcp
if mode eth1 dhcp

if mark eth0
if mark eth1
if mark lo:0

feature set azure_byol true
integration_mode reverse_proxy

config commit
config sync

EOF

while netstat -lnt | awk '$4 ~ /:2812$/ {exit 1}';
    do sleep 10;
done

# One shot Activation
########################################################################
echo "USE_RSA_LOGIN = False" >> /opt/waf/conf/ui.config

/opt/waf/python/bin/python - <<EOF > /dev/null 2>&1
from hashlib import md5
from ui import app

with app.test_request_context():
    client = app.test_client()
    client.post('/login', data={'login': 'admin','password': '82082716189f80fd070b89ac716570ba','lang': 'en'})
    client.get("/license/get_config/?license_token=$LICENSE")
EOF

sed -i '$ d' /opt/waf/conf/ui.config
sed -i "s/^    ('en', 'English')/    ('en', 'English'),\n    ('ru', 'Russian'),/g" \
    /opt/waf/conf/static.ui.config

cp /opt/waf/static/licenses/PTAF_EULA-en.pdf /opt/waf/static/licenses/PTAF_EULA-ru.pdf

monit restart ui
