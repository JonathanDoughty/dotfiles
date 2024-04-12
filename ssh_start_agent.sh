#!/usr/bin/env bash
# start_ssh_agent

# Inspired by https://stackoverflow.com/questions/18880024/start-ssh-agent-on-login
ssh_start_agent () {
    # shellcheck disable=SC2046 # word splitting is wanted
    unset $(echo -n "$(env | grep -o '^SSH_[^=]*')")  # start clean
    SSH_ENV="${HOME}/.ssh/environment"; export SSH_ENV
    # shellcheck source=/dev/null
    [ -e "${SSH_ENV}" ] && . "${SSH_ENV}"
    ps -fp "${SSH_AGENT_PID:-1}" | grep -q ssh-agent$ || {
        ssh-agent | sed '/^echo/d' >| "${SSH_ENV}"
        chmod 600 "${SSH_ENV}"
    }
    case "${OSTYPE}" in
        (linux*)
            if ssh-add -l | grep -q 'no identities' ; then
                find ~/.ssh -name 'id*' -print0 | xargs -0 ssh-add # all local identities; not just defaults
            fi
            ;;
        (darwin*)
            # Add keys added to Keychain, e.g., via ssh-add -K
            (builtin cd ~/.ssh || exit; ssh-add -q --apple-load-keychain 2>/dev/null )
            ;;
        (*)
            echo "No ssh_agent on ${OSTYPE^?}?"
            ;;
    esac
}
if [ $# ]; then
    ssh_start_agent "@"
fi
