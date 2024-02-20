#!/usr/bin/env bash
# enable_fzf - fuzzy finder config

[[ $_ != "$0" ]] || { printf "%s must be sourced to be useful." "$0"; exit 1; }
# Silently exit unless brew is present - since brew is how I install fzf
type brew 1>/dev/null 2>&1 || return 1
type fzf 1>/dev/null 2>&1 || return 1

HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(brew --prefix)}"  # repeated $(brew --prefix) is slow according to bash_profile.py

# Adapted from /usr/local/opt/fzf/install generated ~/.fzf_bash

_fzf_comprun() {
    # https://pragmaticpineapple.com/four-useful-fzf-tricks-for-your-terminal/
    # Real source is https://github.com/junegunn/fzf#fuzzy-completion-for-bash-and-zsh
    local command=$1
    shift
    case "$command" in
        (cd)
            fzf "$@" --preview 'tree -C {} | head -200' ;;
        (export|unset)
            fzf "$@" --preview "eval 'echo \$'{}" ;;
        (ssh)
            fzf "$@" --preview 'dig {}' ;;
        (*)
            fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'
            # alternate fallback: fzf "$@"
            ;;
    esac
}

# Completion init can take seconds to execute; does it add value I'll miss?
# shellcheck disable=SC1090 # Auto-completion for {bash,zsh}
[[ $- == *i* ]] && source "${HOMEBREW_PREFIX}/opt/fzf/shell/completion.${0##*[/-]}"

# shellcheck disable=SC1090  # key bindings for {bash,zsh}
source "${HOMEBREW_PREFIX}/opt/fzf/shell/key-bindings.${0##*[/-]}"
if [[ ${BASH_VERSINFO[0]} -gt 3 ]]; then # in bash's more recent than macOS's
    bind -m emacs-standard -x '"\C-t": transpose-chars'
    bind -m emacs-standard -x '"\C-f": fzf-file-widget'
elif [[ -n ${ZSH_VERSION} ]]; then
    bindkey -M emacs '^F' fzf-file-widget
    bindkey -M emacs '^T' transpose-chars
fi

# Other preferred fzf options
export FZF_CTRL_T_OPTS="--select-1 --exit-0"
#export FZF_COMPLETION_TRIGGER='~~'
if [[ $(type -f fd 2>/dev/null) ]]; then
    export FZF_DEFAULT_COMMAND='fd --type f --color=never'
    export FZF_ALT_C_COMMAND='fd --type d . --color=never'
elif [[ $(type -f rg 2>/dev/null) ]]; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --smartcase --glob "!.git/*"'
    #export FZF_DEFAULT_COMMAND='rg --files --smartcase'
fi
