#!/usr/bin/env bash
# path_add_remove.sh - PATH manipulation

type vprintf &>/dev/null || _define_from "shell_funcs.sh"

add_to_my_path () {
    # Add arguments to path and remove any duplicates
    ppath "${@}"
    remove_path_duplicates
}

remove_path_duplicates() {
    # Implemented without the associative arrays to be macOS /bin/bash compatible
    [[ -n "${ZSH_VERSION}" ]] && emulate -L ksh
    local oldIFS newPath p
    oldIFS=$IFS
    IFS=:
    newPath=

    declare -a components
    declare -i index
    for p in $PATH; do
        for (( i=0 ; i < index ; i++ )) ; do
            if [[ -n "$p" && "${components[$i]}" == "$p" ]]; then
                continue 2
            fi
        done
        newPath=${newPath:+$newPath:}$p
        components[index]=$p
        (( index++ ))
    done
    [[ "$newPath" != "$PATH" ]] && \
        vprintf 2 "\nDeduped PATH:\n%s\nwas:\n%s\n" "${newPath//:/$'\n'}" "${PATH//:/$'\n'}"
    PATH=$newPath
    IFS=$oldIFS
}

ppath () {
    # prepend directories given as arguments to PATH
    vprintf 2 "%d args, prepend: %s" "${#@}" "${*}"
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

    for d ; do
        if [ -d "$d" ] ; then
            PATH=$d:$PATH
        fi
    done
    vprintf 2 "PATH: %s\n" "$PATH"
}

rpath () {
    # remove argument directories from PATH
    vprintf 2 "%d args remove: %s" "${#@}" "${*}"
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
    vprintf 2 "PATH: %s\n" "$PATH"
}
