#!/usr/bin/env bash
# .bash{rc,_aliases} - bash personal initializations; many years of accumulated cruft here

#[[ -t 0 ]] || return # scripts should not rely on this top level, connected to a terminal test

# System definitions
if [[ -f /etc/bashrc ]] && [[ -z "$INSIDE_EMACS" ]]; then
    # shellcheck disable=SC1091
    . /etc/bashrc
fi

[[ "$EUID" -eq 0 ]] && return   # avoid remainder if root

declare -i _verbose=0           # 1 - report externals; 2 - more; 3 - detailed
declare -i _debug=0             # 1 - reserved for sourced scripts; >2 - some execution traces

# Functions used herein and in some other scripts in same repo
_helper_functions() {

    # Find and output the full path to the argument (or a blank line)
    script_source() {
        local SCRIPT SCRIPT_FILE=$1
        local APPLE_TERM=1  # Ignore $2 and always find script (1 was $2)
        [[ "$_debug" -gt 2 ]] && trap "set +x" RETURN && set -x
        # I used to prefer that Terminal on macOS be more standard unless forced and relied on
        # alternatives like iTerm. Setting APPLE_TERM above enables full customization in
        # Terminal.
        [[ "${TERM_PROGRAM}" == "Apple_Terminal" && -z "$APPLE_TERM" ]] && echo "" && return
        if [[ -e "${SCRIPT_FILE}" ]]; then
            echo "${SCRIPT_FILE}"
            return
        else
            # Expect script in same directory as this (.bashrc)
            if [[ -L "${BASH_SOURCE[0]}" ]]; then
                # readlink on MacOSX does nothing if target is not a symlink
                SCRIPT="$(dirname "$(readlink -n "${BASH_SOURCE[0]}")")/${SCRIPT_FILE}"
            else
                SCRIPT="$(builtin cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/${SCRIPT_FILE}"
            fi
        fi
        echo "${SCRIPT}"
    }

    # For infrequently used functions, reduced .bashrc size, and general dotfile goodness:
    # redefine stub functions from external source files on first use.
    # ToDo: Move this to misc-functions.sh ?
    lazy_load_from() {
        local REDEFINED_FUNCTION=${FUNCNAME[1]}
        local SCRIPT SCRIPT_FILE=$1 && shift
        SCRIPT=$(script_source "${SCRIPT_FILE}")

        if [[ -e "${SCRIPT}" ]]; then
            if [[ "$2" = "quiet" ]]; then # strip the 'quiet' last argument
                set -- "${@:1:$(($#-1))}"
            fi
            . "${SCRIPT}"
            declare -f "${REDEFINED_FUNCTION}" > /dev/null
            if [[ $? ]]; then
                $REDEFINED_FUNCTION "$@"
            else
                echo "$SCRIPT did not redefine $REDEFINED_FUNCTION"
            fi
        elif [[ "$2" = "quiet" ]]; then
            # rarely: issue no warning and remove the attempted redefinition
            unset -f "${REDEFINED_FUNCTION}"
        elif [[ -z "${SCRIPT}" ]]; then
            echo "Can't find script ${SCRIPT}, ${REDEFINED_SCRIPT} not redefined"
        fi
    }

    # `source` functions & config from external file
    _define_from() {
        local EXT_CMDS
        EXT_CMDS="$(script_source "$@" )"
        if [[ -e "$EXT_CMDS" ]]; then
            source "$EXT_CMDS"
            [[ "$_verbose" -gt 0 ]] && printf "Sourced definitions from %s\n" "$1" 1>&2
            return 0
        else
            [[ "$_verbose" -gt 1 ]] && printf "Skipped sourcing from non-existent %s\n" "$1" 1>&2
            return 1
        fi
    }

    # Other common functions
    _define_from shell-funcs.sh
    _define_from path_add_remove.sh
}

