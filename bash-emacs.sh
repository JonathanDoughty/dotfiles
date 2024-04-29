#!/usr/bin/env bash
# bash-emacs - helpers for command line interaction with *the* editor

# Guesses at path for emacsclient unless EMACSCLIENT_PATH has been set

if [ -n "$ZSH_VERSION" ]; then emulate -L ksh; fi

function emc {
    # As suggested by https://www.emacswiki.org/emacs/EmacsClient#h5o-28
    # back in the day, specify a non-standard socket location
    local SOC="/tmp/emacs_socket_for_${LOGNAME}/server"
    # Note that this also requires
    # (setq server-socket-dir (format "/tmp/emacs_socket_for_%s" (user-login-name)))
    # prior to (server-start)
    local CLIENT

    if [ ! -e "$SOC" ]; then
        case ${OSTYPE} in # though there is no no current dependence on OS version
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

    if [ -n "$CLIENT" ]; then
        if [ ! -e "$SOC" ]; then
            while ! "$CLIENT" -q -s "$SOC" -e t 2>/dev/null ; do
                printf "Waiting for server-start\n"
                sleep 1
            done
        fi
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
