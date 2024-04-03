#!/usr/bin/env bash
# path_add_remove.sh - PATH manipulation

type vprintf &>/dev/null || _define_from "shell_funcs.sh"

add_to_my_path () {
    # Add arguments to path and remove any duplicates
    ppath "${@}"
    remove_path_duplicates
}

remove_path_duplicates() {
    # via https://www.baeldung.com/linux/remove-paths-from-path-variable
    local oldIFS newPath p
    oldIFS=$IFS
    IFS=:
    newPath=
    declare -A ALREADY_IN_PATH
    for p in $PATH; do
        if [[ -n "$p" && -z "${ALREADY_IN_PATH[$p]}" ]]; then
            newPath=${newPath:+$newPath:}$p
            ALREADY_IN_PATH[$p]=$p
        fi
    done
    IFS=$oldIFS
    vprintf 2 "New PATH %s was %s" "${newPath}" "$PATH"
    PATH=$newPath
}

ppath () {
    # prepend directories given as arguments to PATH
    vprintf 2 "%d args: %s" "${#@}" "${*}"
    local code n d
    # POSIXly reverse arguments (so that first of arguments is first in eventual PATH)
    # via https://unix.stackexchange.com/a/467924/13887
    code='set --'
    n=$#
    while [ "$n" -gt 0 ]; do
        code="$code \"\${$n}\""
        n=$((n - 1))
    done
    eval "$code"

    # shellcheck disable=SC2068
    for d ; do
        if [ -d "$d" ] ; then
            PATH=$d:$PATH
        fi
    done
}

rpath () {
    # remove argument directories from PATH
    vprintf 2 "%d args: %s" "${#@}" "${*}"
    local oldIFS=$IFS r d newPath
    IFS=:
    for d in $PATH; do
        for r in "$@"; do
            if [ "$r" == "$d" ] ; then
                continue 2
            fi
        done
        newPath=${newPath:+"$newPath:"}${d}
    done
    IFS=$oldIFS
    PATH=$newPath
}
