#!/usr/bin/env bash
# bash_brew.sh - brew related shell integration and aliases/functions


if [[ -n "$ZSH_VERSION" ]]; then
    : # zsh accounted for
fi

_bash_brew_usage () {
    [[ -n "$ZSH_VERSION" ]]
    # shellcheck disable=SC2296 # zsh syntax if no BASH_SOURCE
    local THIS_SOURCE=${BASH_SOURCE[0]:-${(%):-%x}}
    cat <<EOF
As defined in $THIS_SOURCE - wrappers around brew operations

brew install - ensure brew installation happen with brew's own python
brew upgrade - refuse tpo upgrade all packages
brew [check|updatep|upgradep] - list only the outdated leaf packages

Wrapper initialization also insures that HOMEBREW_PREFIX is set sanely,
and, for bash, adds homebrew directories to MANPATH and initializes
bash completion.

EOF

}

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
        if [[ -n "$BASH_VERSION" ]]; then
            # shellcheck disable=SC2031 # I don't see how this is modifing _verbose in a subshell
            [[ "${_verbose:-0}" -gt 0 ]] && \
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
        else
            : # zsh MANPATH / completion TBD
        fi
        break
    fi
done
unset candidates d HOMEBREW_DIR

if [[ -n "${HOMEBREW_PREFIX}" ]]; then  # brew was found above
    brew () {
        # Avoid polluting virtual environments, preclude other brew blunders,
        # and provide commands that brew doesn't support yet.

        local python_path

        _check_brew_python () {
            [[ -n "$BASH_VERSION" ]] && python_path="$(type -p python3)"
            [[ -n "$ZSH_VERSION" ]] && python_path="$(whence python3)"
            # Check that brew will use homebrew's own python
            # See https://docs.brew.sh/Homebrew-and-Python#virtualenv
            if [[ "$python_path" != "${HOMEBREW_PREFIX}/bin/python3" ]]; then
                echo "$python_path"
            else
                echo ""
            fi
        }

        _check_outdated () {
            # Inspired by https://github.com/Homebrew/brew/issues/5858
            # An intersection of brew outdated + brew leaves

            _list_brew_formula_updates () { # as well as casks
                brew bundle check --verbose | \
                    awk '/needs to be installed or updated/ {printf("%s\n", $3) }' | \
                    sort
            }

            ( # in a subshell so current directory isn't polluted
                # with possibly duplicate Brewfile
                [[ -n "$_debug" ]] && trap "set +x" RETURN && set -x
                # and lose direnv's report as directory is changed
                builtin cd "$TMPDIR" 2>/dev/null || exit 0
                command rm -f Brewfile
                command brew bundle dump 1>/dev/null 2>&1
                # shellcheck disable=SC2046  # we want separate arguments
                command brew outdated $(_list_brew_formula_updates)
            )
            [[ -n "$_debug" ]] || unset -f _list_brew_formula_updates
        }

        case ${1} in
            (install)
                # Don't believe me? Read https://docs.brew.sh/Homebrew-and-Python
                python_path="$(_check_brew_python)"
                if [[ "${python_path}" == "" ]]; then
                    "${HOMEBREW_PREFIX}"/bin/brew "$@"
                else
                    (
                        PATH=${HOMEBREW_PREFIX}/bin:${PATH}
                        printf "Installing in subshell, python3 here was %s now %s\n" "${python_path}" "$(type -p python3)"
                        [[ "$(_check_brew_python)" == "" ]] && "${HOMEBREW_PREFIX}"/bin/brew "$@"
                    )
                fi
                ;;
            (upgrade)
                if [[ -z "$2" ]]; then
                    printf "Cowardly refusing to upgrade all\n"
                else
                    "${HOMEBREW_PREFIX}"/bin/brew "$@"
                fi
                ;;
            (check|updatep|upgradep)
                # List just the formula and casks, not the dependencies
                _check_outdated
                ;;
            (help|-h)
                command brew help
                printf "\nWrapper help:\n"
                _bash_brew_usage
                ;;
            (*)
                [[ "${#@}" -gt 0 ]] || brew help # no args? pick up this help too
                # Pass through
                command brew "$@"
                ;;
        esac

        # No need for these outside
        [[ -n "$_debug" ]] || unset -f _check_brew_python _check_outdated
    }

    export HOMEBREW_NO_ENV_HINTS=1 # stop with the hints already

    ( # Being sourced?
        [[ -n $ZSH_VERSION && $ZSH_EVAL_CONTEXT =~ :file$ ]] ||
        [[ -n $BASH_VERSION ]] && (return 0 2>/dev/null)
    ) || brew "${@:-help}"      # otherwise invoke the wrapper
fi
