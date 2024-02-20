#!/usr/bin/env bash
# shell functions used by other dotfile shell initializations

is_sourced() { # https://stackoverflow.com/a/28776166/1124740
    if [[ -n "$ZSH_VERSION" ]]; then
        case $ZSH_EVAL_CONTEXT in (*:file:*) return 0 ;; esac
    else  # Add additional POSIX-compatible shell names here, if needed.
        case ${0##*/} in (dash|-dash|bash|-bash|ksh|-ksh|sh|-sh) return 0 ;; esac
    fi
    [ -n "${_verbose}" ] && echo " must be sourced to be useful."
    return 1  # NOT sourced.
}

is_defined() {
    type "$@" >/dev/null 2>&1
}
