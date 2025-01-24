#!/usr/bin/env bash
# Actions to set up conditions and start macOS applications on login

declare -i verbose=0            # 1 - info; 2 - chattier & logged; 3 - executaion trace

settings () {
    [[ "$verbose" -gt 2 ]] && set -x
    [[ "$verbose" -gt 1 ]] && log=~/login_actions.txt

    # I create a 40GB, Case sensitive, APFS sparsebundle where most of git repos
    # and other work lives. Why? See https://stackoverflow.com/a/12085233/1124740
    sparsebundle="${HOME}/CM.sparsebundle"

    if [[ -z "$CM_DIR" ]]; then
        # Try to insure minimal environment, e.g., if running from Login item
        if type direnv &>/dev/null; then
            direnv allow; eval "$(direnv export bash)"
        else
            [[ -z "${DIRENV_FILE}" ]] && . ~/.envrc # what direnv would normlly run
            # NB this won't handle otherdirectories though, as in start_notebooks
        fi

        # ToDo?
        # Use `launchctl setenv` to export environmental changes to future processes
        # Best done as a start/end diff to pick up other changes
    fi
    source_dir="${CM_DIR:-/path/to/git/repo}"  # where the master copy of this lives

    # This gets symlinked as app_script in a Platypus https://sveinbjorn.org/platypus
    # app which I run as a Login Item.
    app_script="${HOME}/Applications/LogInScript.app/Contents/Resources/script"
}

adjust_path () {
    # Consider adding a file instead to /etc/paths.d/
    PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"
}

mount_cm () {
    # Check that my case sensitive sparsebundle, generally a separate login item, is accessible
    declare -i times delay=2

    if [[ ! -d "${source_dir}" ]]; then
        if [[ -d "$sparsebundle" ]]; then
            [ "$verbose" -gt 0 ] && \
                printf "Opening %s\n" "$sparsebundle"
            open "$sparsebundle"    # Get macOS to mount the sparsebundle as a volume
            sleep $delay
        else
            printf "NO %s ?!!\n" "$sparsebundle"
            exit 1
        fi
    else
        [[ "$verbose" -gt 0 ]] && \
            printf "%s is accessible\n" "${source_dir}"
        return 0
    fi

    # Wait for sparsebundle contents to appear
    for times in 10 9 8 7 6 5 4 3 2 1 0; do
        if [[ ! -d "${source_dir}" ]]; then
            [[ "$verbose" -gt 1 ]] && \
                printf "Waiting %s seconds for %s\n" $((times * delay)) "${source_dir}"
            sleep $delay
        else
            break
        fi
    done
    if [[ ! -d "${source_dir}" ]]; then
        printf "%s not accessible, exiting\n" "${source_dir}"
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
    if [[ -n "$TERM_PROGRAM" ]]; then
        # I want this to run in the destination directory, not the source git repo
        if [[ "${source_dir}" != "$(realpath "$(dirname "${BASH_SOURCE[0]}")")" ]] ; then
            # This script
            _compare_if_present "${source_dir}/${BASH_SOURCE[0]##*/}" "${BASH_SOURCE[0]}"
            # It's symlinked login item version
            _compare_if_present "$app_script" "${BASH_SOURCE[0]}"
            # Common environment definitions
            _compare_if_present "${source_dir}/.envrc" ".envrc"
            # Actions
            _compare_if_present "${source_dir}/HomeJustfile" "Justfile"
        else
            printf "%s expects to run from %s not %s\n" "${BASH_SOURCE[0]}" "$HOME" "$PWD"
        fi
    fi
    unset -f _compare_if_present
}

# Initializations that depend on contents of the sparsebundle

ssh_identities () {
    # Add identities so that all clients of ssh-agent have access to those.
    source "${source_dir}/ssh_start_agent.sh"
}

start_hammerspoon () {
    # Make sure my primary macOS crutch is in place
    local crutch=Hammerspoon
    if ! pgrep -q "$crutch" ; then
        local id app
        # Look for the application
        id=$(osascript -e "id of application \"$crutch\"" 2>/dev/null)
        app="$(osascript -e "tell application \"Finder\" to POSIX path of (get application file id \"$id\" as alias)" 2>/dev/null)"
        if [[ -n "$app" ]]; then
            open -a "$app" && [ "$verbose" -gt 0 ] && \
                printf "Started %s\n" "$crutch"
        else
            printf "%s not found\n" "$crutch"
        fi
    else
        [ "$verbose" -gt 0 ] && printf "%s already started\n" "$crutch"
    fi
}

start_notebooks () {
    if [[ -e ~/TW ]]; then
        (
            # My setup assumes direnv will init the environment
            builtin cd ~/TW 2>/dev/null || exit
            just open && [ "$verbose" -gt 0 ] && printf "Started Notes\n"
        )
    fi

    case "$(uname -n)" in
        (WorkLaptop*)
            # This used to start my Project notebook on work laptop
        pgrep -q -f 'tiddlywiki.*port=9994' || \
        (
            ~/CM/Base/bin/tw -s project &>/dev/null && printf "Started Project TW\n"
            open http://localhost:9994
        )
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
    settings
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
            (*hammer*|crutch)
                start_hammerspoon
                ;;
            (*note*|tw)
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

while getopts "hv?" flag; do
    case "$flag" in
        (v) verbose=$((verbose+1))
            ;;
        (h|\?|*)
            printf "%s path|cm|check|ssh|hammerspoon|notes\n" "${BASH_SOURCE[0]}"
            exit
            ;;
    esac
done
shift "$((OPTIND - 1))"

# Allow for command line testing of individual functions
login_actions "$@"
