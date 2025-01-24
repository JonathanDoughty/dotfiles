#!/usr/bin/env bash

# shellcheck disable=SC2317

[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

export PYTHONDONTWRITEBYTECODE="Don't clutter with __pycache__ directories"
# alternately: see/use https://docs.python.org/3/using/cmdline.html#envvar-PYTHONPYCACHEPREFIX

_python_path_additions () {
    local user_script_path
    case ${OSTYPE} in
        (darwin*)
            # I prefer manually maintained 'Official' Python over homebrew's dependency updated one
            # NB: installation will prepend it's versioned directory in ~/.bash_profile
            
            add_to_my_path /Library/Frameworks/Python.framework/Versions/Current/bin

            # Add most recent Python framework's pip install --user directory
            printf -v user_script_path "${HOME}/Library/Python/%s/bin" \
                   "$(find "${HOME}/Library/Python" -depth 0 -type d -exec ls -t1 {} + | head -1)"
            [[ -n  "$user_script_path" ]] && add_to_my_path "$user_script_path"
            vprintf 2 "Did %s (%s) add %s ?\n" "${FUNCNAME[0]}" "${BASH_SOURCE[1]}" "$user_script_path"
            # Would I do better by just identifying here tools that I install via pip --user?
            ;;
        (*)
            if type python3 &>/dev/null; then
                printf "using %s" "$(type -p python3)"
            else
                printf "No python3 in PATH"
            fi
            # ToDo what is the right thing on Linux, where system python3 does not install pip or pip3
            # (but linuxbrew adds it's own pip3)?
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
#unset _path_additions _virtualenv_setup
