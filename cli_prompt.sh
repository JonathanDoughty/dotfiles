#!/usr/bin/env bash
# Set up command line prompt glitz and naintaining full CLI history file.
# Also works in zsh.

# Selects from implementations based on:
# * https://github.com/starship/starship - if installed
# * https://github.com/justjanne/powerline-go - if installed
# * https://github.com/riobard/bash-powerline - modified version below
# * Ancient tradition - from back in the day, and for dumb terminals

# This consolidates various command line prompt setup utilities and settings I've tried / lived
# with over decades. The order below determines which gets set up, as determined by the first one
# recognized by _prompt_setup, except in the case of dumb terminals that always use traditional.

_PROMPT_SELECTIONS=( "starship" "powerline-go" "_bash_powerline" "_traditional")
_COLOR_THEME="base16-solarized-dark.sh" # see themes/*.sh
_THEME_DIR="$(dirname "${BASH_SOURCE[0]}")/themes"
_CLI_HISTORY=~/.full_history

if [[ -z "$_PS_SYMBOL" ]]; then # OS identifying symbol
    case "$(uname)" in
        (Darwin)   _PS_SYMBOL='' ;; # '' broken in some nerdfonts; alternative: '⌘'
        (Linux)    _PS_SYMBOL='$' ;;
        (*)        _PS_SYMBOL='%' ;;
    esac
    export _PS_SYMBOL
fi

# For powerline-go these are my preferences; you might prefer others.
# Order matters, at least wrt bash and the -modules* lines
_PLG_OPTIONS=(
    "-mode patched -theme default -max-width 30"
    "-shell-var _PS_SYMBOL"
    "-cwd-mode fancy -cwd-max-depth 2"
    "-modules host,ssh,cwd,perms,exit,shell-var"
    "-modules-right venv,git,direnv"
    "-hostname-only-if-ssh"
    "-git-mode fancy"
    "-path-aliases /Volumes/CM/Active=CM"  # where almost all my git repos live
)
_PLG_ARGS="${_PLG_OPTIONS[*]}"  # as a single string
if [[ -n "${BASH_VERSION}" ]]; then
    _PLG_EXE="$(type -p powerline-go)"
    # Bash doesn't support right prompt, collapse those into modules
    _PLG_ARGS="${_PLG_ARGS/ -modules-right /,}"
    # and as long as that's the case, if there is a max-width then
    # push powerline to a newline, increasing the max width
    _PLG_ARGS="${_PLG_ARGS/-max-width [0-9][0-9]/-max-width 50 -newline}"
elif [[ -n "${ZSH_VERSION}" ]]; then
    _PLG_EXE="$(whence powerline-go)"
fi

