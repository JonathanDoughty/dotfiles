#!/usr/bin/env bash
# brew-integration.sh - brew related shell integration and aliases/functions
# Note that in one of my twistier mazes this gets invoked via ~/TW/.envrc

# shellcheck disable=SC2317 # usage defined at top level for visibility; redefined internally

# YakShave: Flesh out the _depends_on functionality

if [[ -n "$ZSH_VERSION" ]]; then
    : # zsh accounted for
fi

_bash_brew_usage () {
    [[ -n "$ZSH_VERSION" ]]
    # shellcheck disable=SC2296 # zsh syntax if no BASH_SOURCE
    local THIS_SOURCE=${BASH_SOURCE[0]:-${(%):-%x}}
    cat <<EOF
As defined in $THIS_SOURCE - wrappers around brew operations

brew install - ensure brew installation happens with brew's own python
brew upgrade - refuse to upgrade all packages
brew [check|updatep|upgradep] - list only the outdated leaf packages
brew deps on [package] - list leaves that depend on package
brew deps graph - generate a visualization of leaves' dependencies

Wrapper initialization also insures that HOMEBREW_PREFIX is set sanely,
and, for bash, adds homebrew directories to MANPATH and initializes
bash completion.

EOF

}

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    # Is there an issue with login_actions's use of direnv to invoke this?
    # What else breaks?
    :
else
    __bash_brew_usage=$(declare -f -p _bash_brew_usage) # redefine from global variable below
fi

_homebrew_setup () {
    # Find homebrew's installation directory and update the environment
    local candidates d HOMEBREW_DIR HOMEBREW_ENV
    # allow for earlier definition of HOMEBREW_PREFIX
    candidates=("$HOMEBREW_PREFIX" # Already defined?
                "/opt/homebrew"``            # Apple silicon default
                "/home/linuxbrew/.linuxbrew" # Current brew on linux default
                "/usr/local")                # Intel macOS default
    for d in "${candidates[@]}"; do
        if [[ -e "${d}/bin/brew" ]]; then
            HOMEBREW_DIR="$d"
            # Add homebrew's environment variable settings
            case "$PATH" in
                (*${HOMEBREW_DIR}/bin*)
                    # Exclude adding to PATH since it is already present where user wants it
                    HOMEBREW_ENV="$("${HOMEBREW_DIR}"/bin/brew shellenv | sed '/ PATH/d')"
                    ;;
                (*)
                    # eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
                    HOMEBREW_ENV="$("${HOMEBREW_DIR}"/bin/brew shellenv)"
                    ;;
            esac
            eval "$HOMEBREW_ENV"
            # brew should always use its own python3; set up bootstrap
            if [[ ! -e "${HOMEBREW_PREFIX}/bin/python3" ]]; then
                setup_homebrew_python() {
                    command brew install python3
                }
                printf "brew should have its own python, see %s\nRun setup_homebrew_python to do so\n" \
                       "https://docs.brew.sh/Homebrew-and-Python#virtualenv"
            fi
            break
        fi
    done
}

_homebrew_integrations () {
    # Integrate brew provided shell completions if installed
    local COMPLETION
    if [[ -n "$BASH_VERSION" ]]; then

        local extglob
        extglob=$(shopt -p extglob)
        MANPATH="${MANPATH%%+(:)}"; export MANPATH # brew's shellenv appends extra :
        eval "$extglob"

        # If bash_completions is installed...
        if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]
        then
            # shellcheck disable=1091  # ... let it handle others
            . "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
        else
            # ... otherwise look for other homebrew completion scripts
            for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*
            do
                # shellcheck disable=1090
                [[ -r "${COMPLETION}" ]] && . "${COMPLETION}"
            done
            # otherwise, at one time I was using git@github.com:scop/bash-completion.git
        fi
    else
        fpath=($HOMEBREW_PREFIX/share/zsh/site-functions $fpath)
        #typeset -U fpath # remove duplicates - is causing an issue with compaudit
        autoload -U compinit ; compinit
        # zsh MANPATH TBD
    fi
    export HOMEBREW_NO_ENV_HINTS=1 # stop with the hints already
}

_formula_integrations () {
    # Integration for specific formula

    for formula in $(brew list); do
        case "$formula" in
            (hunspell)
                libreoffice_dict="/Applications/LibreOffice.app/Contents/Resources/extensions/dict-en"
                if [[ -d "$libreoffice_dict" ]]; then
                    export DICPATH="${DICPATH:+$DICPATH:}$libreoffice_dict"
                fi
                #printf "DICPATH: %s\n" "$(env | grep DICPATH)" 2>&1
            ;;
        esac
    done
}

