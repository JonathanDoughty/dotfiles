#!/usr/bin/env bash
# .bash_profile - login shell initialization

[ -z "$PS1" ] && return # If not running interactively, do nothing else

# Avoid macOS's ancient bash
if [ "${BASH_VERSINFO[0]}" == "3" ]; then
    case $- in
        (*i*)  # As long as shell is interactive
            for d in "/opt/homebrew" "/usr/local"; do
                RECENT_BASH="${d}"/bin/bash
                if [ -x ${RECENT_BASH}  ]; then
                    exec ${RECENT_BASH} --login
                fi
            done
            ;;
    esac
fi

# startup profiling - see https://www.rosipov.com/blog/profiling-slow-bashrc/
# and ~/CM/Base/bin/bash_profile.py
#PROFILE_LOG=/tmp/bashstart.$$.log    # uncomment to start profiling
if [ -n "${PROFILE_LOG}" ]; then
    printf "Profiling - expect slow start.\n"
    PS4='+ $EPOCHREALTIME\011 '     # bash 5 can report time to sufficient microsecond resolution
    #PS4='+ $(gdate "+%s.%N")\011 ' # coreutils' gdate has nanosecond resolution
    exec 3>&2 2>"${PROFILE_LOG}"
    set -x
fi

[ -n "$ENV_SET" ] && return  # from .bashrc; avoid multiple invokations (e.g., Synology)

# Generic aliases and functions
if [ -f ~/.bashrc ]; then
    # shellcheck disable=SC1090
    source ~/.bashrc
fi

# System specific settings
OS_SETTINGS=~/.bash_$(uname -s)
if [ -f "$OS_SETTINGS" ]; then
    # shellcheck disable=SC1090
    source "$OS_SETTINGS"
fi

# Host specific settings
HOST_SETTINGS=~/.bash_$(hostname -s)
if [ -f "$HOST_SETTINGS" ]; then
    # shellcheck disable=SC1090
    source "$HOST_SETTINGS"
fi

if [ -n "${PROFILE_LOG}" ]; then
    set +x
    exec 2>&3 3>&-
    printf -v CMD "%s %s" "$(command which bash_profile.py)" "${PROFILE_LOG}"
    printf "Profiling complete.\nEvaluate results with\n"
    case "${OS_SETTINGS#*_}" in
        (Darwin)
            echo "$CMD" | pbcopy
            printf "%s\nwhich you can paste from clip/pasteboard\n" "$CMD"
            ;;
        (*)
            printf "%s\n" "$CMD"
            ;;
    esac
    unset PROFILE_LOG CMD
fi
unset OS_SETTINGS HOST_SETTINGS
