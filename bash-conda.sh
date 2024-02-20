#!/usr/bin/env bash

# An alternative is to `conda init` modify shell startup environments and then
# `conda config --set auto_activate_base false` to get conda to not complain about that and do
# a `conda activate base`
# See https://stackoverflow.com/a/61533565/1124740

# I prefer to activate_conda when I want to and not pollute all shells.

[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

function activate_conda {

    # conda's own instructions
    # eval "$(/usr/local/miniconda3/bin/conda shell.YOUR_SHELL_NAME hook)"
    #
    # To install conda's shell functions for easier access, first activate, then:
    #
    # conda init
    #
    # If you'd prefer that conda's base environment not be activated on startup,
    #    set the auto_activate_base parameter to false:
    #
    # conda config --set auto_activate_base false

    if [ -e "/usr/local/miniconda3" ]; then # My preference on Macos
        CONDA_BASE=/usr/local/miniconda3
    elif [ -e "/usr/local/CM/miniconda" ]; then  # e.g., AWS
        CONDA_BASE="/usr/local/CM/miniconda"
    elif [ -e "/opt/anaconda3" ]; then  # e.g., dhs00816-pc
        CONDA_BASE="/opt/anaconda3"
    elif [ -e "${HOME}/miniconda3" ]; then # Standard per Miniconda installation
        CONDA_BASE="${HOME}/miniconda3"
    else
        printf "\n\n*** Don't know where CONDA_BASE is on %s ***\n\n" "$(uname -n)"
    fi

    if [ -e "${CONDA_BASE}" ]; then
        eval "$("${CONDA_BASE}/bin/conda" shell."${SHELL##*/}" hook)"
    else
        printf "CONDA_BASE required for activation"
    fi
}
