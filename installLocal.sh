#!/bin/bash
root="$(cd $(dirname $BASH_SOURCE) && pwd)"
cd "$root"

if (($EUID!=0));then
    echo "Need run as root"
    exit 1
fi

sed "s|ROOT|$root|g" ssrlocal >/usr/local/bin/ssrlocal
chmod +x /usr/local/bin/ssrlocal
