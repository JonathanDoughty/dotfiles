#!/usr/bin/env bash
# misc-functions.sh - crutches I've grown too used to

_debug=0

if ! type is_defined &>/dev/null ; then
    # Source common functions
    if [[ -z ${ZSH_VERSION} ]]; then
        # shellcheck disable=SC1091
        . "$(dirname "${BASH_SOURCE[0]}")/shell-funcs.sh"
    else
        # shellcheck disable=SC1091,SC2296 # This is valid zsh sytax
        . "$(dirname "${(%):-%N}")/shell-funcs.sh"
    fi
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

_is_type cd 'builtin' && cd () {
    lazy_load_from directory-functions.sh "$@" "quiet"
}

_is_type up 'function' || up () {
    lazy_load_from up_directory.sh "$@"
}

_is_type man 'function' || man () {
    lazy_load_from man_page_viewer.sh "$@"
}

_is_type mman 'function' || mman () {
    lazy_load_from man_page_viewer.sh "$@"
}

for _f in 'add_to_my_path' 'ppath' 'rpath'; do
    # I don't think this is really lazy loading but I'm too lazy to yakshave further
    # shellcheck disable=SC1091
    is_defined "${_f}" || source /dev/stdin <<-EOF
	${_f} () {
	   lazy_load_from path_add_remove.sh "\$@";
	}
	EOF
done

ssh_start_agent () {
    if [[ -n "$BASH_VERSION" ]]; then
        lazy_load_from "${FUNCNAME[0]}.sh" "$@"
    elif [[ -n "$ZSH_VERSION" ]]; then
        # shellcheck disable=SC1087,SC2154 # This is zsh
        lazy_load_from "${funcstack[1]}.sh" "$@"
    fi
}

# Standard command default options and shortcuts for frequent combinations. I wasted too much
# time when using aliases failed under conditions I'd forgotten about; now I just use
# functions.

cp () { command cp -i "$@"; }
cs () { printf '\033c'; }       # clear screen
eg () {
    if [[ "$#" -gt 0 ]]; then
        env | grep  "$@"
    else
        printf "eg [pattern to search for in environment]\n"
    fi
}
g () { git "$@"; }
 # enable completion for that shortcut:
if [[ -n "$BASH_VERSION" ]]; then
    _is_type __git_complete 'function' && __git_complete g __git_main
elif [[ -n "$ZSH_VERSION" ]]; then
    compdef g=git
fi
gs () { git st; }                # see .gitconfig

_is_type grep 'alias' && unalias grep       # replace Linux's system defined alias...
grep () { command grep --color=auto "$@"; } # ... with function equivalent I keep consistent
mv () { command mv -i "$@"; }
whatsmyip () { dig +short myip.opendns.com @resolver1.opendns.com "$@"; }
dnslookup () { # for when my DNS settings are not working
    if [[ "$#" -lt 1 ]]; then
        printf "usage: dnslookup host\n"
        return
    else
        curl https://api.hackertarget.com/dnslookup/?q="${1}";
        printf "\n"
    fi
}

# Command replacements when available
type duf  &>/dev/null && [[ -z "$INSIDE_EMACS" ]] && \
    df () {
        # duf requires line drawing characters
        # Use ~/bin/,duf symlink to patched version to avoid path confusion
        ,duf --only local --hide-fs nullfs \
             --hide-mp '*/.timemachine/*,/System/*,/Volumes/Recovery' \
             --output mountpoint,size,used,avail,filesystem
}
type dust &>/dev/null && \
    du () { dust --ignore_hidden --no-percent-bars "$@"; }
type btm  &>/dev/null && \
    top () { btm "$@"; } # `bottom` via brew

# More colorful ls
_is_type ls 'alias' && unalias ls # replace Linux's system alias
if [[ -e "${HOMEBREW_PREFIX:-/no_prefix}"/bin/lsd || -e /usr/local/bin/lsd ]]; then # brew or DSM 
    ls () {
        local _defaults=""
         # emacs' shell-mode is not a true terminal emulator
        [[ "$INSIDE_EMACS" =~ 'comint' ]] && _defaults="--classic"
        # I find lsd (LSDeluxe) more consistent with ls flags than the alternative e{x,z}a.
        command lsd --classify $_defaults "$@"
    }
elif type eza &>/dev/null ; then
    ls () {
        local _sort=""
        # SynoCLI package adds eza as an alternative to exa
        if [[ "$1" =~ -.* && "$1" != x"${1/t/}" ]]; then
            # Handle non-traditional -t, which muscle memory invokes.
            local _args="${1/t/}"
            shift
            _sort="$_args --sort=modified"
        fi
        eza --classify --color=auto --color-scale --icons "$_sort" "$@"
    }
elif ls --classify -d . &>/dev/null ; then # --classify <- GNU ls via brew coreutils / Linux
    ls () {
        command ls --classify --color=auto "$@"
    }
elif ls -% -d . &>/dev/null ; then # macOS /bin/ls
    ls () {
        command ls -FG --color=auto "$@"
    }
