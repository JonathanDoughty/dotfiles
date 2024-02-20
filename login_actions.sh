#!/usr/bin/env bash
# Actions to set up standard applications on login

# This gets symlinked as app_script in a Platypus app which runs as a Login item

sparsebundle="${HOME}/CM.sparsebundle"
sparse_volume="/Volumes/CM"
sourcedir="${HOME}/CM/dotfiles"  # where the master copy of this lives
app_script="${HOME}/Applications/LogInScript.app/Contents/Resources/script"
verbose=1
log=
[ $verbose -gt 1 ] && log=~/login_actions.txt

adjust_path () {
    PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"
}

mount_cm () {
    declare -i times delay=2

    # Check that my case sensitive sparsebundle, generally a separate login item, is accessible
    if [ ! -d "$sourcedir" ]; then
        if [ -d "$sparsebundle" ]; then
            [ $verbose -gt 0 ] && printf "Opening %s\n" "$sparsebundle"
            open "$sparsebundle"    # Get macos to mount the sparsebundle as a volume
            sleep $delay
        else
            printf "NO %s ?!!\n" "$sparsebundle"
            exit 1
        fi
    else
        [ $verbose -gt 0 ] && printf "%s is accessible\n" "$sourcedir"
        return 0
    fi

    # Wait for sparsebundle contents to appear

    for times in 10 9 8 7 6 5 4 3 2 1 0; do
        if [ ! -d "$sourcedir" ]; then
            [ $verbose -gt 1 ] && printf "Waiting %s seconds for %s\n" $((times * delay)) "$sourcedir"
            sleep $delay
        else
            break
        fi
    done
    if [ ! -d "$sourcedir" ]; then
        printf "%s not accessible, exiting\n" "$sourcedir"
        return 1
    fi
    return 0
}

dismount_cm () {
    local pids
    declare -i p
    # Signal processes (other than this one) accessing sparse bundle
    pids=$(lsof "$sparse_volume" | awk 'NR>1 {print $2}' | grep -v $$ | sort -u)
    for p in $pids; do
        kill "$p"
    done
    diskutil eject "$sparse_volume"
}

check_scripts_sources () {
    # Let me know (in iTerm where I can do something about it) if the CM'd version of this and
    # related scripts are out of sync.
    #trap "set +x" RETURN && set -x # fun^ction debugging
    if [ -n "$TERM_PROGRAM" ]; then
        cmp "$sourcedir/${BASH_SOURCE[0]##*/}" "${BASH_SOURCE[0]}"
        cmp "$sourcedir/Justfile" "Justfile"
        cmp "$app_script" "${BASH_SOURCE[0]}"
    fi
}

# Initializations that depend on contents of the sparsebundle

ssh_identities () {
    # Add identities so that all clients of ssh-agent have access to those.
    # It appears that Ventura has added functionality to ssh-add such that if
    # no agent exists but the socket does, that an ssh-agent process is spawned.

    # If you get "No identity found in the keychain." then you'll need to
    # (cd ~/.ssh; ssh-add --apple-use-keychain [private key files])

    if [ -S "$SSH_AUTH_SOCK" ]; then
        [ $verbose -gt 1 ] && printf "ssh-agent processes:\n%s\n" "$(pgrep -l ssh-agent)" && \
            printf "SSH_AUTH_SOCK's owner: %s\n" "$(lsof -t "$SSH_AUTH_SOCK")"
        if ! /usr/bin/ssh-add -l >/dev/null 2>&1; then
            # Sierra+ enables adding identities with passphrases stored in Keychain via ssh-add -K
            # ssh-add will add all local keys with Keychain passwords
            (builtin cd ~/.ssh || exit ; /usr/bin/ssh-add -q --apple-load-keychain --apple-use-keychain)
            [ $verbose -gt 0 ] && printf "Added the following identities to ssh agent %s\n" "$SSH_AUTH_SOCK"
        else
            [ $verbose -gt 0 ] && printf "ssh identities already added\n"
        fi
        ssh-add -l | awk '{printf "\t%s\n", $3}'
    else
        printf "No ssh-agent socket present\n"
    fi
}

start_hammerspoon () {
    # Make sure my primary Mac crutch is in place
    if ! pgrep -q Hammerspoon ; then
        open -a Hammerspoon && [ $verbose -gt 0 ] && printf "Started Hammerspoon\n"
    else
        [ $verbose -gt 0 ] && printf "Hammerspoon already started\n"
    fi
}

start_notebooks () {
    (cd ~/TW && just open && [ $verbose -gt 0 ] && printf "Started Notes\n")

    case "$(uname -n)" in
        (WorkLaptop*)
            # Start my Project notebook on work laptop
            pgrep -q -f 'tiddlywiki.*port=9994' || \
                (~/CM/Base/bin/tw -s project &>/dev/null && printf "Started Project TW\n")
            open http://localhost:9994
            ;;
    esac
}

init_log () {
    if [ -n "${log}" ]; then
        if touch "$log"; then
            printf "Log being generated in %s\n" "$log"
        else
            printf "Unable to create %s\n" "$log"
        fi
        # Adapted from: https://www.linuxjournal.com/content/bash-redirections-using-exec
        if test -t 1; then      # Stdout is a terminal.
            exec &> >(tee "$log")
        else                    # Stdout is not a terminal.
            npipe=/tmp/$$.tmp
            trap 'rm -f $npipe' EXIT
            mknod $npipe p
            tee <$npipe "$log" &
            exec 1>&-
            exec 1>$npipe
        fi
    fi
}

login_actions () {
    init_log

    if [ "$#" -gt 0 ]; then
        case "$1" in
            (*path*)
                adjust_path
                ;;
            (*cm*)
                mount_cm
                ;;
            (*check*)
                check_scripts_sources
                ;;
            (*ssh*)
                ssh_identities
                ;;
            (*hammer*)
                start_hammerspoon
                ;;
            (*note*)
                start_notebooks
                ;;
            (*)
                printf "Unrecognized %s option: %s\n" "$0" "$1"
                ;;
        esac
    else                        # auto sequence
        adjust_path
        mount_cm || exit 1      # or all further bets are off
        check_scripts_sources
        ssh_identities
        start_hammerspoon
        start_notebooks
    fi
}


[ $verbose -gt 1 ] && set -x
case "$0" in
    (*login*|*script*)
        login_actions "$@"
        ;;
esac
