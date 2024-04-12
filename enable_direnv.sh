#!/usr/bin/env bash
# enable_direnv support

type direnv &>/dev/null || return 1

if [[ -n "$BASH_VERSION" ]]; then
    # See https://emacs.stackexchange.com/q/2573/5146 wrt Emacs shell-mode
    # Note old bash version syntax for macOS native bash compatibility
    # Avoid macOS / direnv / iTerm conflict
    [[ -z "${OSTYPE/darwin*}" && -n "${ITERM_SESSION_ID}" ]] && \
        PROMPT_COMMAND="${PROMPT_COMMAND}${PROMPT_COMMAND:+;}unset XPC_SERVICE_NAME;"

    eval "$(direnv hook bash)"
elif [[ -n "$ZSH_VERSION" ]]; then
    eval "$(direnv hook zsh )"
fi
