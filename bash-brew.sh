#!/usr/bin/env bash
# bash_brew.sh - brew related shell integration and aliases/functions

if [[ -n "$ZSH_VERSION" ]]; then
    return 1;
    # See https://docs.brew.sh/Shell-Completion#configuring-completions-in-zsh
    # TODO handle brew in virtualenvs
fi

[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

# Set up brew shellenv and shell completion if installed
# allowing for early definition of HOMEBREW_PREFIX
candidates=("$HOMEBREW_PREFIX" "/opt/homebrew" "/home/linuxbrew" "/usr/local")
for d in "${candidates[@]}"; do
    if [[ -e "${d}/bin/brew" ]]; then
        HOMEBREW_DIR="$d"
        case "$PATH" in
            (*${HOMEBREW_DIR}/bin*)
                # Exclude adding to PATH since already present
                eval "$("${HOMEBREW_DIR}"/bin/brew shellenv | sed '/ PATH/d')" ;;
            (*)
                eval "$("${HOMEBREW_DIR}"/bin/brew shellenv)" ;;
        esac
        MANPATH="${MANPATH/:$/}"; export MANPATH # brew's shellenv appends an extra :
        [[ "${_verbose:=0}" -gt 0 ]] && \
            printf "%s: PATH:%s\nMANPATH: %s\n" "${BASH_SOURCE[0]##*/}" "$PATH" "$MANPATH"
        if [[ -r "${HOMEBREW_DIR}/etc/profile.d/bash_completion.sh" ]]
        then
            # shellcheck disable=1091
            source "${HOMEBREW_DIR}/etc/profile.d/bash_completion.sh"
        else
            for COMPLETION in "${HOMEBREW_DIR}/etc/bash_completion.d/"*
            do
                # shellcheck disable=1090
                [[ -r "${COMPLETION}" ]] && source "${COMPLETION}"
            done
        fi
        break
    fi
done
unset candidates d HOMEBREW_DIR

if [[ -n "${HOMEBREW_PREFIX}" ]]; then  # brew was found above
    brew () { # Avoid polluting virtual environments and preclude other brew blunders
        local python_path

        check_python () {
            python_path="$(type -p python3)"
            # Check that brew will use homebrew's own python
            # See https://docs.brew.sh/Homebrew-and-Python#virtualenv
            if [[ "$python_path" != "${HOMEBREW_PREFIX}/bin/python3" ]]; then
                echo "$python_path"
            else
                echo ""
            fi
        }

        case ${1} in
            (*install*)
                python_path="$(check_python)"
                if [[ "${python_path}" == "" ]]; then
                    "${HOMEBREW_PREFIX}"/bin/brew "$@"
                else
                    (
                        PATH=${HOMEBREW_PREFIX}/bin:${PATH}
                        printf "Installing in subshell, python3 here was %s now %s\n" "${python_path}" "$(type -p python3)"
                        [[ "$(check_python)" == "" ]] && "${HOMEBREW_PREFIX}"/bin/brew "$@"
                    )
                fi
                ;;
            (*upgrade*)
                if [[ -z "$2" ]]; then
                    printf "Cowardly refusing to upgrade all\n"
                else
                    "${HOMEBREW_PREFIX}"/bin/brew "$@"
                fi
                ;;
            (*)
                "${HOMEBREW_PREFIX}"/bin/brew "$@"
                ;;
        esac
    }

    export HOMEBREW_NO_ENV_HINTS=1
fi
