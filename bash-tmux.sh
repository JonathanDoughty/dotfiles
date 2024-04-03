#!/usr/bin/env bash
# bash-tmux.sh
# See also .tmux.conf

if [ -n "$ZSH_VERSION" ]; then emulate -L ksh; fi
[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

mta () {
    # TODO Future yak shaving exercises:
    # 1) Use this on the remote end or provide a companion script for remote server initialization
    # 2) Check for / add ssh key (ssh-add -l):
    #    [ -n "${SSH_AUTH_SOCK}" ]
    # 3) Run tmux or otherwise start server first (tmux info returns $? == 1)

    _title () {
        #trap "set +x" RETURN && set -x
        if [[ $can_set_title ]]; then
            if type set_tab_title &>/dev/null; then # see directory_functions.sh
                set_tab_title "$@"
            else
                can_set_title=1
            fi
        fi
    }

    local can_set_title
    case "$1" in
        (*d*|*m*)
            case "$1" in
                (d|-d|diskstation)
                    local host="diskstation"
                    ;;
                (m|-m|mare)
                    local host="eire"
                    ;;
            esac
            _title "mosh $host"
            mosh --server=/usr/local/bin/mosh-server "$host" -- \
                 /usr/local/bin/tmux new-session -AD -s "$host"
            ;;
        (*)
            _title "mosh $1"
            # was mosh "$1" -- tmux attach -d || tmux new -s "$1"
            mosh "$1" -- tmux new-session -AD -s "$1"  # works with mosh 1.3.2 / tmux 2.6
            ;;
    esac
    # restore tab/term title
    [[ -n "$_last_tab_title" ]] &&_title "$_last_tab_title"
    unset -f _title
}

# Via https://stackoverflow.com/a/62422576/1124740
# Have tmux prompt for default directory for current session / future panes
tmux-cwd () {
    tmux command-prompt -I "$PWD" -p "New session dir:" "attach -c %1"
}
alias twd=tmux-cwd
