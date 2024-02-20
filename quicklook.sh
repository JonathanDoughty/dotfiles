#!/usr/bin/env bash
# QuickLook a file from command line, via
# http://hints.macworld.com/article.php?story=20100712090451517

[[ "$_" != "$0" ]] || { printf "%s must be sourced to be useful." "$0"; exit 1; }

function ql {
    qlmanage -p "$@" &>/dev/null &
    #local QL_PID="$!"

    #echo "Press any key"
    #read -s -n 1

    #kill $QL_PID
}

if [ $# ]; then
    ql "@"
fi
