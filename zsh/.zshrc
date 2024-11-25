#!/usr/bin/env zsh
# shellcheck shell=bash # for what this is worth
# zsh initialization, for e.g., exec zsh

# Uncomment to use the profiling module
# zmodload zsh/zprof
# then enter zload to see profiling info https://stackoverflow.com/a/58524231/1124740

# shellcheck disable=SC2034 # zsh internals that ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

# shellcheck disable=SC2206 # zsh prepends to path differently
path=(~/.local/bin ~/CM/Base/bin ~/CM/Base/Darwin $path)

# Homebrew completion; must be early in zsh initialization
if type brew &>/dev/null; then
    # shellcheck disable=SC2168,SC2155 # zsh enables local at top level
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
    # shellcheck disable=SC2206,SC2128 # zsh prepends to path differently
    path=($GOPATH $path)
fi

# Remove /etc/zshrc_Apple_Terminal's command prompt function
# Note this will reportedly break session restoration too.
autoload -U add-zsh-hook
add-zsh-hook -d precmd update_terminal_cwd

# Suppress macOS' /etc/zshrc_Apple_Terminal shell sessions
export SHELL_SESSIONS_DISABLE=1

# External definitions I commonize with bash
DOTFILES=~/CM/dotfiles

if [[ "$ZSH_EVAL_CONTEXT" == "file" ]]; then

    # The following apply only for interactive shells.

    _define_from() {
        local file="$1"
        emulate zsh             # be sure we start from zsh
        [[ "$_zdbg" -gt 0 ]] && printf "sourcing %s\n" "${DOTFILES}/$file"
        source "${DOTFILES}"/"$file"
        emulate zsh             # reset any sourced emulation
    }

    # Some functions that are _define_from sources will have lazy load definitions, replaced on
    # first use - a holdover from the way the bash setup works. Here I source the true function
    # definitions.
    _zdbg=0
    lazy_load_from() { # args: script_source function_name [args]
        # shellcheck disable=2154 # funcstack is zsh's internal equivalent of bash's FUNCNAME
        [[ "$_zdbg" -gt 0 ]] && \
            printf "lazy_load_from %d args: %s\n" "$#@" "$*" && \
            printf "\tfuncstack %d elements: %s\n" "$#funcstack" "${funcstack[*]}"
        [[ "$_zdbg" -gt 1 ]] && set -x
        local funcname="${funcstack[2]}"
        unfunction "${funcstack[2]}" # undefine the definition that got us here
        # shellcheck disable=SC2199 # zsh syntax okay
        if [[ "${@: -1}" == "quiet" ]]; then
            # Remove optional lazy_load 'quiet' parameter leftover from bash implementation
            shift -p
        fi
        local to_source=$1 && shift         # remove the source file argument
        _define_from "$to_source"
        [[ "$_zdbg" -gt 0 ]] && printf "re-calling %s %s" "${funcname}" "$@"
        eval "$funcname $*"
        [[ "$_zdbg" -gt 1 ]] && set +x
    }

    #
    files=(
        "shell-funcs.sh"        # should be first as other may use
        "path_add_remove.sh"    # PATH manipulation
        "less_termcap.sh"       # PAGER setup
        "cli_prompt.sh"         # prompt glitz
        "brew-integration.sh"
        "emacsclient.sh"
        "bash-tmux.sh"
        "enable_fzf.sh"
        "misc-functions.sh"     # includes lazy load definitions from other sources
        "enable_direnv.sh"      # should be near/at end
        "iterm_integration.sh"  # must be after direnv
    )
    for f in "${files[@]}"; do
        _define_from "$f"
    done

    # Options
    bindkey -e # recommended over set -o emacs
    setopt chaselinks # similar to set -o physical
    setopt noclobber

    cd . || return     # NB: not builtin cd
    # Side-effect: lazy load function definitions for overrides and initialize tab title & prompt;
    # this is way too obscure.

    unhash -f _define_from
fi

emulate zsh  # restore zsh functionality left over from any of above

# Interactive setup

set -o emacs
setopt CHASE_LINKS  # resolve symlinks for cd
setopt SHARE_HISTORY
