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

# Remove /etc/zshrc_Apple_Terminal's command prompt function
# Note this will reportedly break session restoration too
autoload -U add-zsh-hook
add-zsh-hook -d precmd update_terminal_cwd

# Suppress macOS' /etc/zshrc_Apple_Terminal shell sessions
export SHELL_SESSIONS_DISABLE=1

# External definitions I commonize with bash
DOTFILES=~/CM/dotfiles

if [[ "$ZSH_EVAL_CONTEXT" == "file" ]]; then
    # The following apply only for interactive shells

    # Some of the following will result in functions that will be lazy loaded on first use
    _debug=0
    lazy_load_from() { # args: script_source function_name [args]
        [[ $_debug -gt 0 ]] && printf "lazy_load_from %s\nfuncstack:%s\n" "$*" "$funcstack[*]"
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

    _define_from() {
        local file="$1"
        emulate zsh             # be sure we start from zsh
        [[ $_debug -gt 0 ]] && printf "sourcing %s\n" "${DOTFILES}/$file"
        source ${DOTFILES}/$file
    }

    #
    files=(
        "shell-funcs.sh"        # should be first as other may use`
        "path_add_remove.sh"    # PATH manipulation
        "less_termcap.sh"       # PAGER setup
        "cli_prompt.sh"         # prompt glitz
        "bash-brew.sh"
        "bash-emacs.sh"
        "bash-tmux.sh"
        "enable_fzf.sh"
        "misc-functions.sh"     # includes lazy loads from others
        "enable_direnv.sh"      # should be near/at end
        "iterm_integration.sh"  # must be after direnv
    )
    for f in "${files[@]}"; do
        _define_from "$f"
    done

    unhash -f _define_from
fi

emulate zsh  # restore zsh functionality left over from any of above

# Interactive setup

set -o emacs
setopt CHASE_LINKS  # resolve symlinks for cd
setopt SHARE_HISTORY
