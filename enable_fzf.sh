#!/usr/bin/env bash
# enable_fzf - fuzzy finder configuration

[[ $_ != "$0" ]] || { printf "%s must be sourced to be useful." "$0"; exit 1; }
type fzf &>/dev/null || return 1

# Control whether my preferences override normal fzf behavior
_override_completions=1
_override_bindings=1
_override_options=1

# Note: I use a patched version of fzf linked from ~/.local/bin
# to avoid complaints related to https://github.com/junegunn/fzf/issues/3721
if [[ ${BASH_VERSINFO[0]} -gt 3 ]]; then # in bash's more recent than macOS's
    # For further debugging
    #eval "$(${FZF_EXE:-fzf} --bash | tee fzf_bash"${_fzf_debug}".sh)"
    eval "$(fzf --bash)"
elif [[ -n "$ZSH_VERSION" ]]; then
    eval "$(fzf --zsh)"
fi

if [[ $_override_completions -gt 0 ]]; then
    # Add support for additional fzf completions
    _fzf_comprun() {
        # https://pragmaticpineapple.com/four-useful-fzf-tricks-for-your-terminal/
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
fi

if [[ $_override_bindings -gt 0 ]]; then
    if [[ ${BASH_VERSINFO[0]} -gt 3 ]]; then # in bash's more recent than macOS's
        bind '"\C-t": transpose-chars'
        #bind -m emacs-standard -x '"\C-t":transpose-chars'
        #bind '"\C-f": fzf-file-widget'
        bind -m emacs-standard -x '"\C-f":fzf-file-widget'
    elif [[ -n ${ZSH_VERSION} ]]; then
        bindkey -M emacs '^F' fzf-file-widget
        bindkey -M emacs '^T' transpose-chars
    fi
fi

if [[ $_override_options -gt 0 ]]; then
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
fi

unset _override_completions _override_bindings _override_options
