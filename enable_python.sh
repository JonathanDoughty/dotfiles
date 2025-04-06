#!/usr/bin/env bash

# shellcheck disable=SC2317

[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

export PYTHONDONTWRITEBYTECODE="Don't clutter with __pycache__ directories"
# alternately: see/use https://docs.python.org/3/using/cmdline.html#envvar-PYTHONPYCACHEPREFIX

_python_path_additions () {
    case ${OSTYPE} in
        (darwin*)
            # I prefer manually maintained 'Official' Python over homebrew's dependency updated one
            # NB: installation will prepend it's versioned directory in ~/.bash_profile
            
            add_to_my_path /Library/Frameworks/Python.framework/Versions/Current/bin

            # Add most recent Python framework's pip install --user directory
            local python_version
            python_version="$(find "${HOME}/Library/Python" -depth 0 -type d -exec ls -t1 {} + | head -1)"
            if [[ -n "$python_version" ]]; then
                local user_script_path
                printf -v user_script_path "${HOME}/Library/Python/%s/bin" "$python_version"
                add_to_my_path "$user_script_path"
            fi
            ;;
        (*)
            if type python3 &>/dev/null; then
                if ! type pip3 &>/dev/null; then
                    : printf "Warning: using %s, no pip3\n" "$(type -p python3)" 1>&2
                    # TODO: what is the right thing on Linux/DSM, where system python3 does not
                    # install pip or pip3 (but linuxbrew adds it's own pip3)? A good excuse to
                    # try uv https://docs.astral.sh/uv/
                fi
            else
                : # No python3, enabling is gonna be rough
            fi
            ;;
    esac
}

_virtualenv_setup () {     # unused now that I use python -m venv
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
        printf "\nNo WORKON_HOME directory; retry when one has been created or export WORKON_HOME=/path/to/where\n"
    fi
}

_python_path_additions
unset _python_path_additions _virtualenv_setup
