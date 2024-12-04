#!/usr/bin/env bash

declare _git_version _shell='bash'

_git_version="$(git --version | cut -f 3 -d ' ')"

git_environment() {
    local CM
    CM=$(realpath "${HOME}/CM" 2>/dev/null)
    # Tell git not to look above home or my CM area
    export GIT_CEILING_DIRECTORIES="${HOME}${CM:+:}${CM}"
}

setup_completions() {
    # Look for / save / source a copy of git-completion that matches the git version
    [[ -n "$ZSH_VERSION" ]] && return # zsh has better git completion natively
    local url completions_file this_dir
    this_dir="$(dirname "$(readlink -n "${BASH_SOURCE[0]}")")"
    printf -v completions_file "%s/git-completion-v%s.%s" "$this_dir" "$_git_version" "$_shell"
    printf -v url "https://raw.githubusercontent.com/git/git/v%s/contrib/completion/git-completion.%s" \
           "$_git_version" "$_shell"
    if [[ ! -e "${completions_file}" ]]; then
        command rm -f "git-completion-v"*".${_shell}"
        command curl --silent "$url" -o "${completions_file}"
    fi
    source "$completions_file"
}

git_environment
setup_completions

# zsh provides handy equivalences
unset -v _git_version _shell
unset -f git_environment setup_completions