_powerline_git_ceiling_directories_handler() {
    # If current directory is a subdirectory of an element of GIT_CEILING_DIRECTORIES
    # remove the git related options from powerline-go's arguments
    local ARGS="${_PLG_ARGS//[$'\t\r\n ']+/}"
    # shellcheck disable=SC2034 # LOCAL_OPTIONS is used by zsh
    [[ -n "$ZSH_VERSION" ]] && setopt shwordsplit && LOCAL_OPTIONS=1
    for i in  ${GIT_CEILING_DIRECTORIES//:/ }; do
        [[ -n "$_verbose" ]] && \
            printf "PWD: '%s' GCD: '%s' diff: '%s'\n" "${PWD}" "${i}" "${PWD#"${i}"}"
        if [[ "${PWD#"${i}"}" != "${PWD}" && "${PWD#"${i}"}" != ""  ]]; then
            # In a subdirectory of GIT_CEILING_DIRECTORY remove the ,git module
            ARGS="${ARGS/,git/}"
            ARGS="${ARGS/,gitlite/}"
            ARGS="${ARGS/-git-mode fancy/}"
            [[ -n "$_verbose" ]] && \
                printf "%s != %s ARGS=%s\n" "${PWD#"${i}"}" "${PWD}" "${ARGS}"
            break
        fi
    done
    #ARGS="${ARGS//[$'\t\r\n ']+/}"  # unneeded now, right?
    printf "%b" "$ARGS"
}

_bash_powerline-go() {

    _update_ps1 () {
        local EXIT_CODE=$?
        local ARGS
        ARGS=$(_powerline_git_ceiling_directories_handler)
        # shellcheck disable=2086 # we want word splitting
        eval "$("${_PLG_EXE}" -eval ${ARGS} -error $EXIT_CODE)"
    }
    if [[ "${TERM_PROGRAM}" == "iTerm.app" ]]; then
        # iTerm shell integration has a problem with PROMPT_COMMAND
        # see https://github.com/powerline/powerline/issues/1844#issuecomment-636408883
        precmd_functions+=(_update_ps1)
    else
        PROMPT_COMMAND="_update_ps1 ${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
}

_zsh_powerline-go() {
    [[ -e "${_PLG_EXE}" ]] || return

    function powerline_precmd() {
        local EXIT_CODE=$?
        local ARGS
        ARGS=$(_powerline_git_ceiling_directories_handler)
        # shellcheck disable=SC2068,SC2298,SC2296 # zsh string splitting into an array
        eval "$("${_PLG_EXE}" -eval ${${(z)ARGS}[@]} -error $EXIT_CODE)"
    }

    function install_powerline_precmd() {
        for s in "${precmd_functions[@]}"; do
            if [ "$s" = "powerline_precmd" ]; then
                return
            fi
        done
        precmd_functions+=(powerline_precmd)
    }

    if [ "$TERM" != "linux" ]; then
        install_powerline_precmd
    fi
    unset install_powerline_precmd
}

_bash_powerline() {
    # Modified from: https://github.com/riobard/bash-powerline
    ## set to 0 to disable
    POWERLINE_GIT=${POWERLINE_GIT:=1}
    # For full directory use the first, for the basename of the current working directory only use \W
    #POWERLINE_DIR="\w"
    POWERLINE_DIR="\W"

    __powerline() {
        # Color scheme
        # ToDo: check this with what _color_setup does
        readonly RESET='\[\033[m\]'
        readonly COLOR_CWD='\[\033[0;35m\]' # magenta
        readonly COLOR_GIT='\[\033[0;36m\]' # cyan
        readonly COLOR_SUCCESS='\[\033[0;32m\]' # green
        readonly COLOR_FAILURE='\[\033[0;31m\]' # red

        readonly SYMBOL_GIT_BRANCH='?'
        readonly SYMBOL_GIT_MODIFIED='*'
        readonly SYMBOL_GIT_PUSH='?'
        readonly SYMBOL_GIT_PULL='?'

        __git_info() {
            [[ $POWERLINE_GIT = 0 ]] && return # disabled
            hash git 2>/dev/null || return # git not found
            local git_eng="env LANG=C git"   # force git output in English to make our work easier

            # get current branch name
            local ref
            ref=$($git_eng symbolic-ref --short HEAD 2>/dev/null)

            if [[ -n "$ref" ]]; then
                # prepend branch symbol
                ref=$SYMBOL_GIT_BRANCH$ref
            else
                # get tag name or short unique hash
                ref=$($git_eng describe --tags --always 2>/dev/null)
            fi

            [[ -n "$ref" ]] || return  # not a git repo

            local marks

            # scan first two lines of output from `git status`
            while IFS= read -r line; do
                if [[ $line =~ ^## ]]; then # header line
                    [[ $line =~ ahead\ ([0-9]+) ]] && marks+=" $SYMBOL_GIT_PUSH${BASH_REMATCH[1]}"
                    [[ $line =~ behind\ ([0-9]+) ]] && marks+=" $SYMBOL_GIT_PULL${BASH_REMATCH[1]}"
                else # branch is modified if output contains more lines after the header line
                    marks="$SYMBOL_GIT_MODIFIED$marks"
                    break
                fi
            done < <($git_eng status --porcelain --branch 2>/dev/null)  # note the space between the two <

            # print the git branch segment without a trailing newline
            printf " %s%s" "$ref" "$marks"
        }

        ps1() {
            local symbol
            # Check the exit code of the previous command and display different
            # colors in the prompt accordingly.
            # shellcheck disable=SC2181 # no, we're checking somethink else's error code
            if [ $? -eq 0 ]; then
                symbol="${COLOR_SUCCESS}${_PS_SYMBOL}${RESET}"
            else
                symbol="${COLOR_FAILURE}${_PS_SYMBOL}${RESET}"
            fi

            local cwd="${COLOR_CWD}${POWERLINE_DIR}${RESET}"
            # Bash by default expands the content of PS1 unless promptvars is disabled.
            # We must use another layer of reference to prevent expanding any user
            # provided strings, which would cause security issues.
            # POC: https://github.com/njhartwell/pw3nage
            # Related fix in git-bash: https://github.com/git/git/blob/9d77b0405ce6b471cb5ce3a904368fc25e55643d/contrib/completion/git-prompt.sh#L324
            local git
            if shopt -q promptvars; then
                __powerline_git_info="$(__git_info)"
                git="$COLOR_GIT\${__powerline_git_info}$RESET"
            else
                # promptvars is disabled. Avoid creating unnecessary env var.
                git="$COLOR_GIT$(__git_info)$RESET"
            fi

            PS1="$cwd$git $symbol "
        }

        PROMPT_COMMAND="ps1${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    }

    __powerline
    unset __powerline
}

_traditional() {
    # For embedding git info in prompt; adapted from internet sources
    parse_git_branch() {
        # Want more glitz? see https://github.com/magicmonty/bash-git-prompt
        local ref
        ref=$(git symbolic-ref HEAD 2> /dev/null)
        echo "(""${ref#refs/heads/}"")"
    }

    # Embed working directory in prompt
    local HLITE="\[\033[0;96m\]" # High intensity cyan
    local YELLOW="\[\033[0;33m\]"
    local NONE="\[\033[0m\]"

    if [ "${BASH/*bash}" == "" ] && [ $EUID -ne 0 ]; then
        # Include simople hostname in ssh connections
        PS1="${HLITE}${SSH_CONNECTION:+${HOSTNAME%%[-.]*}} \W${YELLOW} \$(parse_git_branch)${NONE} $ "
    fi
}

_prompt_setup() {
    # Determine which of prompt mechanisms is available and initialize
    local exe
    [[ -z "$ZSH_VERSION" ]] && : # trap "set +x" RETURN && set -x

    for p in "${_PROMPT_SELECTIONS[@]}"; do
        exe=$(type "$p" 2>/dev/null | head -1)
        if [[ -n "$exe" ]]; then
            #exe=${exe//* /} # just the full path to the executable (or that it's a function)
            case "$exe" in
                (*powerline-go*)
                    [[ -z "$ZSH_VERSION" ]] && _bash_powerline-go
                    [[ -n "$ZSH_VERSION" ]] && _zsh_powerline-go
                    break
                    ;;
                (*starship*)
                    if [[ -z "$ZSH_VERSION" ]]; then
                        # I haven't figured out whether to use eat's own prompt handling
                        [[ "$INSIDE_EMACS" =~ .*eat.* ]] && \
                            printf "Using eat shell prompt annotation\n" && return
                        eval "$(starship init bash)"
                    else
                        eval "$(starship init zsh)"
                    fi
                    break
                    ;;
                (*bash_powerline*)
                    if [[ -z "$ZSH_VERSION" ]]; then
                        _bash_powerline
                    else
                        autoload -Uz vcs_info
                        if [[ $(type precmd &>/dev/null) -ne 0 ]] ; then
                            precmd () { vcs_info ; }
                            zstyle ':vcs_info:*' formats ' %s(%F{red}%b%f)'
                            # shellcheck disable=SC2034,SC2154 # used by zsh
                            PROMPT="%n@%m %? %d %F{red}%/%f$vcs_info_msg_0_ $_PS_SYMBOL "
                        fi
                    fi
                    break
                    ;;
                (*traditional*)
                    _traditional
                    ;;
                (*)
                    printf ""
                    break
                    ;;
            esac
        fi
    done
    [[ -z "$exe" ]] && printf "None of %s found for prompt\n" "${_PROMPT_SELECTIONS[*]}"
}

_color_setup() {
    # I use Tinted scripts https://github.com/tinted-theming/tinted-shell/blob/main/scripts/
    # YakShave: test/adopt https://github.com/tinted-theming/tinty
    local theme="${_THEME_DIR}/${_COLOR_THEME}"
    [[ -e "$theme" ]] && source "$theme"
}

_command_history_setup() {
    # Record all CLI work

    : ${_CLI_HISTORY:=~/.full_history}
    [[ -e "$_CLI_HISTORY" ]] || printf "Host PWD PID Timestamp           Cmd\n" > "${_CLI_HISTORY}"

    : "${HOSTNAME:=$(hostname -s)}" # insure HOSTNAME is set

    # Adapted from https://www.jefftk.com/p/logging-shell-history-in-zsh
    _full_history() {
        local _entry _pwd
        # declare -a _prefixes # ToDo replacements in addition to $HOME -> ~
        local HISTTIMEFORMAT="%Y-%m-%dT%H:%M:%S "
        if [[ -z "$ZSH_VERSION" ]]; then
            _entry="$(history 1)"
            _pwd="${PWD/#${HOME}/\~}"
        else
            _entry="$(history -t "$HISTTIMEFORMAT" -1)"
            _pwd="${PWD/#${HOME}/~}"
        fi
        _entry="${_entry/# *([0-9])  /}"  # remove history number and surrounding spaces
        printf "%s %s %s %s\n" "${HOSTNAME}" "${_pwd}" "$$" "${_entry}" \
               >> "${_CLI_HISTORY}"
    }

    # Run that (once) at the conclusion of each command
    # (extra checks prevent adding twice while debugging)
    if [[ -z "$ZSH_VERSION" ]]; then
        [[ ${PROMPT_COMMAND} =~ .*_full_history.* ]] || \
            PROMPT_COMMAND="${PROMPT_COMMAND}${PROMPT_COMMAND:+;}_full_history"
    else
        # shellcheck disable=SC2128 # This will be executed in zsh
        [[ ${precmd_functions} =~ .*_full_history.* ]] || \
            precmd_functions+=(_full_history)
    fi

    histgrep() {                # look for pattern in full history
        local matches=10
        if [[ "$#" == 0 ]]; then
            printf "Usage %s [max # entries] pattern\n" "${FUNCNAME[0]}"
            return
        elif [[ "$1" =~ ^[0-9]*$ ]]; then
            matches="$1" && shift
        fi
        # occurances of pattern in history
        grep "$@" "$_CLI_HISTORY" | tail -n "$matches"
        # ToDo: use rg/ripgrep if available
    }
}

# How shall the prompt be handled for this terminal type?
case $TERM in
    (dumb)  # i.e., emacs shell; see also .emacs.d/init_${SHELL}.sh
        _traditional
        export PAGER='cat'
        ;;
    (xterm*|dtterm*|linux|screen*|*truecolor*|*256*)
        _color_setup
        _prompt_setup
        ;;
    (*)
        printf "TERM %s not recognized, see %s\n" "$TERM" "${BASH_SOURCE[0]}"
        ;;
esac

_command_history_setup

# clean up: no need for these once sourced
_funcs=(_zsh_powerline-go _bash_powerline _bash_powerline-go _traditional _prompt_setup \
                          _color_setup
                          _command_history_setup)
unset -f "${_funcs[@]}" ; unset -v _funcs _PROMPT_DSELECTIONS _COLOR_THEME _THEME_DIR
