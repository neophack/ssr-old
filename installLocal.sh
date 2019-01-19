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
    if ! command -v python >/dev/null 2>&1;then
        echo "Need python"
        exit 1
    fi
}

check

clean(){
    echo "Clean..."
    closeTmpProxy
    echo 'Clean Done'
}

usage(){
    cat<<-EOF
	Usage: $(basename $0) CMD
	CMD:
	    full        full install
	                (including: libsodium,brew(Mac only),coreutils(Mac only),service file,soft link)

	    mini        minimal install
	                (including: libsodium,service file,soft link)

	    coreutils   install coreutils
	                (including: realpath)

	    uninstall
	EOF
    exit 1
}

function installLibsodium(){
    echo "installLibsodium()"
    sodiumver=1.0.16
    cd "$root"
    if ! ls /usr/local/lib/libsodium* >/dev/null 2>&1;then
        cp libsodium-${sodiumver}.tar.gz /tmp
        cd /tmp
        tar xf libsodium-${sodiumver}.tar.gz && cd libsodium-${sodiumver}
        ./configure && make -j2 && sudo make install
        if [ "$(uname)" == "Linux" ];then
            sudo sh -c 'echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf'
            sudo ldconfig
            cmds=$(cat<<-EOF
			sh -c 'echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf'
			ldconfig
			EOF
)
            sudo sh -c "$cmds"
        fi
    fi
}
function config(){
    echo "config()"
    cd "$root"
    count=0
    if [ ! -e config-local.json ];then
        cp config-local.json.example config-local.json
    fi
    if [[ "$uname" == Linux ]];then
        vi config-local.json
        return 0
    fi
    while true;do
        vi config-local.json
        localPort="$(grep '\"local_port\"' config-local.json | grep -o '[0-9]\+')"
        if [ -z "$localPort" ];then
            echo "local_port is null"
            continue
        fi
        python local.py -c config-local.json >/tmp/tmpProxy.log 2>&1 &
        PID=$!
        curl -m 5 -x socks5://localhost:$localPort google.com >/dev/null 2>&1
        if curl -m 20 -x socks5://localhost:$localPort google.com ;then
            echo "proxy is working."
            break
        else
            count=$((count+1))
            if (($count==3));then
                echo "proxy not work,skip..."
                break
            fi
            echo "proxy not work,config again..."
            kill -9 $PID >/dev/null 2>&1
        fi
    done
}

#for install homebrew related
function tmpProxy(){
    echo "tmpProxy()"
    cd "$root"
    export ALL_PROXY=socks5://localhost:$localPort
    export all_proxy=socks5://localhost:$localPort
    export HTTP_PROXY=socks5://localhost:$localPort
    export http_proxy=socks5://localhost:$localPort
    git config --global http.proxy socks5://localhost:$localPort
    git config --global https.proxy socks5://localhost:$localPort
}

function closeTmpProxy(){
    echo "closeTmpProxy()"
    cd "$root"
    if [ -n "$PID" ];then
        kill -9 $PID >/dev/null 2>&1
        PID=
    fi
    unset ALL_PROXY
    unset all_proxy
    unset HTTP_PROXY
    unset http_proxy
    git config --global --unset-all http.proxy
    git config --global --unset-all https.proxy
}

function installBrew(){
    if [ "$(uname)" != "Darwin" ];then
        return
    fi
    echo "installBrew()"
    cd "$root"
    tmpProxy
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
        return 1
    fi
    if ! brew list coreutils >/dev/null 2>&1;then
        echo "install coreutils"
        brew install coreutils
    fi
}

function installService(){
    echo "installService()"
    cd "$root"
    case $(uname) in
        Linux)
            cmds=$(cat<<-EOF
			sed -e "s|ROOT|$root|g" -e "s|PYTHON|$(which python)|g" ssrlocal.service > /etc/systemd/system/ssrlocal.service
			systemctl daemon-reload
			systemctl enable ssrlocal
			systemctl start ssrlocal
			EOF
)
            sudo sh -c "$cmds"
            ;;
        Darwin)
            if [ ! -d $home/Library/LaunchAgents ];then
                mkdir -p $home/Library/LaunchAgents
            fi
            sed -e "s|ROOT|$root|g" ssrlocal.plist > $home/Library/LaunchAgents/ssrlocal.plist
            ;;
    esac

}

function installSoftLink(){
    echo "installSoftLink()"
    cd "$root"
    cmds=$(cat<<-EOF
		ln -sf $root/ssrlocal $DEST_BIN_DIR/ssrlocal
		ln -sf $root/ssrp $DEST_BIN_DIR/ssrp
		EOF
)
    sudo sh -c "$cmds"
}

uninstall(){
    echo "uninstall()"
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
    full)
        actions=(installLibsodium config installBrew installService installSoftLink)
        ;;
    uninstall)
        actions=(uninstall)
        ;;
    mini)
        actions=(installLibsodium config installService installSoftLink)
        ;;
    coreutils)
        actions=(installLibsodium config installBrew)
        ;;
    *)
        usage
        ;;
esac

trap clean EXIT
for action in "${actions[@]}";do
    $action
done