# Generate/re-order PATH based on directories that actually exist on this machine
_path_additions() {
    [[ "$_debug" -gt 1 ]] && trap "set +x" RETURN && set -x

    local post_external_additions=${#}

    case "$post_external_additions" in
        (0)    # Start by sanitizing previously set PATH (*cough* path_helper & /etc/paths.d/*)
            declare -a ORIGINAL_PATH
            local oldIFS=$IFS
            IFS=:
            read -r -a ORIGINAL_PATH <<<"$PATH"
            IFS=$oldIFS
            # shellcheck disable=SC2123  # because PATH is what will be sanitized / added to
            PATH=
            add_to_my_path "${ORIGINAL_PATH[@]}"

            # Order matters below: additions made later, at front of PATH, take precedence
            add_to_my_path /usr/local/share/bin
            add_to_my_path /usr/local/bin
            # My utilities - needed pre-externals because some external defs pick up scripts from here
            add_to_my_path "${HOME}/CM/Base/bin" "${HOME}/CM/Base/$(uname -s)"

            # Machine specific paths
            case ${OSTYPE} in
                (darwin*)
                    ;;
                (linux*)
                    # Left for reference, I don't typically use these any more
                    #add_to_my_path /usr/psql-*/bin   # PostgreSQL
                    #add_to_my_path /snap/bin         # snaps
                    #add_to_my_path /opt/local/apache-maven-*/bin  # Java
                    ;;
                (cygwin*)
                    # Historical reference / Windows brag
                    if [[ -r /cygdrive/c ]]; then
                        PATH=/usr/bin:${PATH}
                        # Don't confuse Cygwin with MS's Unix
                        if [[ -r /cygdrive/c/SFU/common ]]; then
                            rpath /cygdrive/c/SFU/common/ # what?
                        fi
                    fi
                    ;;
            esac
            ;;
        (*)       # Paths to override standards, externals, and framework specific contents.
            if [[ -n "$HOMEBREW_PREFIX" ]]; then
                add_to_my_path "${HOMEBREW_PREFIX}/"{bin,sbin} # move before standards
                add_to_my_path "${HOMEBREW_PREFIX}"/opt/coreutils/bin # GNU standard replacements
            fi

            # Move some externals ahead of homebrew's
            local IFS=:
            for p in $PATH ; do
                if [[ "$p" =~ Python ]]; then
                    add_to_my_path "$p" # prepend and remove duplicates
                fi;
            done
 
            # My own platform specific installations take precedence
            add_to_my_path "${HOME}/.local/bin"
            ;;
    esac
    [[ "$_verbose" -gt 1 ]] && printf "augmented/re-ordered PATH: %s\n" "$PATH"
}

# Environment variables
_environment_setup() {
    # set up environment only if not set
    # this was well avoided overhead in the last century; much less so now
    case ${ENV_SET:-notset} in
        (notset)
            [[ "$_debug" -gt 1 && -n "${INSIDE_EMACS}" ]] && set -x

            # Environment variables generic enough to be aggregated here

            export EDITOR=vi    # sadly emacs isn't everywhere by default
            export VISUAL=${EDITOR}
            export RIPGREP_CONFIG_PATH=${HOME}/.ripgreprc # rc file not automatic considered silly
            export SUDO_PS1='# '
            export TIMEFORMAT=$'\nreal:\t%R\nuser:\t%U\nsystem:\t%S\ncpu:\t%P%%'

            # Color preferences - belongs in _terminal_setup or external though does perturb environment
            local SCRIPT_SRC
            if is_defined dircolors ; then
                SCRIPT_SRC=$(script_source "my.dircolors")
                # dircolors (GNU coreutils on macOS) pertains mostly to Linux terminal logins now
                [[ -e ${SCRIPT_SRC} ]] && eval "$(dircolors "${SCRIPT_SRC}")"
                export LS_COLORS
            fi

            # bash always resets PATH; overload ENV_SET
            ENV_SET=$PATH; export ENV_SET
            ;;
        (*)  # environment already set
            if [[ "$PATH" -ne "$ENV_SET" ]]; then
                printf "PATH has gotten out of sync:\n%s\nexpected:\n%s\n" "$PATH" "$ENV_SET" 1>&2
            fi
            ;;
    esac # ! ENV_SET
}

_external_defs() { # functions, etc. related to local installs, external set up
    local files f

    [[ "$_debug" -gt 1 ]] && trap "set +x" RETURN && set -x
    files=(
        "brew-integration.sh"    # homebrew related
        "docker-funcs.sh"
        "emacsclient.sh"         # shell emacs access
        "enable_fzf.sh"          # fuzzy finder
        "git-integration.sh"
        "bash-go.sh"             # golang dev
        "disable-bash-office.sh"
        "bash-tmux.sh"
        "enable_python.sh"       # python dev
        "disable-bash-pyenv.sh"
        "disable-switch_java.sh"         # java dev
        "bash-dev.sh"            # miscellaneous development
        "bash-misc.sh"           # miscellaneus stubs and helpers
        "misc-functions.sh"      # crutches I've grown to depend on, including lazy loaded overrides
        "less_termcap.sh"        # PAGER & related functions & preferences
    )
    for f in "${files[@]}"; do
        # source the ones that exist
        _define_from "$f"
    done
}

# Adapt to the terminal this shell runs in
_terminal_setup() {
    # Note: in most cases we would [[ -t 0 ]] || return but some scripts *may* want to do
    # terminal-like adaptions. E.g., I think ssh_add / keychain may be viable

    [[ "$_debug" -gt 1 ]] && trap "set +x" RETURN && set -x
    if [[ -n "$TERMINAL_EMULATOR" || "$TERM_PROGRAM" == "vscode" ]]; then
        return                  # avoid terminal adaptation in IDE consoles
    fi

    # Terminal control related external definitions
    local files f
    files=(
        "cli_prompt.sh" # setup prompt based on user choice
        "enable_direnv.sh"
        "iterm_integration.sh"
        "ssh_start_agent.sh"
    )
    for f in "${files[@]}"; do
        # source the ones that exist
        _define_from "$f"
    done

    # See https://emacs.stackexchange.com/q/2573/5146 wrt Emacs shell-mode
    # Old bash version syntax for macOS native bash compatibility
    # An issue seen in emacs shell and Terminal exec bash
    PROMPT_COMMAND=${PROMPT_COMMAND/;;/;}
}

_interactive_options() {
    case $- in                      # ksh, bash, set -i for interactive
        (*i*) # interactive set up continues
            # Terminal set up / shell environment configuration
            # bash specific
            set -o emacs
            set -o noclobber
            set -o physical # follow symlinks
            # See also .bash_* for system specific additions
            HISTFILESIZE=10000
            HISTSIZE=10000
            HISTCONTROL=ignoredups
            #HISTIGNORE="ssh *:scp *:mta *:"
            shopt -s histappend histreedit histverify
            shopt -s checkwinsize
            umask u=rwx,g=rx,o=
            # completion setup moved to brew, OS/system inits, or specific additions
            ;;
        (*)                     # non-interactive - be standard
            ;;
    esac
}

_main() {
    # ... A Maze Of Twisty Little Passages All Alike...
    _helper_functions

    if [ -z "$ENV_SET" ]; then  # avoid duplicate invocation, e.g., for exec bash
        _environment_setup
        _path_additions         # standard paths including ~/.local/bin for external_defs
    fi

    _interactive_options "$@"        # external_defs (e.g., fzf) rely on set -o emacs/vi
    _external_defs                   # relies on _path_additions above
    _terminal_setup                  # some rely on external_defs, e.g., ssh agent check
    _path_additions "post externals" # final path revisions

    cd . || return              # NB: NOT builtin cd
    # Side-effect: lazy load function definitions for overrides and initialize tab title & prompt;
    # this is way too obscure.

    # Clear variables/functions not intended for further use
    unset -v _verbose _debug
    unset -f _environment_setup _interactive_setup _terminal_setup \
          _define_from _helper_functions _external_defs _aliases _path_additions \
          "${FUNCNAME[0]}"
}

# possibly useful
#trap 'printf "%s:%d\n" "${FUNCNAME[0]}" "$LINENO"' DEBUG

_main "$@"
