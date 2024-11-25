#!/usr/bin/env bash
# Some of my most frequently used crutches relate to directory movement
# The `up` functionality relies on/is adapted from
# # https://github.com/shannonmoeller/up
# These are now mostly compatible with zsh

# shellcheck disable=SC2154  # don't warn of bash / zsh compatibility
[[ -z "$ZSH_VERSION" && $_ != "$0" ]] || \
    [[ -n "$ZSH_VERSION" && "${zsh_eval_context[-1]}" = "file" ]] || \
    { echo "This file must be sourced to be useful."; exit 1; }

[ -n "$ZSH_VERSION" ] || shopt -s extglob  # I think this is required, I'm too lazy to recall why

# Remember the current directory as $t and copy it to the clipboard
sett () {
    t="$PWD"
    case "${OSTYPE}" in
        (darwin*)
            printf "%s" "$PWD" | pbcopy
            ;;
    esac
    echo "t=$t -> clipboard"
}

# pwd on steroids - echo numbered trailing components of directory stack
pw () {
    [ -n "$ZSH_VERSION" ] && DIRSTACK=("$PWD" "${dirstack[@]}")
    typeset d n=0
    for d in "${DIRSTACK[@]}"; do
        printf "%i) %s " "${n}" "${d##*/}"
        ((n=n+1))
    done
    printf "\n"
}

# Show complete (full path) directory stack (unless pwd has options)
pwd () {
    case ${#1} in
        (0) dirs -l ;;
        (*) command pwd "$@" ;;
    esac
}

# functions for changing directories while maintaining breadcrumbs

set_tab_title () {
    _last_tab_title=${_current_tab_title:=""}
    case "$TERM" in
        (xterm*|dtterm*|screen*)
            echo -ne '\033]0;'"${*}"'\007'
            ;;
        (*) ;;
    esac
    _current_tab_title="$*"
}

update_title_with_directory () {
    [ -n "$ZSH_VERSION" ] && emulate -L ksh
    # Window title remembers first, non-Home, and current directory
    # Since the first is generally why I created this window/tab in the first place
    local prefix
    #[ "${ZSH_VERSION}" == "" ] && trap "set +x" RETURN && set -x # bash function debugging
    #[ "${ZSH_VERSION}" != "" ] && trap "set +x" EXIT && set -x # zsh function debugging
    if [ -z "${INITIAL_WD}" ]; then
        [ "${ZSH_VERSION}" == "" ] && INITIAL_WD=${*%/} || INITIAL_WD='.' # Ignore trailing /
        [ "${INITIAL_WD}" == '.' ] && INITIAL_WD="${PWD}"
        if [ "${INITIAL_WD}" == "${HOME}" ]; then
            unset INITIAL_WD
        else
            INITIAL_WD=${INITIAL_WD##*/} # initial working directory = the basename of the target the first time shell executed this
            # not necessarily ${PWD} since I tend to use home directory symlinks
            prefix="${INITIAL_WD}:"
        fi
    elif [ $# ]; then
        prefix="${INITIAL_WD}:"
    else
        prefix="${SSH_CONNECTION:+${HOSTNAME%%[-.]*}:}"
    fi
    set_tab_title "${prefix}${PWD##*/}"
}

update_term_title () {
    update_title_with_directory "$@"
}

cd () {

    # cd + show current directory in titlebar
    case $# in
        (0) builtin cd "$@" || return ;;
        (1)
            case ${1} in
                (^*) # integrate up functionality
                    local arg
                    arg="${1/\^/}"
                    shift
                    up "${arg:-1}" "$*"
                    ;;
                (\?|-\?|-h)
                    printf "\
        cd ^# - change to directory # up the tree
        cd - - change to previous directory
        cd path - change to path
	%s remembered as \$l == ~-
" "$OLDPWD"
                     ;;
                (*) builtin cd "$@" || return ;;
            esac
            ;;
        (*) builtin cd "$@" || return ;;
    esac
    l="$OLDPWD"
    update_term_title "$@"
}

pd () {
    # pushd + reflect change in titlebar
    #[ -n "$ZSH_VERSION" ] && trap "set +x" EXIT && set -x
    case $# in
        (0) pushd || return ;;
        (*)
            case ${1} in
                ([0-9]*) # treat bare digits as the equivalent of +digit
                    pushd "+${*}" || return ;;
                (^*) # integrate up functionality
                    #trap "set +x" RETURN && set -x # function debugging
                    local arg
                    arg="${1/\^/}"
                    shift
                    pushd -n "${PWD}" &>/dev/null # quietly duplicate the current PWD on DIRSTACK
                    up "${arg:-1}" "$*"
                    ;;
                (\?|-\?|-h)
                    printf "\
        pd # - swap current directory with dirstack entry #
        pd ^# - push $PWD on dirstack and go up #
        pd path - push $PWD on dirstack and make path curent

	%s remembered as \$l == ~-
" "$OLDPWD"
                    ;;
                (*) pushd "$@" || return ;;
            esac
    esac
    l="$OLDPWD"                 # remember last directory (equivalent to ~-)
    update_term_title "$PWD"
}

cr () {
    # Reset term tab prefix and cd to reflect that change
    unset INITIAL_WD
    cd "$@" || return
}

pop () {
    # popd + reflect change in titlebar
    case ${#1} in
        (0) popd || return ;;
        (*) popd "$@" || return ;;
    esac
    # shellcheck disable=SC2034 # The point is to have a single letter variable for OLDPWD
    l="$OLDPWD"
    update_term_title "$PWD"
}

dp () {
    # directory previous - same as cd - or cd ~-
    cd "${OLDPWD}" || return
}

up () {
    # up is adapted from external sources
    local __SCRIPT; __SCRIPT='up_directory.sh'
    if [ -z "$ZSH_VERSION" ]; then
        # On first call, replace this with the adapted version
        __SCRIPT="$(command cd -P "$(dirname "${BASH_SOURCE[0]}")" && command pwd -P)/${__SCRIPT}"
    else
        #__SCRIPT="${0:a:h}/${__SCRIPT}" # Common wisdom is wrong for at least .zsh*
        # shellcheck disable=SC2296,SC2086  # since this is zsh interpreted
        __SCRIPT="$(dirname ${(%):-%x})/${__SCRIPT}"
    fi
    . "${__SCRIPT}"
    # then call the replacement version
    up "$1"
}

case "$TERM_PROGRAM" in
    (*Term*)                    # does this handle all the display applications?
        ssh () {
            # restore title after ssh ends
            command -p ssh "$@"
            set_tab_title "$_last_tab_title"
        }
        ;;
    (*)
        ;;
esac

if [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
    # wezterm's working directory handling interferes with my personal preference
    cd ~ || return
fi
# Initialize titlebar as this is sourced
update_term_title "$@"
