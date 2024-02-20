#!/usr/bin/env zsh
# zsh environment variables - used for every zsh shell

#printf "This is %s via %s (%s)\n" "$SHELL" "$0" "${BASH_SOURCE[0]:-${(%):-%x}}"

# Don't clutter ${HOME}
if [[ -d ${HOME}/CM/dotfiles/zsh ]]; then
    export ZDOTDIR=${HOME}/CM/dotfiles/zsh
fi
# Ensure that a non-login, non-interactive shell has a defined environment.
# Why would that non-standard behavoir be desirable?
#if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
#  source "${ZDOTDIR:-$HOME}/.zprofile"
#fi
