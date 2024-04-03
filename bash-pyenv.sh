#!/usr/bin/env bash
# activate-pyenv - do when I choose what pyenv would have users embed in all shells

[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

function activate_pyenv {
    pyenv root &>/dev/null || ( echo "Need pyenv in PATH" && return 1 )
    PYENV_ROOT="$(pyenv root)" && export PYENV_ROOT
    if [ -n "${PYENV_ROOT}" ] ; then
        if [ -z "${PYENV_SHELL}" ]; then
            eval "$(pyenv init -)"
            export PATH="$PYENV_ROOT/bin:$PATH"
            eval "$(pyenv init --path)"
            eval "$(pyenv virtualenv-init -)"  # requires https://github.com/pyenv/pyenv-virtualenv
             # This next needed on MII according to https://mitrepedia.mitre.org/index.php/Python
             # Is this a problem elsewhere?
            export PYTHON_BUILD_ARIA2_OPTS="--async-dns=false"
        else
            echo "pyenv already activated"
        fi
    fi
}
