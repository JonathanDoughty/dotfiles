#!/usr/bin/env bash
# shell functions used by other dotfile shell initializations

is_sourced() {
    # Was the calling script file sourced?
    # Note caveats in https://stackoverflow.com/a/28776166/1124740
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
    # When _verbose >= optional first arg level output remainder with calling function to stderr
    # Suppressing / restoring execution tracing
    {  _vprintf_flags="$-"; set +x; \
       trap 'case "$_vprintf_flags" in (*x*) unset _vprintf_flags; set -x ;; (*) unset _vprintf_flags ;; esac' RETURN EXIT; \
       } 2> /dev/null
    local level fmt func
    # Inherit an outer _verbose; like declare -I but in a zsh compatible way; ignoring if unset (reset on RETURN)
    set +u && [[ -z "$_verbose" ]] && local _verbose="${VERBOSE:--1}"
    if [[ "$1" =~ [[:digit:]] ]]; then
        level=$1 fmt="%s $2\n" && shift 2
    else
        level=0 fmt="%s $1\n" && shift 1
    fi
    func="[${FUNCNAME[1]}]:"
    if [[ "$func" == "maybe" ]]; then
        # In this case we want the caller
        func="${FUNCNAME[2]}"
        if [[ $DRY_RUN -ne 0 ]]; then
            # ... and for dry runs indicate it is not being executed
            func="skipped: $func"
        fi
    fi
    if [[ "$_verbose" -ge "$level" ]]; then
        # shellcheck disable=SC2059 # the point is to pass in fmt
        printf "$fmt" "$func" "$@" 1>&2 ||
            printf "Error: level %s fmt %s args:%s\n" "$level" "$fmt" "$@" 1>&2
    fi
}

maybe () {
    # print and - unless this is a dry run - eval arguments
    local cmd
    declare -i level=3          # normally only print cmd at the most verbose
    if [[ $1 =~ [[:digit:]] ]]; then
        # Treat leading digits as desired verbosity level, not as part of command
        level=$1
        shift
    fi
    cmd=( "$@" )
    if [[ $DRY_RUN -eq 0 ]]; then
        vprintf $level "%s" "${cmd[*]}"
        eval "${cmd[*]}"
    else
        vprintf "%s" "${cmd[*]}"
    fi
}
