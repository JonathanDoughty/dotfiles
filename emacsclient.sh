#!/usr/bin/env bash
# bash-emacs - helpers for command line interaction with *the* editor

function emc {
    # This assumes that the user's init sequence includes (server-start)
    local SOC # path to Emacs' server socket

    function _emc_start_emacs () {
        # If server's socket can't be found then start Emacs
        SOC=$(_emc_find_emacs_socket)
        if [ ! -e "$SOC" ]; then
            case ${OSTYPE} in
                (darwin*)
                    osascript -e "tell application \"Emacs\" to activate"
                    ;;
                (linux*)
                    emacs --daemon
                    ;;
            esac
        fi
    }

    function _emc_find_emacs_socket () {
        # Find the socket that Emacs server will have started
        SOC=""
        case ${OSTYPE} in
            (darwin*)
                # $APP won't work for EmacsForMacOS
                # Sigh: we have to ignore errors that might come from mounted Time Machine volumes
                SOC=$(lsof -w -c Emacs | grep 'server$' | awk '{print $(NF) }')
                ;;
            (linux*)
                SOC=$(lsof -c emacs | grep 'server$' | awk '{print $(NF) }') # untested
                ;;
        esac
        printf "%s" "$SOC"
    }

    function _emc_wait_for_server_response () {
        declare -i TIMER=1
        while [[ ! -e "$SOC" ]]; do
            # Look for whatever socket Emacs has open
            SOC=$(_emc_find_emacs_socket)
            if [[ -z "$SOC" ]]; then
                printf "Waiting %d seconds for Emacs to create server socket\n" "$TIMER"
                sleep $TIMER
                (( TIMER+=1 ))
            else
                break
            fi
        done

        # Insure client gets response from server
        TIMER=1
        while ! "$CLIENT" -q -s "$SOC" -e t &>/dev/null ; do
            printf "Waiting %d seconds for server response\n" "$TIMER"
            sleep $TIMER
            (( TIMER+=1 ))
        done
    }

    function _emc_find_client () {
        # Find the emacsclient associated with the running Emacs
        local EPATH="" process client=""
        case ${OSTYPE} in
            (darwin*)
                process="Emacs"
                ;;
            (linux*)
                process="emacs"
                ;;
        esac
        # Within Emacs shell, on macOS, pgrep doesn't find the Emacs process
        # Possibly https://unix.stackexchange.com/a/100759/13887 ?
        #EPATH=$(ps -fp $(pgrep "$process") | tail -1 | awk '{print $NF}')
        # alternately, unchecked on Linux
        #EPATH=$(killall -s "$process") | awk '{print $NF}')
        # shellcheck disable=SC2009
        EPATH=$(ps aux | grep $process | grep -v grep | awk '{print $NF}')
        # Traverse filesystem hierarchy looking for client
        while [[ "${EPATH%/*}" != "" && "$client" == "" ]]; do
            client="$(find "${EPATH%/*}" -name emacsclient)"
            EPATH="${EPATH%/*}"
        done
        echo "$client"
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

    _emc_start_emacs

    local CLIENT
    CLIENT=$(_emc_find_client)
    if [ -n "$CLIENT" ]; then
        _emc_wait_for_server_response

        # shellcheck disable=SC2068 # Send each array element as separate argument
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
