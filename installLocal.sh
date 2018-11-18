#!/bin/bash
root="$(cd $(dirname $BASH_SOURCE) && pwd)"
cd "$root"

if (($EUID!=0));then
    echo "Need run as root"
    exit 1
fi

if ! command -v tmux >/dev/null 2>&1;then
    if command -v apt-get >/dev/null 2>&1;then
        apt-get install -y tmux
    elif command -v yum >/dev/null 2>&1;then
        yum install -y tmux
    elif command -v pacman >/dev/null 2>&1;then
        pacman -S tmux --noconfirm
    elif command -v brew >/dev/null 2>&1;then
        brew install tmux
    fi
fi

if ! command -v tmux >/dev/null 2>&1;then
    echo "need tmux"
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
