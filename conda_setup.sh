#!/usr/bin/env bash
# What conda would normally have added to ~/.bash_profile
# Because not every project uses the same conda setup.

[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

# Pick the most recently added, non-environment miniconda
ANACONDA_HOME="$(grep -v envs "$HOME"/.conda/environments.txt| tail -1)"

__conda_setup="$("${ANACONDA_HOME}"/bin/conda 'shell.bash' 'hook' 2> /dev/null)"
# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "${HOME}/.pyenv/versions/miniconda3-4.7.12/etc/profile.d/conda.sh" ]; then
        # shellcheck disable=SC1091
        . "${HOME}/.pyenv/versions/miniconda3-4.7.12/etc/profile.d/conda.sh"
    else
        export PATH="${HOME}/.pyenv/versions/miniconda3-4.7.12/bin:$PATH"
    fi
fi
unset __conda_setup
