#!/usr/bin/env bash
# .bash_profile - login shell initialization

[[ -t 0 ]] || return # Do nothing if stdin is not a terminal

# Further shell adaptations below from
ADAPTATIONS+=(~/.bashrc)                # Generic aliases and functions
ADAPTATIONS+=(~/.bash_"$(uname -s)")    # for this OS
ADAPTATIONS+=(~/.bash_"$(hostname -s)") # for this host
ADAPTATIONS+=(~/.bash_custom)           # additional user customization

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
        (*)
            printf "Not an interactive shell\n"
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

if [[ "$ENV_SET" == "$PATH" ]]; then
    printf "ENV_SET (%s) == PATH (%s), redundant?\n" "$ENV_SET" "$PATH"
    : # && return  # set in .bashrc; avoid multiple invocations (e.g., Synology)
fi

# Include others, in order
for f in "${ADAPTATIONS[@]}"; do
    if [ -f "$f" ]; then
        : printf "sourcing %s\n" "$f"
        source "$f"
    fi
done

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
unset ADAPTATIONS
