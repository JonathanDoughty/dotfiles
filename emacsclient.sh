#!/usr/bin/env bash
# emacsclient - helpers for command line interaction with *the* editor
# These also work in zsh.

function emc {
    # Because I frequently use different versions of Emacs I want to insure that the
    # emacsclient this uses is correctly paired with the running version.

    local SOC # path to Emacs' server socket

    function _emc_start_emacs () {
        # If server's socket can't be found then start Emacs
        SOC=$(_emc_find_emacs_socket)
        if [ ! -e "$SOC" ]; then
            case ${OSTYPE} in
                (darwin*)
                    # This assumes Emacs' init sequence, like mine, includes (server-start)
                    osascript -e "tell application \"Emacs\" to activate"
                    ;;
                (linux*)
                    emacs --daemon
                    ;;
            esac
        fi
    }

    function _emc_find_emacs_socket () {
        # Find the socket that Emacs server is using
        SOC=""
        case "${OSTYPE%%[0-9.-]*}" in
            (darwin*)
                # Sigh: ignore errors that might come from mounted Time Machine volumes
                SOC=$(lsof -w -c '/Emacs/i' | awk '/server$/ { print $(NF) }')
                ;;
            (linux*)
                # Linux includes socket info following path
                SOC=$(lsof -c '/emacs/i' | awk '/server / {print $(NF-2) }')
                ;;
        esac
        printf "%s" "$SOC"
    }

    function _emc_wait_for_server_response () {
        declare -i TIMER=1
        while [[ ! -e "$SOC" ]]; do
            # Look for Emacs' server socket
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

    function _emc_find_emacs_pid () {
        local process_name pid
        case ${OSTYPE} in
            (darwin*)
                process_name="Emacs"
                ;;
            (linux*)
                process_name="emacs"
                ;;
        esac
        # Within Emacs shell, on macOS, pgrep doesn't find the Emacs process
        # Possibly the bug described https://unix.stackexchange.com/a/100759/13887
        # Use lsof instead.
        pid="$(lsof -w -c "/$process_name/i" -t)"
        echo "$pid"
    }

    function _emc_find_client_path () {
        # Find the emacsclient associated with the running Emacs
        local emacs_path="" pid client=""
        pid="$1"
        emacs_path="$(ps -fp "$pid" | awk 'NR>1 {printf "%s", $NF}')"
        # Find the companion emacsclient in the filesystem hierarchy
        while [[ "${emacs_path%/*}" != "" && "$client" == "" ]]; do
            # EmacsForMac RC includes multiple bin-* directories for separate $(uname -m)s
            # Use the universal binary from bin/ (first we hope.)
            client="$(find "${emacs_path%/*}" -name emacsclient | head -1)"
            emacs_path="${emacs_path%/*}"
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

    local CLIENT pid
    pid="$(_emc_find_emacs_pid)"
    CLIENT=$(_emc_find_client_path "$pid")
    if [ -n "$CLIENT" ]; then
        _emc_wait_for_server_response

        # shellcheck disable=SC2068 # Send each array element as separate argument
        "$CLIENT" -s "$SOC" -n -a \"\" $@

        # And focus Emacs
        case "$OSTYPE" in
            (darwin*)
                osascript -e "tell application \"Emacs\" to activate"
                ;;
            (linux*)
                if type wmctrl &>/dev/null; then
                    wmctrl -ia "$pid"
                fi
                ;;
        esac
    else
        printf "Can't find emacsclient to open %s\n" "$@"
    fi
}

function emr {
    # Open files read-only
    emc -e "(view-file \"$*\")"
}

# shellcheck disable=SC1091 # eat - Emulate a Terminal
[[ -n "$EAT_SHELL_INTEGRATION_DIR" ]] && \
    source "$EAT_SHELL_INTEGRATION_DIR/${SHELL##*/}"

# Any arguments? Then invoke emacsclient with them
if [[ ${#@} -gt 1 ]]; then
    emc "$@"
fi
