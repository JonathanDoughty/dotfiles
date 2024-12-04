#!/usr/bin/env bash
# enable_fzf - fuzzy finder configuration

type fzf &>/dev/null || return 1 # skip if fzf is unavailable
is_sourced || return 1          # from shell-funcs.sh

# Control whether my preferences override normal fzf behavior
_override_completions=1
_override_bindings=1
_override_options=1

# --[shell] option used below added in version 49; this breaks when fzf hits 1.0
fzf --version | awk -F . '{ if( $2 > 48) exit 0 ; else exit 1; }' || return 1

if [[ ${BASH_VERSINFO[0]} -gt 3 ]]; then # in bash's more recent than macOS's
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
        if false ; then
            # This recommended setup causes shell start issues for me
            # See https://github.com/junegunn/fzf/issues/1750
            RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
            INITIAL_QUERY=""
            FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
                               fzf --bind "change:reload:$RG_PREFIX {q} || true" \
                               --ansi --phony --query "$INITIAL_QUERY"
        else
            export FZF_DEFAULT_COMMAND='rg --files --hidden --smartcase --glob "!.git/*"'
            #export FZF_DEFAULT_COMMAND='rg --files --smartcase'
        fi
    fi
fi

# Handy functions from fzf ChangeLog https://github.com/junegunn/fzf/blob/master/CHANGELOG.md:

# Display all bash/zsh functions, highlighted. Stop with ctrl-c, ctrl-g, ctrl-q, esc
shell_functions () {
    declare -f | perl -0777 -pe 's/^}\n/}\0/gm' |
        bat --plain --language bash --color always |
        fzf --read0 --ansi --reverse --multi --highlight-line --gap
}

# Page output, e.g., from long ripgrep results
fpg () {
    perl -0777 -pe 's/\n\n/\n\0/gm' |
        fzf --read0 --ansi --multi --highlight-line --reverse --tmux 70%
}

unset _override_completions _override_bindings _override_options
