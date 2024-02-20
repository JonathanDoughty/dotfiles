#!/usr/bin/env bash
# bash_office.sh - Office tool related functions

[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

function add_to_calendar {
    (
        cd ~/Downloads || return
        if [ -e owssvr.dll ]; then
            mv owssvr.{dll,ics} # Change extension to what Outlook will recognize
            open -a "Microsoft Outlook" owssvr.ics # Add to Outlook calendar
            if [[ $(type -f trash) ]]; then
                trash owssvr.ics
            else
                osascript -e "tell application \"Finder\" to delete POSIX file \"${PWD}/owssvr.ics\""
            fi
        fi
    )
}
