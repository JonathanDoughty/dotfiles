#!/usr/bin/env bash
# ssh_start_agent

# Inspired by https://stackoverflow.com/questions/18880024/start-ssh-agent-on-login
# For macOS, see login_actions.sh:ssh_identities()

ssh_start_agent () {
    local vars
    vars="$(env | grep -o '^SSH_[^=]*')"
    vars="${vars//[$'\t\n\r']}"  # deal with bash 4 unset issue
    # shellcheck disable=SC2086  # word splitting desired
    unset $vars                  # start with environment cleaned of SSH_ vars
    local ssh_dir="${HOME}/.ssh" # you probably don't want to change this

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
