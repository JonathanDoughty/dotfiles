#!/usr/bin/env bash

ITERM_PATH=${HOME}/.iterm2  # Note; non-standard path

if [[ -n "$BASH_VERSION" ]]; then
    # iTerm integration (must be after direnv PROMPT_COMMAND setup)
    if [[ -n "$ITERM_SESSION_ID" && \
          -r "${ITERM_PATH}/shell_integration.bash" ]]
    then
        add_to_my_path "${ITERM_PATH}"

        _PROMPT_COMMAND="${PROMPT_COMMAND}"
        # iterm shell integration interferes with other uses of PROMPT_COMMAND
        # see https://gitlab.com/gnachman/iterm2/-/issues/7961
        type _direnv_hook &>/dev/null && precmd_functions+=(_direnv_hook)
        # shellcheck disable=SC1091
        . "${ITERM_PATH}/shell_integration.bash"
    fi
else
    : # Haven't bothered with zsh yet
fi
unset ITERM_PATH
