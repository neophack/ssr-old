#!/bin/bash
root="$(cd $(dirname $BASH_SOURCE) && pwd)"
cd "$root"

user=${SUDO_USER:-$(whoami)}
home=$(eval echo ~$user)

DEST_BIN_DIR=/usr/local/bin
check(){
    if (($EUID==0));then
        echo "Dn't need run as root"
        exit 1
    fi
}

trap clean EXIT

clean(){
    echo "Clean..."
    kill -9 $PID >/dev/null 2>&1
    git config --global --unset-all http.proxy
    git config --global --unset-all https.proxy
    echo 'Clean Done'
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
    if ! ls /usr/local/lib/libsodium* >/dev/null 2>&1;then
        cp libsodium-1.0.16.tar.gz /tmp
        cd /tmp
        tar xf libsodium-1.0.16.tar.gz && cd libsodium-1.0.16
        ./configure && make -j2 && sudo make install
        cd "$root"
    fi
    #install homebrew then install lisodium on MacOS
    if [ ! -e config-local.json ];then
        cp config-local.json.example config-local.json
    fi
    while True;do
        vi config-local.json
        localPort="$(grep '\"local_port\"' config-local.json | grep -o '[0-9]\+')"
        if [ -z "$localPort" ];then
            echo "local_port is null"
            continue
        fi
        python local.py -c config-local.json >/tmp/installLocal-local.py.log 2>&1&
        PID=$!
        curl -m 5 -x socks5://localhost:$localPort google.com >/dev/null 2>&1
        if curl -m 20 -x socks5://localhost:$localPort google.com ;then
            break
        else
            echo "proxy not work,config again..."
            read aaa
            kill -9 $PID >/dev/null 2>&1
        fi

    done

    export ALL_PROXY=socks5://localhost:$localPort
    export all_proxy=socks5://localhost:$localPort
    export HTTP_PROXY=socks5://localhost:$localPort
    export http_proxy=socks5://localhost:$localPort
    git config --global http.proxy socks5://localhost:$localPort
    git config --global https.proxy socks5://localhost:$localPort
    if ! command -v brew >/dev/null 2>&1;then
        echo "Install homebrew..."
        /usr/bin/ruby -e "$(curl --max-time 60 -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi
    # if ! brew list libsodium >/dev/null 2>&1;then
    #     echo "Install libsodium"
    #     brew install libsodium
    # fi
    if ! command -v brew >/dev/null 2>&1;then
        echo "Install homebrew failed."
        exit 1
    fi
    if ! brew list coreutils >/dev/null 2>&1;then
        echo "install coreutils"
        brew install coreutils
    fi
}

install(){
    check

    if ! command -v python >/dev/null 2>&1;then
        echo "need python"
        exit 1
    fi

    case $(uname) in
        Linux)
            cmds=$(cat<<-EOF
			sed -e "s|ROOT|$root|g" -e "s|PYTHON|$(which python)|g" ssrlocal.service > /etc/systemd/system/ssrlocal.service
			systemctl daemon-reload
			systemctl enable ssrlocal
			systemctl start ssrlocal
			echo "run libsodium.sh to run libsodium if needed."
			ln -sf $root/ssrlocal $DEST_BIN_DIR/ssrlocal
			ln -sf $root/ssrp $DEST_BIN_DIR/ssrp
			EOF
)
            sudo sh -c "$cmds"
            ;;
        Darwin)
            installBrewLibsodium
            ln -sf $root/ssrlocal $DEST_BIN_DIR/ssrlocal
            ln -sf $root/ssrp $DEST_BIN_DIR/ssrp
            if [ ! -d $home/Library/LaunchAgents ];then
                mkdir -p $home/Library/LaunchAgents
            fi
            sed -e "s|ROOT|$root|g" ssrlocal.plist > $home/Library/LaunchAgents/ssrlocal.plist
            ;;
    esac
}

uninstall(){
    check
    case $(uname) in
        Linux)
            cmds=$(cat<<-EOF
			systemctl stop ssrlocal
			systemctl disable ssrlocal
			rm /etc/systemd/system/ssrlocal.service
			rm $DEST_BIN_DIR/ssrlocal
			EOF
)
            sudo sh -c "$cmds"
            ;;
        Darwin)
            launchctl unload $home/Library/LaunchAgents/ssrlocal.plist
            rm $home/Library/LaunchAgents/ssrlocal.plist
            rm $DEST_BIN_DIR/ssrlocal
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
