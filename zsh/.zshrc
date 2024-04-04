#!/usr/bin/env zsh
# zsh initialization, for e.g., exec zsh

# Uncomment to use the profiling module
# zmodload zsh/zprof
# then enter zload to see profiling info https://stackoverflow.com/a/58524231/1124740

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

# Additions to default path
path=(~/.local/bin ~/CM/Base/bin ~/CM/Base/Darwin $path)

# Homebrew completion; must be early in zsh initialization
if type brew &>/dev/null; then
    local _bp=$(brew --prefix)
    FPATH=${_bp}/share/zsh-completions:${_bp}/share/zsh/site-functions:$FPATH
    # compinit: insecure directories? fix: compaudit | xargs chmod 755
fi

# Can causes problems with functions that rely on emulate {ba,k}sh
autoload -Uz compinit
compinit

if type go &>/dev/null ; then
    GOROOT="$(go env GOROOT)" && export GOROOT
    GOPATH="$(go env GOPATH)" && export GOPATH
    path=($GOPATH $path)
fi

# External definitions I commonize with bash
DOTFILES=~/CM/dotfiles
if [[ "$ZSH_EVAL_CONTEXT" == "file" ]]; then
    # Source these only for really interactive shells

    # YakShaves:
    # check https://askubuntu.com/questions/1577/moving-from-bash-to-zsh lazy_load_from logic.
    # See man zshmisc's Autoloading Functions

    _debug=0
    lazy_load_from() { # args: script_source function_name [args]
        [[ $_debug -gt 0 ]] && printf "lazy_load_from %s\nfunckstack:%s\n" "$*" "$funcstack[*]"
        [[ $debugpwd -gt 1 ]] && set -x
        unfunction $funcstack[-1] # undefine the definition that got us here
        local this_dir=${${(%):-%x}:A:h}
        # Remove any bash optional lazy_load 'quiet' parameter
        if [[ "${@: -1}" == "quiet" ]]; then
            shift -p
        fi
        local to_source=$1 && shift # remove the source file argument
        source ${this_dir}/../$to_source "$@" # which are in parent in my set up
        emulate zsh  # blunt force reset
        [[ $_debug -gt 0 ]] && printf "re-calling %s %s" "$funcstack[1]" "$@"
        $funcstack[-1] "$@"
    }

    source ${DOTFILES}/shell-funcs.sh
    source ${DOTFILES}/path_add_remove.sh
    source ${DOTFILES}/less_termcap.sh
    source ${DOTFILES}/cli_prompt.sh
    source ${DOTFILES}/bash-brew.sh # issues with read - ask()?
    source ${DOTFILES}/bash-emacs.sh
    source ${DOTFILES}/bash-tmux.sh
    source ${DOTFILES}/enable_fzf.sh
    source ${DOTFILES}/misc-functions.sh # lazy loads from others
fi

# Unmodified external integrations
[[ -n "$ITERM_SESSION_ID" ]] && source ~/.iterm2/shell_integration.zsh
whence -w direnv >/dev/null && eval "$(direnv hook zsh)"

emulate zsh  # restore zsh functionality left over from any of above

# Interactive setup

set -o emacs
setopt CHASE_LINKS  # resolve symlinks for cd
setopt SHARE_HISTORY
