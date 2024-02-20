#!/usr/bin/env bash
# fancy up the command line prompt
# Most of this now uses https://github.com/justjanne/powerline-go if present
# else, for bash, use adaptation of https://github.com/riobard/bash-powerline

# Order matters, at least wrt bash and the -modules* lines
_PLG_OPTS="
        -mode patched -theme default -max-width 30
        -shell autodetect
        -cwd-mode fancy -cwd-max-depth 2
        -modules host,ssh,cwd,perms,exit,shell-var
        -modules-right venv,git,direnv
        -hostname-only-if-ssh
        -git-mode fancy
        -path-aliases /Volumes/CM/Active=CM
"
if [[ -z "$_PS_SYMBOL" ]]; then
    case "$(uname)" in
        (Darwin)   _PS_SYMBOL='' ;; # '' broken in some nerdfonts; non-proprietary alternative: '⌘'
        (Linux)    _PS_SYMBOL='$' ;;
        (*)        _PS_SYMBOL='%' ;;
    esac
    export _PS_SYMBOL
fi
if [[ -n "${BASH_VERSION}" ]]; then
    _PLG_EXE="$(type -p powerline-go)"
    # shellcheck disable=SC2116,SC2086 # not useless: collapse spaces (and removes tabs, newlines, returns)
    _PLG_OPTS="$(echo ${_PLG_OPTS//[$'\t\r\n']/})"
    # Bash doesn't support -modules-right, collapse those into modules
    _PLG_OPTS="${_PLG_OPTS/ -modules-right /,}"
    # and as long as that's the case, push powerline to a newline, increasing the max width
    _PLG_OPTS="${_PLG_OPTS/-max-width [0-9][0-9]/-max-width 50 -newline}"
    # Replace unused root indicator with OS unique _PS_SYMBOL
    _PLG_OPTS="${_PLG_OPTS/-shell autodetect/-shell-var _PS_SYMBOL}"
elif [[ -n "${ZSH_VERSION}" ]]; then
    _PLG_EXE="$(whence powerline-go)"
    _PLG_OPTS="${_PLG_OPTS/-shell autodetect/-shell-var _PS_SYMBOL}"
fi

_bash_powerline-go() {
    _update_ps1 () {
        # shellcheck disable=2086 # we want word splitting
        eval "$("${_PLG_EXE}" -eval ${_PLG_OPTS} -error $?)"
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
    # Adapted from https://github.com/justjanne/powerline-go
    [[ -e "${_PLG_EXE}" ]] || return

    function powerline_precmd() {
        # shellcheck disable=2086 # we want word splitting
        eval "$("${_PLG_EXE}" -eval ${=_PLG_OPTS} -error $?)"
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
        # Colorscheme
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

[[ -n "${ZSH_VERSION}" ]] && emulate -L bash
: "${OS:=$(uname -s)}"
if [[ "${OS/*Darwin*/}" == "" && "${TERM_PROGRAM}" != "including_Apple_Terminal" ]]; then
   if [ -n "$ZSH_VERSION" ]; then
       _zsh_powerline-go
   elif [ -n "$BASH_VERSION" ]; then
       if [[ -e "$_PLG_EXE" ]]; then
           _bash_powerline-go
       else
           _bash_powerline
       fi
   fi
else
    POWERLINE_GIT=0
    _bash_powerline
fi
[[ -n "$BASH_VERSION" ]] && unset -f _zsh_powerline-go _bash_powerline _bash_powerline-go
[[ -n "$ZSH_VERSION" ]] && unhash -f _zsh_powerline-go _bash_powerline _bash_powerline-go
