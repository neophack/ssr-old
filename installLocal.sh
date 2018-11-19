#!/bin/bash
root="$(cd $(dirname $BASH_SOURCE) && pwd)"
cd "$root"

user=${SUDO_USER:-$(whoami)}
home=$(eval echo ~$user)

DEST_BIN_DIR=/usr/local/bin
check(){
    if (($EUID!=0));then
        echo "Need run as root"
        exit 1
    fi
}

usage(){
    cat<<-EOF
	Usage: $(basename $0) CMD
	CMD:
	    install
	    uninstall
	EOF
    exit 1
}

install(){
    check
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

    if ! command -v python >/dev/null 2>&1;then
        if command -v apt-get >/dev/null 2>&1;then
            apt-get install -y python
        elif command -v yum >/dev/null 2>&1;then
            yum install -y python
        elif command -v pacman >/dev/null 2>&1;then
            pacman -S python --noconfirm
        elif command -v brew >/dev/null 2>&1;then
            brew install python
        fi
    fi

    if ! command -v python >/dev/null 2>&1;then
        echo "need python"
        exit 1
    fi

    echo "install libsodium..."
    bash libsodium.sh

    # sed "s|ROOT|$root|g" ssrlocal >$DEST_BIN_DIR/ssrlocal
    # chmod +x $DEST_BIN_DIR/ssrlocal
    ln -sf $root/ssrlocal $DEST_BIN_DIR/ssrlocal

    case $(uname) in
        Linux)
            read -p "install ssrlocal service? [Y/n] " ser
            if [[ $ser != [nN] ]];then
                sed -e "s|ROOT|$root|g" ssrlocal.service > /etc/systemd/system/ssrlocal.service
                systemctl daemon-reload
                systemctl enable ssrlocal
                systemctl start ssrlocal
            fi
            ;;
        Darwin)
            read -p "install ssrlocal plist? [Y/n] " ser
            if [[ "$ser" != [nN] ]];then
                sed -e "s|ROOT|$root|g" ssrlocal.plist > $home/Library/LaunchAgents/ssrlocal.plist
            fi
            ;;
    esac
}

uninstall(){
    check
    rm $DEST_BIN_DIR/ssrlocal
    case $(uname) in
        Linux)
            systemctl stop ssrlocal
            systemctl disable ssrlocal
            rm /etc/systemd/system/ssrlocal.service
            ;;
        Darwin)
            launchctl unload $home/Library/LaunchAgents/ssrlocal.plist
            rm $home/Library/LaunchAgents/ssrlocal.plist
            ;;
    esac
}

cmd=$1

case $cmd in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        usage
        ;;
esac
