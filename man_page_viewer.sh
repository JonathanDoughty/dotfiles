#!/usr/bin/env bash
# man_page_viewer - set up for man pages, documentation etc.
# I source this in my interactive shell environment via .{bash,zsh}rc

if [ -z "$ZSH_VERSION" ]; then
    [ "$_" != "$0" ] || { printf "%s must be sourced to be useful." "$0"; exit 1; }
else
    # shellcheck disable=SC2296     # This will be evaulated by zsh
    [[ -n ${(M)zsh_eval_context:#file} ]] || \
        { printf "%s must be sourced to be useful.\n" "$0"; exit 1; }
fi

: "${OS:=$(uname -s)}"          # rather than the builtin OSTYPE for historical reasons

if type add_to_my_path >/dev/null 2>&1 ; then
    # shellcheck disable=SC1091
    [[ -z ${ZSH_VERSION} ]] && . "$(dirname "${BASH_SOURCE[0]}")/path_add_remove.sh"
    # shellcheck disable=SC1091,SC2296 # This is valid zsh sytax
    [[ -n ${ZSH_VERSION} ]] && . "$(dirname "${(%):-%N}")/path_add_remove.sh"
fi

set_manpath() {
    # ferret out where man pages are on different systems
    if [[ -n "$ZSH_VERSION" ]]; then
        emulate -L bash
    else
        # bash's trap works differently
        [[ "$VERBOSE" -gt 1 ]] && trap "set +x" RETURN && set -x
    fi

    # Set up standard paths to include only existing directories, only once, on first use
    add_to_man_path () {
        # Be DRY and don't repeat path handling logic from path_add_remove.sh
        local OLD_PATH="$PATH"; PATH="${MANPATH}"
        add_to_my_path "$@"
        MANPATH="$PATH"
        PATH="$OLD_PATH"
        [[ -n "$VERBOSE" ]] && printf "MANPATH: %s\n" "${MANPATH}"
    }

    local mandirs=()
    export ORIGINAL_MANPATH=${MANPATH} # remember this has been done
    case ${OS} in
    (Darwin)
        # See man path_helper for setting initial system MANPATH
        mandirs+=(
            "/usr/share/man"    # Put built-in macOS man pages first
            "$(eval "$(/usr/libexec/path_helper -h | grep MANPATH)"; echo "${MANPATH/: / }")"
            "${JAVA_HOME:=$(/usr/libexec/java_home)/man}"
        )
        ;;
    (Linux)                    # generally most will be in man.config
        mandirs+=(
            "${JAVA_HOME:=/opt/local/java}"/man
            /usr/share/man /opt/local/man /usr/lib/perl5/man
            /opt/local/share/man
                 )
        ;;
    (Cygwin)                    # Historical reference
        if [ -r /cygdrive/c ]; then
            mandirs+=(
                /usr/share/man
            )
        fi
        ;;
    (SunOS|IRIX|HPUX)           # Showing off old experience
        mandirs+=(
            /opt/SUNWspro/man /usr/openwin/man /usr/dt/man
            /usr/catman /usr/contrib/man # SGI, HP
            /opt/local/man /opt/GNU/man
            /usr/X11R6.3/man /opt/X11r5/man
            /opt/hpnp/man /usr/man
            /opt/local/man/perl/man /opt/local/lib/perl5/man
            /usr/afsws/man
        )
        ;;
    esac
    if [ -n "${mandirs[*]}" ]; then
        # first the man equivalents to PATH; this picks up some extras
        # The / expression is bash specific
        [ "${BASH/*bash}" == "" ] && add_to_man_path "${PATH//bin/man}"
        # Then the other candidates from above
        add_to_man_path "${mandirs[@]}"
        export MANPATH
    fi
}

helpme() {                      # help is a bash builtin
    # Use command's --help option (assuming it has one)
    if type bat 1>/dev/null 2>&1 ; then
        "$@" --help 2>&1 | bat --language=help
    else
        "$@" --help 2>&1 | more
    fi
}

man() {
    # Insure MANPATH is sane before invoking terminal man pager
    [[ -n "${ORIGINAL_MANPATH}" ]] || set_manpath
    # If bat has been installed, use its extra man colorizing
    if type bat 1>/dev/null 2>&1 && [[ -z "$MANPAGER" ]]; then
        export MANPAGER="sh -c 'col -bx | bat --language=man'"
    fi
    command man "$@"
    # No man page? try help instead
    if [[ $? ]]; then
        helpme "$@"
    fi
}

mman() {
    # Generally I prefer a separate viewer app

    # zsh still does not like something in here - maybe this should be -L ksh like it was?
    [ -n "${ZSH_VERSION}" ] && emulate -L bash
    local -i VERBOSE
    local flag

    while getopts "Tv" flag "$@"; do
        if [[ "$flag" == "T" && -z "$ZSH_VERSION" ]]; then
            trap "set +x" RETURN && set -x # trace all remaining execution
        elif [ "$flag" == "v" ]; then
            VERBOSE+=1
        fi
    done
    shift "$((OPTIND - 1))"

    _dash() {
        if [[ "${VERBOSE}" -gt 1 && -z "$ZSH_VERSION" ]]; then
            trap "set +x" RETURN && set -x # function debugging
        fi
        if [ $# -eq 1 ]; then
            open "dash://manpages%3A${1}"
        else
            local docset=$1
            shift
            # Shorter mappings to specific docsets are via Dash docset keyword edits
            if [ -n "${VERBOSE}" ]; then
                echo "open dash://${docset}%3A$*"
            fi
            open "dash://${docset}%3A$*"
        fi
    }

    # Insure MANPATH is sane before invoking viewer the first time. It is not clear if this
    # environment change accomplishes anything anyway, especially if the app was already
    # started.
    [[ -n "${ORIGINAL_MANPATH}" ]] || set_manpath

    case ${OS} in
        (Darwin)
            if [[ -e /Applications/Dash.app || -e ~/Applications/Dash.app ]]; then
                _dash "$@"
            else
                # Use native Postscript generation, piping that to Preview
                # though since Postscript was removed in Sonoma ... - see Notes on Dash
                command man -t "$@" | open -f -a Preview
            fi
            ;;
        (Linux)
            if [ -n "${DISPLAY}" ]; then
                if [ -n "${VERBOSE}" ]; then
                    echo "yelp man:$1"
                fi
                yelp man:"$1" 2> /dev/null & # re-look at man2html?
            else
                # TODO yak shaving: check if in tmux and open page in another (or a man) window
                man "$@"
            fi
            ;;
    esac
}
if [[ -n "$ORIGINAL_MANPATH" ]]; then # in case this is re-sourced
    MANPATH=$ORIGINAL_MANPATH
    export -n ORIGINAL_MANPATH
fi
