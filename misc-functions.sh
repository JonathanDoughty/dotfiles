#!/usr/bin/env bash
# misc-functions.sh - crutches I've grown too used to

_debug=0

if type is_defined >/dev/null 2>&1 ; then
    # Source common functions
    # shellcheck disable=SC1091
    [[ -z ${ZSH_VERSION} ]] && . "$(dirname "${BASH_SOURCE[0]}")/shell-funcs.sh"
    # shellcheck disable=SC1091,SC2296 # This is valid zsh sytax
    [[ -n ${ZSH_VERSION} ]] && . "$(dirname "${(%):-%N}")/shell-funcs.sh"
fi

_is_type () {
    # check type of $1 for bash or zsh
    local target type candidate
    target="$1"; shift
    if [[ -n "$BASH_VERSION" ]]; then
        type="$(type -t "$target" 2>&1)"
    elif [[ -n "$ZSH_VERSION" ]]; then
        type="$(whence -w "$target" 2>&1)"
    else
        printf "Don't know type/whence equivalent for %s\n" "$SHELL" && return 1
    fi
    for candidate in "$@"; do
        [[ -n "$ZSH_VERSION" ]] && [[ $candidate == "file" ]] && candidate="command"
        [[ $_debug -gt 1 ]] && \
            printf "candidate=%s type %s %s =%s\n" "$candidate" "$OPT" "$target" "$type"
        case "$type" in
        (*$candidate) return 0 ;;
        esac
    done
    return 1
}

# Stubs for functions redefined on first use from external definitions.
# (as long as they haven't been previously redefined already.)

_is_type cd 'builtin' && cd() {
    lazy_load_from directory-functions.sh "$@" "quiet"
}

_is_type up 'function' || up() {
    lazy_load_from up_directory.sh "$@"
}

_is_type man 'function' || man() {
    lazy_load_from man_page_viewer.sh "$@"
}

_is_type mman 'function' || mman() {
    lazy_load_from man_page_viewer.sh "$@"
}

for _f in 'add_to_my_path' 'ppath' 'rpath'; do
    # I don't think this is really lazy loading but I'm too lazy yakshave further
    # shellcheck disable=SC1091
    is_defined "${_f}" || source /dev/stdin <<-EOF
	${_f}() {
	   lazy_load_from path_add_remove.sh "\$@";
	}
	EOF
done

ssh_start_agent() {
    # Yakshave: needs zsh work
    lazy_load_from "${FUNCNAME[0]}.sh" "$@"
}

# standard command options and shortcuts
# I've wasted too much time when aliases fail under odd conditions. I now just use functions.

cp () { command cp -i "$@"; }
cs () { printf '\033c'; }       # clear screen
g () { git "$@"; }
 # enable completion for that:
if [[ -n "$BASH_VERSION" ]]; then
    _is_type __git_complete 'function' && __git_complete g __git_main
elif [[ -n "$ZSH_VERSION" ]]; then
    compdef g=git
fi
gs () { git st; }                # see .gitconfig
_is_type grep 'alias' && unalias grep       # replace Linux's system defined alias
grep () { command grep --color=auto "$@"; } # ... with function equivalent I keep consistent
hist () { history "$@"; }
mv () { command mv -i "$@"; }
whatsmyip () { dig +short myip.opendns.com @resolver1.opendns.com "$@"; }

# Replacements when available
type duf  1>/dev/null 2>&1 && [[ -z "$INSIDE_EMACS" ]] && \
    df () {
        # duf requires line drawing characters
        # Use ~/bin/,duf symlink to patched version to avoid path confusion
        ,duf --only local --hide-fs nullfs \
             --hide-mp '*/.timemachine/*,/System/*,/Volumes/Recovery' \
             --output mountpoint,size,used,avail,filesystem
}
type dust 1>/dev/null 2>&1 && \
    du () { dust --ignore_hidden --no-percent-bars "$@"; }
type btm  1>/dev/null 2>&1 && \
    top () { btm "$@"; } # `bottom` via brew

# More colorful ls
_is_type ls 'alias' && unalias ls # replace Linux's system alias
if [[ -e "${HOMEBREW_PREFIX}"/bin/lsd ]]; then
    ls () {
        local _defaults=""
         # emacs' shell-mode is not a true terminal emulator
        [[ "$INSIDE_EMACS" =~ 'comint' ]] && _defaults="--classic"
        # I find lsd (rust-based lsdeluxe) to be more consistent with ls than the alternative exa.
        # lsd normally needs nerd-fonts: https://github.com/ryanoasis/nerd-fonts
        "${HOMEBREW_PREFIX}"/bin/lsd $_defaults "$@"
    }
elif type eza 1>/dev/null 2>&1 ; then
    ls () {
        # SynoCLI package adds eza as an alternative to exa.
        eza --classify --color=auto --color-scale --icons "$@"
    }
elif ls --classify 1>/dev/null 2>&1 ; then # classify <- GNU ls via brew coreutils / Linux
    ls () {
        command ls --classify --color=auto "$@"
    }
