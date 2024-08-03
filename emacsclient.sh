#!/usr/bin/env bash
# bash-emacs - helpers for command line interaction with *the* editor

# Guesses at path for emacsclient unless EMACSCLIENT_PATH has been set

function emc {

    function _find_emacs_socket () {
        case ${OSTYPE} in
            (darwin*)
                # $APP won't work for EmacsForMacOS
                # Sigh: we have to ignore errors that might come from mounted Time Machine volumes
                lsof -w -c Emacs | grep 'server$' | awk '{print $(NF) }'
                ;;
            (linux*)
                lsof -c emacs | grep 'server$' | awk '{print $(NF) }' # untested
                ;;
        esac
    }
    
    local -i VERBOSE
    OPTIND=1                    # needed for subsequent function getopts
    while getopts "v" flag "$@"; do
        if [ "$flag" == "v" ]; then
            VERBOSE+=1
        fi
    done
    shift "$((OPTIND - 1))"

    if [[ "${VERBOSE}" -gt 0 && -z "$ZSH_VERSION" ]]; then
        set -x && trap "set +x" RETURN EXIT
    fi
    
    # Find emacslient and emacs app in places where they has been seen
    declare -a paths
    if [[ -n "$EMACSCLIENT_PATH" && -e "$EMACSCLIENT_PATH" ]]; then
        # Add user specified path as first in array
        paths+=("$EMACSCLIENT_PATH")
    fi
    paths+=("${HOME}/Applications/EmacsForMacOS.app/Contents/MacOS/bin/emacsclient");
    paths+=("${HOME}/Applications/Emacs.app/Contents/MacOS/bin/emacsclient");
    paths+=("/Applications/Emacs.app/Contents/MacOS/bin/emacsclient");
    paths+=(/"snap/bin/emacsclient")  # Ubuntu via snap
    paths+=("/usr/local/bin/emacsclient")
    paths+=("/usr/bin/emacsclient")

    # Which client and app? Order above matters.
    local CLIENT APP c
    for c in "${paths[@]}"; do
        if [[ -e "$c" ]]; then
            CLIENT="$c"
            if [[ "${CLIENT%%.app*}" != "${CLIENT}" ]]; then
                # Extract app name from client path
                APP="${CLIENT%%.app*}"
                APP="${APP##*/}"
                [[ "$VERBOSE" -gt 0 ]] && \
                    printf "Using app %s\nand client %s\n" "$APP" "$CLIENT"
            fi
            break
        fi
    done

    local SOC
    SOC=$(_find_emacs_socket)
    if [ ! -e "$SOC" ]; then
        case ${OSTYPE} in 
            (darwin*)
                osascript -e "tell application \"$APP\" to activate"
                ;;
            (linux*)
                emacs --daemon
                ;;
        esac
    fi

    declare -i TIMER=1
    if [ -n "$CLIENT" ]; then
        while [[ ! -e "$SOC" ]]; do
            # Look for whatever socket Emacs has open
            SOC=$(_find_emacs_socket)
            if [[ -z "$SOC" ]]; then
                printf "Waiting %d seconds for Emacs to create server socket\n" "$TIMER"
                sleep $TIMER
                (( TIMER+=1 ))
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
