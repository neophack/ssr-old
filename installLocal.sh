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

installBrewLibsodium(){
    #install homebrew then install lisodium on MacOS
    cp config-local.json.example config-local.json
    vi config-local.json
    python local.py -c config-local.json >/dev/null 2>&1&
    PID=$!

    #check proxy
    #proxyServer=$(grep '"server"' $Root/runtime/config.json | awk -F\" '{print $4}')
    #curlProxy=$(curl -x socks5://localhost:1080 myip.ipip.net  | grep -oE '([0-9]+\.){3}[0-9]+')

    export ALL_PROXY=socks5://localhost:1080
    if ! command -v brew;then
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi
    if ! brew list libsodium;then
        echo "Install libsodium"
        brew install libsodium
    fi
    kill -9 $PID
}
install(){
    check

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
    ln -sf $root/ssrp $DEST_BIN_DIR/ssrp

    case $(uname) in
        Linux)
            read -p "install ssrlocal service? [Y/n] " ser
            if [[ $ser != [nN] ]];then
                sed -e "s|ROOT|$root|g" -e "s|PYTHON|$(which python)|g" ssrlocal.service > /etc/systemd/system/ssrlocal.service
                systemctl daemon-reload
                systemctl enable ssrlocal
                systemctl start ssrlocal
            fi
            ;;
        Darwin)
            installBrewLibsodium
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