else
    ls () {
        # native, e.g. macOS /bin/ls
        command ls -FG --color=auto "$@"
    }
fi

lr () {  # list recent files
    [[ -n $ZSH_VERSION ]] && emulate -L sh # blunt foorce word splitting
    local _color_arg
    if [[ -e "${HOMEBREW_PREFIX}"/bin/lsd ]]; then
        _color_arg="--color always"
    else                        # standard ls and eza:
        _color_arg="--color=always"
    fi
    # shellcheck disable=SC2012,SC2086  # using ls function is the point, ignore glob complaint
    ls -lrt $_color_arg "${@}" | tail -$(( LINES * 3 / 4 )) # 3/4 of screen worth
}

type rg 1>/dev/null 2>&1 && \
    rgd () { rg -. "$@"; }       # ripgrep dot files too

which () {  # tell how argument will be interpreted
    builtin alias "$@" 2>/dev/null \
        || type "$@" 2>/dev/null \
        || typeset -f "$@" 2>/dev/null \
        || command which "$@"
}

if [[ -n "$BASH_VERSION" && ${BASH_VERSINFO[0]} -gt 3 ]]; then
    : # I used to include bash_completion here for some reason, now in .bashrc
fi

# OS specific

_macos_funcs () {
    unset COMMAND_MODE # ignore ancient legacy behavior
    attach () {
        local drive rest disk
        if [ $# -eq 0 ]; then
            read -erp "Attach: " drive rest
        else
            drive=$1
        fi
        disk=$(diskutil list | grep "$drive" | awk '{print $NF}')
        if [ -e /dev/"$disk" ]; then
            printf "%s attached\n" "$(hdiutil attach /dev/"$disk" | awk '{print $NF}')"
        else
            printf "Huh? %s from %s\n" "$disk" "$drive"
        fi
    }

    # possibly stale stats, human readable base 10, skip /dev, autofs mounts;
    # fallback df replaced by duf based version above if that's installed
    _is_type df function || \
        df () { /bin/df -n -H -T nodevfs,autofs,osxfuse "$@"; }

    # provide a function to eject mounted volumes like linux has
    eject () {
        [[ $_debug -gt 0 ]] && trap "set +x" RETURN && set -x
        printf "ejecting %s ..." "${1}"
        hdiutil detach "${1}"
    }
    if [[ -n "$BASH_VERSION" ]]; then # bash command completion for the lazy typer
        __mounted_vols () {
            # shellcheck disable=SC2207  # I do want to split the output
            COMPREPLY+=($(compgen -W "$(mount | sed -n '/ \/Volumes/p' | cut -d ' ' -f 3)" -- "$cur"))
        }
        _eject () {
            _comp_initialize -- "$@" || return
            __mounted_vols
        }
        complete -F _eject eject
    else # and zsh completion as a bonus
        __mounted_vols () {
            # shellcheck disable=SC2034,SC2207 # zsh expect/uses reply
            reply=( $(mount | sed -n '/ \/Volumes/p' | cut -d ' ' -f 3) )
        }
        compctl -K __mounted_vols eject
    fi

    _is_type top 'alias' 'function' || \
        top () { command top -o cpu "$@"; }

    kh () { # Useful when I've caused an infinite loop
        killall -STOP Hammerspoon
    }

    _is_type "qlmanage" "file" &&  \
        ql () { # command line quicklook
            qlmanage -p "$@" &>/dev/null &
        }

    ssh-apple () {
        # I end up doing this enough to make it a function
        (
            cd ~/.ssh || exit
            ssh-add -q --apple-load-keychain --apple-use-keychain
        )
    }

    _is_type "time_machine_local" "file" && \
        tml() {
            time_machine_local      # my force a local time machine update script
        }

    trash () {
        if [ -x "${HOMEBREW_PREFIX}/bin/trash" ]; then
            "${HOMEBREW_PREFIX}/bin/trash" "$@"
            if [ $? -eq 1 ]; then  # Must be a filesystem that doesn't support trash
                # Yakshave: remember filesystem and do this autmatically
                # Or check filesystem root for .Trash first
                #\rm -v "$@"
                # Move the file to Trash so it sticks around?
                # Yakshave: Only do this for files/directories smaller than a limiting size
                mv "$@" ~/.Trash
            fi
        else
            command rm "$@"
        fi
    }
    _is_type "trash" "function" "file" && \
        rm () { trash "$@"; }
}

_linux_funcs () {
    _is_type df 'function' || \
        df () { command df -h -x tmpfs -x squashfs -x devtmpfs "$@"; }
    pstree () { /usr/bin/pstree -Gpu "$@"; }
    rm () { command rm -i "$@"; }
    if [ -n "${DESKTOP_SESSION}" ]; then  # When in GUI; Debian specific?
        type xdg-open 1>/dev/null && \
            open () { xdg-open "$@"; }
    fi
}

case ${OSTYPE} in
    (darwin*)
        _macos_funcs
        ;;
    (linux*)
        _linux_funcs
        ;;
esac
unset _debug _is_type _macos_funcs _linux_funcs _f
