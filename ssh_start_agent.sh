#!/usr/bin/env bash
# ssh_start_agent

#[[ -t 0 ]] || return            # scripts *may* want to ensure an agent can provide keys

ssh_start_agent () {

    local ssh_dir="${HOME}/.ssh" # you probably don't want to change this

    if [[ ! -e "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        printf "Created %s; replace as needed; all bets are off without contents\n" "$ssh_dir"
    fi
    # This script is likely sourced: avoid a subshell (and multiple traps when sourced.)
    trap "trap - RETURN; popd >/dev/null; set +x" RETURN
    pushd "$ssh_dir" >/dev/null || return; set +x #; printf "pushed to\n%s\n" "$(dirs -v)"

    # Check for the far simpler https://www.funtoo.org/Funtoo:Keychain
    if type keychain &>/dev/null; then
        case "$OSTYPE" in
            (darwin*)
                # Just start the agent(s) if needed
                eval "$(keychain --quiet --quick --eval)"
                # and use macOS' ssh-add to get any additions from Keychain Access
                # without requiring password entry.
                /usr/bin/ssh-add -q --apple-load-keychain 2>/dev/null
                ;;
            (linux*)
                eval "$(keychain --quiet --quick --eval id_rsa_"$(hostname -s)")"
                # Assumes hostname's key requires no password or prompts for one
                # Others TBD
                ;;
        esac
    else
        # Prior to adopting keychain I did this all manually, inspired by
        # https://stackoverflow.com/questions/18880024/start-ssh-agent-on-login
        local vars
        vars="$(env | grep -o '^SSH_[^=]*')"
        vars="${vars//[$'\t\n\r']}"  # deal with bash 4 unset issue
        # shellcheck disable=SC2086  # word splitting desired
        unset $vars                  # start with environment cleaned of SSH_ vars
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
    fi
}
ssh_start_agent
