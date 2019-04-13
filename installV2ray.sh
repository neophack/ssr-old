#!/bin/bash

bash <(curl -L -s https://install.direct/go.sh)

cat<<EOF>/etc/v2ray/config.json
{
    "inbound": {
        "port": 8900,
        "protocol": "vmess",
        "settings": {
            "clients": [
                {
                    "alterId": 64,
                    "id": "e2791dbb-f340-4a71-998a-da3b184a1cef",
                    "level": 1
                }
            ]
        },
        "streamSettings": {
            "network": "ws"
        }
    },
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "outbound": {
        "protocol": "freedom",
        "settings": {}
    }
}
EOF