_homebrew_setup

if [[ -n "${HOMEBREW_PREFIX}" ]]; then

    _homebrew_integrations
    _formula_integrations

    # Define wrapper function around normal brew shell
    brew() {
        # Avoid polluting virtual environments, preclude other brew blunders,
        # and provide commands that brew doesn't support yet.

        local python_path

        eval "$__bash_brew_usage" # define usage again locally

        _check_python () {
            [[ -n "$BASH_VERSION" ]] && python_path="$(type -p python3)"
            [[ -n "$ZSH_VERSION" ]] && python_path="$(whence python3)"
            # Check that brew will use homebrew's own python
            if [[ "$python_path" != "${HOMEBREW_PREFIX}/bin/python3" ]]; then
                echo "$python_path" # return the path to the default, non-brew python3
            else
                echo ""         # python3 is brew's
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
                # Debian no longer specifies TMPDIR but does XDG_RUNTIME_DIR with /tmp fallback
                builtin cd "${TMPDIR:-${XDG_RUNTIME_DIR:-/tmp}}" 2>/dev/null || \
                    ( echo "No TMPDIR, exiting"; exit 0 )
                command rm -f Brewfile
                command brew bundle dump &>/dev/null
                # shellcheck disable=SC2046  # we want separate arguments
                command brew outdated $(_list_brew_formula_updates)
            )
            [[ -n "$_debug" ]] || unset -f _list_brew_formula_updates
        }

        _depends_on () {
            # implement `brew deps --tree $(brew leaves)` reporting which leaves depend on packages
            # YakShave: awk saving the leaves and then reporting whenever the dependency was seen?
            #trap "set +x" RETURN && set -x
            shift; shift
            printf "brew deps on %s not implemented yet\n" "$*"
        }

        _graph () {
            if [[ ! -e "${HOMEBREW_PREFIX}/Library/Taps/martido/homebrew-graph" ]]; then
                printf "Requires \`brew tap martido/homebrew-graph\`\n" && return
            fi
            local dot
            dot="$( ([[ -n "$BASH_VERSION" ]] && type -p dot ) || ( [[ -n "$ZSH_VERSION" ]] && whence dot ) )"
            if [[ -z "$dot" ]]; then
                printf "Requires dot from \`brew install graphviz\`\n" && return
            else
                local graph_file="${TMPDIR:-${XDG_RUNTIME_DIR:-/tmp}}/brew_graph.png"
                brew graph --installed --highlight-leaves | dot -Tpng -o"$graph_file"

                open "$graph_file" 
            fi
        }
        
        case ${1} in  # wrapper defined brew verbs
            (install)
                # Don't believe me? Read https://docs.brew.sh/Homebrew-and-Python
                python_path="$(_check_python)"
                if [[ "$python_path" == "" ]]; then
                    "${HOMEBREW_PREFIX}"/bin/brew "$@"
                else
                    (
                        PATH=${HOMEBREW_PREFIX}/bin:${PATH}; export PATH
                        printf "Installing in subshell, python3 here was %s now %s\n" \
                               "$python_path" "$(_check_python)"
                        if [[ "$(_check_python)" == "" ]]; then
                            "${HOMEBREW_PREFIX}"/bin/brew "$@"
                        else
                            printf "Cowardly refusing as python3 is still %s, please run %s\n" \
                                   "$(_check_python)" "setup_homebrew_python"
                        fi
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
            (deps*)
                case "$2" in
                    (on)
                        _depends_on "$@"
                        ;;
                    (graph)
                        _graph
                        ;;
                    (*)
                        shift # just invoke the normal brew deps
                        command brew deps "$@"
                        ;;
                esac
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
        [[ -n "$_debug" ]] || \
            unset -f _check_python _check_outdated _bash_brew_usage _graph _depends_on
    }
fi

unset -f _bash_brew_usage _homebrew_setup _homebrew_integrations _formula_integrations

( # Being sourced?
    [[ -n $ZSH_VERSION && $ZSH_EVAL_CONTEXT =~ :file$ ]] ||
        [[ -n $BASH_VERSION ]] && (return 0 2>/dev/null)
) || brew "${@:-help}"          # otherwise invoke the wrapper
