#!/usr/bin/env bash
# start_ssh_agent

# Inspired by https://stackoverflow.com/questions/18880024/start-ssh-agent-on-login
ssh_start_agent () {
    if [[ ${BASHVERSINFO[1]} -lt 5 ]]; then
        # shellcheck disable=SC2046 # start clean construct for bash 4 unset issue
        eval $(echo unset $(echo -n $(env | grep -o '^SSH_[^=]*' | tr '\n' ' ')))
    else
        # shellcheck disable=SC2046 # works for bash and zsh
        unset $(env | grep -o '^SSH_[^=]*' | tr '\n' ' ') # start clean
    fi
    local ssh_dir="${HOME}/.ssh"

    if [[ ! -e "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        printf "Created %s; replace as needed\n" "$ssh_dir"
    fi
    SSH_ENV="${ssh_dir}/environment"; export SSH_ENV
    # shellcheck source=/dev/null
    [ -e "${SSH_ENV}" ] && . "${SSH_ENV}"
    ps -fp "${SSH_AGENT_PID:-1}" | grep -q ssh-agent$ || {
        ssh-agent | sed '/^echo/d' >| "${SSH_ENV}"
        chmod 600 "${SSH_ENV}"
    }
    case "${OSTYPE}" in
        (linux*)
            if ssh-add -l | grep -q 'no identities' ; then
                 # add all local identities; not just defaults
                find "$ssh_dir" -name 'id*' -print0 | xargs -0 ssh-add
            fi
            ;;
        (darwin*)
            # Add keys added to Keychain
            (builtin cd "$ssh_dir" || exit; ssh-add -q --apple-load-keychain 2>/dev/null )
            ;;
        (*)
            echo "No ssh_agent on ${OSTYPE^?}?"
            ;;
    esac
}
if [ $# ]; then
    ssh_start_agent "@"
fi
