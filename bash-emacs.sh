#!/usr/bin/env bash
# bash-emacs - helpers for command line interaction with *the* editor

if [ -n "$ZSH_VERSION" ]; then emulate -L ksh; fi

function emc {
    # As suggested by http://emacsformacosx.com/tips
    local SOC="/tmp/emacs_socket_for_${LOGNAME}/server"
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

    # Places where emacslient lives; yakshave as a bash array / loop
    if [ -e ~/Applications/Emacs.app/Contents/MacOS/bin/emacsclient ]; then
        CLIENT=~/Applications/Emacs.app/Contents/MacOS/bin/emacsclient # My local application version
    elif [ -e /Applications/Emacs.app/Contents/MacOS/bin/emacsclient ]; then
        CLIENT=/Applications/Emacs.app/Contents/MacOS/bin/emacsclient # YAMAMOTO's native Mac version
    elif [ -e /usr/local/bin/emacsclient ]; then
        CLIENT=/usr/local/bin/emacsclient # Something I've installed
    elif [ -e /usr/bin/emacsclient ]; then
        CLIENT=/usr/bin/emacsclient # OS's emacs
    elif [ -e /snap/bin/emacsclient ]; then
        CLIENT=/snap/bin/emacsclient  # Ubuntu via snap
    fi

    if [ -n "$CLIENT" ]; then
        if [ ! -e "$SOC" ]; then
            while ! "$CLIENT" -q -s "$SOC" -e t 2>/dev/null ; do
                printf "Waiting for server-start\n"
                sleep 2
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

case ${0##*/} in
    (dash|-dash|bash|-bash|ksh|-ksh|sh|-sh|zsh|-zsh) ;; # being sourced to define functions only
    (*)
        # shellcheck disable=SC2068  # bare $@ is the point
        emc $@ ;; # this file executed as a script? pass arguments to the emacsclient wrapper
esac
