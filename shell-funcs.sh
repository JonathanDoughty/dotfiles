#!/usr/bin/env bash
# shell functions used by other dotfile shell initializations

# Don't override earlier settings
[[ -z "$VERBOSE" ]] && declare -i VERBOSE=0
[[ -z "$DRY_RUN" ]] && declare -i DRY_RUN=0

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
    # Suppressing / restoring active execution tracing in this function
    {  _vflags="$-"; set +x; \
       trap 'case "$_vflags" in (*x*) unset _vflags; set -x ;; (*) unset _vflags ;; esac' RETURN EXIT; \
       } 2>/dev/null
    local level fmt func
    # Inherit an outer _verbose; like declare -I but in a zsh compatible way;
    # ignoring if unset (-u will be reset on RETURN via _vflags)
    set +u && [[ -z "$_verbose" ]] && local _verbose="${VERBOSE:--1}"
    if [[ "$1" =~ ^[[:digit:]]+$ ]]; then
        level=$1 fmt="%s $2\n" && shift 2
    else
        level=0 fmt="%s $1\n" && shift 1
    fi
    func="[${FUNCNAME[1]}]:"
    if [[ "$func" == "maybe" ]]; then
        # In this case we want the caller
        func="${FUNCNAME[2]}"
        if [[ "${DRY_RUN}" -gt 0 ]]; then
            # ... and for dry runs indicate execution was skipped
            func="skipped: $func"
        fi
    fi
    if [[ "$_verbose" -ge "$level" ]]; then
        # shellcheck disable=SC2059 # the point is to pass fmt as an argument
        printf "$fmt" "$func" "$@" 1>&2 ||
            printf "Error: level %s fmt %s args:%s\n" "$level" "$fmt" "$@" 1>&2
    fi
}

maybe () {
    # Print and, if this is not a dry run, eval arguments
    # Note: if the arguments include pipes then the entire argument sequence must be quoted
    local cmd status
    declare -i level=3          # unless specified otherwise print cmd only at the most verbose
    if [[ $1 =~ ^[[:digit:]]+$ ]]; then
        # Treat digits-only first argument as verbosity level, not as part of command
        level=$1
        shift
    fi
    cmd=( "$@" )
    if [[ "${DRY_RUN:-0}" == "0" ]]; then
        # DRY_RUN isn't set or is 0: evaluate arguments in a sub-shell, capturing output
        vprintf $level "%s" "${cmd[*]}"
        local cmd_output tmp_output
        tmp_output=/tmp/maybe_eval.$$
        touch tmp_output        # insure existence
        (
            #printf "Start\n"
            eval "${cmd[*]}" 
            #printf "End\n"
            exit "${PIPESTATUS[0]}"
        ) 1>|"$tmp_output" 2>&1 # overwrite previous if any
        status=$?
        cmd_output=$(tr -d '\0' <"${tmp_output}")
        [[ "$level" -ge 3 ]] || command rm -f "$tmp_output" # clean up unless really verbose
        status=$?
        if [[ ! $? ]]; then
            vprintf "%s returned %d output:%s" "${cmd[*]}" "$status" "$cmd_output"
        fi
    else                        # dry run: print what would be executed
        vprintf "%s" "${cmd[*]}"
    fi
    if [[ ${#cmd_output} -ne 0 ]]; then
        echo "$cmd_output"
    fi
    return $status
}

access_keys() {
    if type keychain &>/dev/null; then
        # Access keys from agent
        eval "$(keychain -q --noask --eval id_rsa)"
        vprintf 1 "%d keys available" "$(keychain --list | sed 's/^.*\///' | wc -l)"
    fi
}