else                            # some kind of POSIX ls?
    ls () {
        command ls -F "$@"
    }
fi

lr () {  # list recent files
    [[ -n $ZSH_VERSION ]] && emulate -L sh # blunt force word splitting
    declare -a  _color_args
    if [[ -e "${HOMEBREW_PREFIX}"/bin/lsd ]]; then
        _color_args=( --color always )
    else                        # standard ls and eza:
        _color_args=( --color=always )
    fi
    local _type
    if [[ -n "$BASH_VERSION" ]]; then
        _type="$(type -t "ls" 2>&1)"
    elif [[ -n "$ZSH_VERSION" ]]; then
        _type="$(whence -w "ls" 2>&1)"
    fi
    # shellcheck disable=SC2012  # using ls function is the point
    [[ "$_type" =~ function ]] && \
        ls -lrt "${_color_args[@]}" "${@}" | tail -$(( LINES * 3 / 4 )) # 3/4 of screen worth
}

if type rg &>/dev/null ; then
    rgh () {                  # ripgrep hidden, e.g., dot files too, with extras from RG_LOCAL 
        local cmd
        # RG_LOCAL="--glob='!venv/**'"; export RG_LOCAL in .envrc for example
        printf -v cmd "rg --hidden %s" "${RG_LOCAL:+$RG_LOCAL}"
        [[ "${_verbose:=0}" != "0" ]] && trap "set +x" RETURN && set -x
        eval $cmd "$@"
    }
    rgi () { rgh --no-ignore "$@"; } # ... and don't ignore files excluded by .gitignore
fi

which () {  # `which` on steroids: how $@ will be interpreted by first one to succeed
    builtin alias "$@" 2>/dev/null \
        || type "$@" 2>/dev/null \
        || typeset -f "$@" 2>/dev/null \
        || command which "$@"
}

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
    _is_type df 'function' || \
        df () { /bin/df -n -H -T nodevfs,autofs,osxfuse "$@"; }

    # provide a function to eject mounted volumes like linux has
    eject () {
        local DEV v target OP
        OP="unmount"
        OPTERR=1; OPTIND=1  # reset getopts
        while getopts "aehv" flag; do
            case "$flag" in
                (h|\?) cat <<EOF
${FUNCNAME[0]} [-a -e -h -v] volume - Unmount mounted volumes

Options:
-a  - unmount all disks on same device
-e  - eject rather than unmount
-v  - be verbose about it
-h  - this help text

EOF
                    return
                    ;;
                (a) # eject all filesystems on same disk
                    DEV=1
                    ;;
                (e) OP="eject"
                    ;;
                (v) # be verbose
                    trap "set +x" RETURN && set -x
                    ;;
                (*)
                    printf "Error parsing %s from %s\n" "$OPTARG" "$@"
                    ;;
              esac
        done
        shift "$((OPTIND - 1))"
        
        target="$1"
        # Determine filesystem disk device number that $target mounts from
        [[ -n "$DEV" ]] && \
            DEV="$(command df | command grep "$target" | command cut -f 1 -d ' ' | command sed 's/s[0-9]*$//g')"
        printf "%sing %s ...\n" "$OP" "$target"
        diskutil "$OP" "$target" &> /dev/null
        case $? in
            (0) ;;
            (16)
                # Hey macOS, why do you report an error for
                printf "WTF? error %d for %s of %s\n" "$?" "$OP" "$target" 1>&2
                ;;
            (*)
                printf "diskutil returned %d %sing %s\n" "$?" "$OP" "$target" 1>&2
                ;;
        esac

        if [[ -n "$DEV" ]]; then
            # Get remaining filesystems on same device
            for v in $(command df | command grep "^$DEV" | command cut -f 1 -d ' '); do
                [[ $VERBOSE -gt 0 ]] && printf "ejecting associated %s ...\n" "$v"
                if ! diskutil "$OP" "$v" ; then
                    printf "Error %d %sing %s\n" $? "$OP" "$v" && break
                fi
            done
        fi
    }
    if [[ -n "$BASH_VERSION" ]]; then # bash command completion for eject
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

    _is_type qlmanage "file" &&  \
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

    _is_type time_machine_local "file" && \
        tml () {                    # for the lazy typer, assuming the script is in PATH by now
            time_machine_local "$@" # start local time machine update script
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
    _is_type trash "function" "file" && \
        rm () { trash "$@"; }
}

_linux_funcs () {
    _is_type df 'function' || \
        df () { command df -h -x tmpfs -x squashfs -x devtmpfs "$@"; }
    pbcopy () {
        # Piping command output into this copies it to the clipboard
        # Via https://jvns.ca/til/vim-osc52/
        printf "\033]52;c;%s\007" "$(base64 | tr -d '\n')"
    }
    pstree () { /usr/bin/pstree -Gpu "$@"; }
    rm () { command rm -i "$@"; }
    if [ -n "${DESKTOP_SESSION}" ]; then  # When in desktop session, per freedesktop.org
        type xdg-open &>/dev/null && \
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
unset _debug _macos_funcs _linux_funcs _f _is_type
