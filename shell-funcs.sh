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
    type "$@" &>/dev/null
}

vprintf () {
    local level=$1 fmt="[%s]: ${2}\n" && shift 2
    local verbosity=${_verbose:--1}
    # shellcheck disable=SC2059 # the point is to pass in fmt
    [[ $verbosity -ge $level ]] && ( printf "$fmt" "${FUNCNAME[1]}" "$@" 1>&2 || \
            printf "Error: level %s fmt %s args:%s\n" "$level" "$fmt" "$@" 1>&2 )
}
