#!/usr/bin/env bash
# enable_direnv support

type direnv &>/dev/null || return 1

_set_umask_via_direnv () {
    # direnv only exports environment changes, create a work around
    # see https://github.com/direnv/direnv/issues/509
    # and https://gist.github.com/laggardkernel/38566f4473068c065f1a1ef15e6e1b4a

    # Record the default umask (set in .bashrc) value on the 1st run
    [[ -z $DEFAULT_UMASK ]] && DEFAULT_UMASK="$(builtin umask)" && export DEFAULT_UMASK

    if [[ -n $UMASK ]]; then
        umask "$UMASK"
    else
        umask "$DEFAULT_UMASK"
    fi
}

if [[ -n "$BASH_VERSION" ]]; then
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_set_umask_via_direnv"

    # See https://emacs.stackexchange.com/q/2573/5146 wrt Emacs shell-mode
    # Note old bash version syntax for macOS native bash compatibility
    # Avoid macOS / direnv / iTerm conflict
    [[ -z "${OSTYPE/darwin*}" && -n "${ITERM_SESSION_ID}" ]] && \
        PROMPT_COMMAND="${PROMPT_COMMAND}:+${PROMPT_COMMAND;}unset XPC_SERVICE_NAME"

    eval "$(direnv hook bash)"
elif [[ -n "$ZSH_VERSION" ]]; then
    add-zsh-hook chpwd _set_umask_via_direnv
    #add-zsh-hook precmd _umask_hook # also run at startup; seems unnecessary

    eval "$(direnv hook zsh )"
fi
