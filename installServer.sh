#!/bin/bash
root="$(cd $(dirname $BASH_SOURCE) && pwd)"
cd "$root"

if (($EUID!=0));then
    echo "Need run as root"
    exit 1
fi

sed "s|ROOT|$root|g" ssrserver >/usr/local/bin/ssrserver
chmod +x /usr/local/bin/ssrserver
