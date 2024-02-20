#!/usr/bin/env bash
# path_add_remove.sh
# PATH manipulation

( _verbose=1 && is_sourced )

# Set up standard paths to include only existing directories without dups
# If a path is already in PATH, move it to the front
add_to_my_path () {
    local d
    args="$*" oldIFS=$IFS IFS=' :'
    for d in $args; do
        if [[ -d "$d" ]]; then # candidate exists
            if [[ "${PATH}" != "${PATH/:${d}/}" ]]; then
                # $d in PATH (but not at front)
                PATH=${PATH/:${d}/}  # remove previous
            fi
            PATH=$d:$PATH
        fi
    done
    PATH=${PATH//::/:}      # remove any duplicate :
    PATH=${PATH%:}          # trim any trailing :
    IFS=$oldIFS
}

ppath () {
    # prepend directory given as argument to PATH
    typeset d
    for d do
        if [ -d "$d" ] ; then
            PATH=$d:$PATH
        fi
    done
}

rpath () {
    # remove directory given as argument from PATH
    typeset rmdir=$1 tIFS=$IFS d tPATH
    IFS=:
    set "$PATH"
    for d do
        if [ "$rmdir" != "$d" ] ; then
            tPATH=${tPATH:+"$tPATH:"}${d}
        fi
    done
    PATH=$tPATH
    IFS=$tIFS
    unset tPATH tIFS rmdir d
}
