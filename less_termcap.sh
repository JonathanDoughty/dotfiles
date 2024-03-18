#!/usr/bin/env bash
# less_termcap - set up functions & colors for PAGERs: bat / more / less / lesspipe

# shellcheck disable=SC2154  # don't warn of bash / zsh compatibility
[[ -z "$ZSH_VERSION" && $_ != "$0" ]] || \
    [[ -n "$ZSH_VERSION" && "${zsh_eval_context[-1]}" = "file" ]] || \
    { echo "This file must be sourced to be useful."; exit 1; }

# Avoid some recent git dependence on less and friends
# Works for diff, break log
#export GIT_PAGER=cat

less_exports () {
    if command -v lesspipe >/dev/null; then
        eval "$(SHELL=/bin/sh lesspipe)"
    elif [ -f "${HOME}/.lessfilter" ]; then
        # Leverage the same lesspipe extension mechanism
        export LESSOPEN="|${HOME}/.lessfilter %s"
    fi
    # https://stackoverflow.com/a/19871578/1124740 warns about
    # +Gg for large files
    export LESS="-F -R -s -M +Gg"
    export LESSHISTFILE=/dev/null
}

if  command -v bat >/dev/null; then
    more () { bat "$@"; }       # Long term muscle memory -> current modern tool
    export PAGER=bat
    less_exports   # bat uses less for paging
#elif  command -v moar >/dev/null; then # see https://github.com/walles/moar
    :
elif command -v less >/dev/null; then
    export PAGER=less
    more () { less "$@"; }      # the original, after all
    less_exports
else
    export PAGER=more
fi

unset -f less_exports

command -v tput 1>/dev/null || return 1  # no tput on, e.g., Synology

# Adapted from https://unix.stackexchange.com/a/147

LESS_TERMCAP_mb=$(tput bold; tput setaf 2);               export LESS_TERMCAP_mb # green
LESS_TERMCAP_md=$(tput bold; tput setaf 6);               export LESS_TERMCAP_md # cyan
LESS_TERMCAP_me=$(tput sgr0);                             export LESS_TERMCAP_me
LESS_TERMCAP_so=$(tput bold; tput setaf 3; tput setab 4); export LESS_TERMCAP_so # yellow on blue
LESS_TERMCAP_se=$(tput rmso; tput sgr0);                  export LESS_TERMCAP_se
LESS_TERMCAP_us=$(tput smul; tput bold; tput setaf 7);    export LESS_TERMCAP_us # white
LESS_TERMCAP_ue=$(tput rmul; tput sgr0);                  export LESS_TERMCAP_ue
LESS_TERMCAP_mr=$(tput rev);                              export LESS_TERMCAP_mr
LESS_TERMCAP_mh=$(tput dim);                              export LESS_TERMCAP_mh
LESS_TERMCAP_ZN=$(tput ssubm);                            export LESS_TERMCAP_ZN
LESS_TERMCAP_ZV=$(tput rsubm);                            export LESS_TERMCAP_ZV
LESS_TERMCAP_ZO=$(tput ssupm);                            export LESS_TERMCAP_ZO
LESS_TERMCAP_ZW=$(tput rsupm);                            export LESS_TERMCAP_ZW
GROFF_NO_SGR=1; export GROFF_NO_SGR  # For Konsole and Gnome-terminal
