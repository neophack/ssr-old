#!/bin/bash
root="$(cd $(dirname $BASH_SOURCE) && pwd)"
cd "$root"

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

    if !command -v tmux >/dev/null 2>&1;then
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
    sed "s|ROOT|$root|g" ssrserver >$DEST_BIN_DIR/ssrserver
    chmod +x $DEST_BIN_DIR/ssrserver

    sed -e "s|ROOT|$root|g" -e "s|PYTHON|$(which python)|g" ssrserver.service > /etc/systemd/system/ssrserver.service
    systemctl enable ssrserver
    echo "install libsodium..."
    bash libsodium.sh
    echo "use ssrserver config to config ssrserver,then issue systemctl start ssrserver"
}

uninstall(){
    check
    rm $DEST_BIN_DIR/ssrserver
    systemctl stop ssrserver
    systemctl disable ssrserver
    rm /etc/systemd/system/ssrserver.service
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
