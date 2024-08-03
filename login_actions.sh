#!/usr/bin/env bash
# Actions to set up standard macOS applications on login

# I create a 40GB, Case sensitive, APFS sparsebundle where most of git repos
# and other work lives. Why? See https://stackoverflow.com/a/12085233/1124740
sparsebundle="${HOME}/CM.sparsebundle"

if [[ -z "$CM_DIR" ]]; then
    # Try to insure minimal environment, e.g., if running from Login item
    . ~/.envrc                  # what direnv would normlly run
fi
sourcedir="${CM_DIR:-/path/to/git/repo}"  # where the master copy of this lives

# This gets symlinked as app_script in a Platypus https://sveinbjorn.org/platypus
# app which I run as a Login item.
app_script="${HOME}/Applications/LogInScript.app/Contents/Resources/script"

verbose=0
log=
[ $verbose -gt 1 ] && log=~/login_actions.txt

adjust_path () {
    # Consider adding a file instead to /etc/paths.d/
    PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"
}

mount_cm () {
    # Check that my case sensitive sparsebundle, generally a separate login item, is accessible
    declare -i times delay=2

    if [[ ! -d "$sourcedir" ]]; then
        if [[ -d "$sparsebundle" ]]; then
            [ $verbose -gt 0 ] && \
                printf "Opening %s\n" "$sparsebundle"
            open "$sparsebundle"    # Get macOS to mount the sparsebundle as a volume
            sleep $delay
        else
            printf "NO %s ?!!\n" "$sparsebundle"
            exit 1
        fi
    else
        [[ $verbose -gt 0 ]] && \
            printf "%s is accessible\n" "$sourcedir"
        return 0
    fi

    # Wait for sparsebundle contents to appear
    for times in 10 9 8 7 6 5 4 3 2 1 0; do
        if [[ ! -d "$sourcedir" ]]; then
            [[ $verbose -gt 1 ]] && \
                printf "Waiting %s seconds for %s\n" $((times * delay)) "$sourcedir"
            sleep $delay
        else
            break
        fi
    done
    if [[ ! -d "$sourcedir" ]]; then
        printf "%s not accessible, exiting\n" "$sourcedir"
        return 1
    fi
    return 0
}

check_scripts_sources () {
    # Let me know (in terminal where I can do something about it) if the CM'd version of this and
    # related scripts are out of sync.
    _compare_if_present () {
        local src dest
        src="$1"
        dest="$2"
        if [[ -e "$src" && -e "$dest" ]]; then
            cmp "$src" "$dest"
        fi
    }
    #trap "set +x" RETURN && set -x
    if [[ -n "$TERM_PROGRAM" ]]; then
        # We want this to run in the destination directory, not the source git repo
        if [[ "$sourcedir" != "$(realpath "$(dirname "${BASH_SOURCE[0]}")")" ]] ; then
            # This script
            _compare_if_present "$sourcedir/${BASH_SOURCE[0]##*/}" "${BASH_SOURCE[0]}"
            _compare_if_present "$sourcedir/Justfile" "Justfile"
            _compare_if_present "$sourcedir/.envrc" ".envrc"
            _compare_if_present "$app_script" "${BASH_SOURCE[0]}"
        else
            printf "%s expects to run from %s not %s\n" "${BASH_SOURCE[0]}" "$HOME" "$PWD"
        fi
    fi
    unset -f _compare_if_present
}

# Initializations that depend on contents of the sparsebundle

ssh_identities () {
    # Add identities so that all clients of ssh-agent have access to those. Ventura added
    # functionality to ssh-add such that if no agent exists but the socket does, then an
    # ssh-agent process is spawned. For Linux see ssh_start_agent.sh.

    # If you get "No identity found in the keychain." then you'll need to
    # (cd ~/.ssh; ssh-add --apple-use-keychain [private key files])

    local cmd
    cmd=/usr/bin/ssh-add        # use native ssh, no e.g., brew alternatives
    if [[ -S "$SSH_AUTH_SOCK" ]]; then
        [ $verbose -gt 1 ] && \
            printf "ssh-agent processes:\n%s\n" "$(pgrep -l ssh-agent)" && \
            printf "SSH_AUTH_SOCK's owner: %s\n" "$(lsof -t "$SSH_AUTH_SOCK")"
        if ! $cmd -l &>/dev/null ; then
            # Sierra+ enabled adding identities with passphrases stored in Keychain via
            # ssh-add --apple-use-keychain
            # ssh-add --apple-load-keychaion will add all local keys with Keychain passwords
            (                   # In a subshell
                builtin cd ~/.ssh || exit
                $cmd -q --apple-load-keychain --apple-use-keychain
            )
            [ $verbose -gt 0 ] && \
                printf "The following identities are available to ssh via %s\n" "$SSH_AUTH_SOCK"
        else
            [ $verbose -gt 0 ] && \
                printf "ssh identities already added\n"
        fi
        # shellcheck disable=SC2046 # word splitting desired listing keys
        $cmd -l | basename $(cut -d ' ' -f 3)
    else
        printf "No ssh-agent socket present\n"
    fi
}

start_hammerspoon () {
    # Make sure my primary Mac crutch is in place
    local crutch=Hammerspoon
    if ! pgrep -q "$crutch" ; then
        local id app
        # Look for the application
        id=$(osascript -e "id of application \"$crutch\"" 2>/dev/null)
        app="$(osascript -e "tell application \"Finder\" to POSIX path of (get application file id \"$id\" as alias)" 2>/dev/null)"
        if [[ -n "$app" ]]; then
            open -a "$app" && [ $verbose -gt 0 ] && \
                printf "Started %s\n" "$crutch"
        else
            printf "%s not found\n" "$crutch"
        fi
    else
        [ $verbose -gt 0 ] && printf "%s already started\n" "$crutch"
    fi
}

start_notebooks () {
    (
        builtin cd ~/TW 2>/dev/null || exit
        just open && [ $verbose -gt 0 ] && printf "Started Notes\n"
    )

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
    else                        # auto sequence through all functions
        adjust_path
        mount_cm || exit 1      # or all further bets are off
        check_scripts_sources
        ssh_identities
        start_hammerspoon
        start_notebooks
    fi
}

# Allow for command line testing of individual functions
[ $verbose -gt 1 ] && set -x
case "$0" in
    (*login*|*script*)
        login_actions "$@"
        ;;
esac
