#!/usr/bin/env bash

# shellcheck disable=SC2317

[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

export PYTHONDONTWRITEBYTECODE="Don't clutter with __pycache__ directories"
# alternately: see/use https://docs.python.org/3/using/cmdline.html#envvar-PYTHONPYCACHEPREFIX

function virtualenv_setup {
    case $(uname -s) in
    (Linux*)
        if [ -z "${WORKON_HOME}" ] && [ -e "${HOME}/Envs" ]; then
            export WORKON_HOME=${HOME}/Envs
        fi
        ;;
    (Darwin*)
        if [ -z "${WORKON_HOME}" ] && [ -e "${HOME}/Documents/Envs" ]; then
            export WORKON_HOME=${HOME}/Documents/Envs
        fi
        ;;
    (MINGW*) # e.g., Git Bash
        export WORKON_HOME=~/Envs  # But do you want to hack Python in this?
        ;;
    esac

    # Get `command` to tell which virtualenvwrapper and python3
    VIRTUALENVWRAPPER_PATH="$(command -v virtualenvwrapper_lazy.sh)" && export VIRTUALENVWRAPPER_PATH
    VIRTUALENVWRAPPER_PYTHON="$(command -v python3)" && export VIRTUALENVWRAPPER_PYTHON
    # virtualenvwrapper complaining? you probably forgot to
    # syspip install virtualenvwrapper when brew upgraded python

    if [ -e "${WORKON_HOME}" ] && [ -e "${VIRTUALENVWRAPPER_PATH}" ]; then
        export PIP_REQUIRE_VIRTUALENV=true
        function syspip {
            local pip
            # Which is the 'system' pip: prefer local (but not virtualenv ones)
            PATH=/usr/local/bin:/usr/bin:${PATH} pip=$(command -v pip3)
            PIP_REQUIRE_VIRTUALENV="" ${pip} "$@"
        }
        . "${VIRTUALENVWRAPPER_PATH}"
    elif [ ! -e "${WORKON_HOME}" ]; then
        printf "\nNo WORKON_HOMRE directory; retry when one has been created or export WORKON_HOME=/path/to/where\n"
    fi
}
