#!/usr/bin/env bash
# bash-emacs - helpers for command line interaction with *the* editor

# Guesses at path for emacsclient unless EMACSCLIENT_PATH has been set

if [ -n "$ZSH_VERSION" ]; then emulate -L ksh; fi

function emc {

    function _find_emacs_socket () {
        case ${OSTYPE} in
            (darwin*)
                lsof -c Emacs | grep 'server$' | awk '{print $(NF) }'
                ;;
            (linux*)
                lsof -c emacs | grep 'server$' | awk '{print $(NF) }' # untested
                ;;
        esac
    }
    
    local SOC
    SOC=$(_find_emacs_socket)
    local CLIENT

    if [ ! -e "$SOC" ]; then
        case ${OSTYPE} in 
            (darwin*)
                osascript -e 'tell application "Emacs" to activate'
                ;;
            (linux*)
                emacs --daemon
                ;;
        esac
    fi

    # Places where emacslient has been known to live
    declare -a paths
    if [[ -n "$EMACSCLIENT_PATH" && -e "$EMACSCLIENT_PATH" ]]; then
        # Add user specified path as first in array
        paths+=("$EMACSCLIENT_PATH")
    fi
    paths+=("/Applications/Emacs.app/Contents/MacOS/bin/emacsclient")
    paths+=("${HOME}/Applications/Emacs.app/Contents/MacOS/bin/emacsclient")
    paths+=("${HOME}/Applications/EmacsMacPort.app/Contents/MacOS/bin/emacsclient")
    paths+=("/usr/local/bin/emacsclient")
    paths+=("/usr/bin/emacsclient")
    paths+=(/"snap/bin/emacsclient")  # Ubuntu via snap
    local c
    for c in "${paths[@]}"; do
        if [[ -e "$c" ]]; then
            CLIENT="$c"
            break
        fi
    done

    #trap "set +x" RETURN && set -x
    if [ -n "$CLIENT" ]; then
        while [[ ! -e "$SOC" ]]; do
            # Look for whatever socket Emacs has open
            SOC=$(_find_emacs_socket)
            if [[ -z "$SOC" ]]; then
                printf "Waiting for Emacs to create server socket\n"
                sleep 1
            else
                break
            fi
        done
        
        while ! "$CLIENT" -q -s "$SOC" -e t &>/dev/null ; do
            printf "Waiting for server-start\n"
            sleep 1
        done
        # shellcheck disable=SC2068 # I want to send each array element
        "$CLIENT" -s "$SOC" -n -a \"\" $@
    else
        printf "Can't find emacsclient to open %s\n" "$@"
    fi
}

function emr {
    # Open files read-only
    emc -e "(view-file \"$*\")"
}

# Any arguments? Then invoke emacsclient with them
if [[ ${#@} -gt 1 ]]; then
    emc "$@"
fi
