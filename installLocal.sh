#!/bin/bash
root="$(cd $(dirname $BASH_SOURCE) && pwd)"
cd "$root"

if (($EUID!=0));then
    echo "Need run as root"
    exit 1
fi

sed "s|ROOT|$root|g" ssrlocal >/usr/local/bin/ssrlocal
chmod +x /usr/local/bin/ssrlocal

case $(uname) in
    Linux)
        read -p "install ssrlocal service? [Y/n] " ser
        if [[ $ser != [nN] ]];then
            sed "s|ROOT|$root|g" ssrlocal.service > /etc/systemd/system/ssrlocal.service
            systemctl daemon-reload
            systemctl enable ssrlocal
            systemctl start ssrlocal
        fi
        ;;
esac
