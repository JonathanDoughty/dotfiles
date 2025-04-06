#!/usr/bin/env bash
# git command integration

# See also cli_prompt.sh for command line git info as part of prompt
# as well as shortcuts in misc-functions.sh

git_environment() {
    local CM
    CM=${CM_DIR:-$(realpath "${HOME}/CM" 2>/dev/null)}
    # Tell git not to look above home or my CM area
    export GIT_CEILING_DIRECTORIES="${HOME}${CM:+:}${CM}"
}

setup_completions() {
    # Look for / save / source a copy of git-completion that matches the git version
    [[ -n "$ZSH_VERSION" ]] && return # zsh has better git completion natively
    local _git_version _shell='bash'
    _git_version="$(git --version | cut -f 3 -d ' ')"
    local _src_url='https://raw.githubusercontent.com/git/git/v%s/contrib/completion'
    local completions_file script_dir
    script_dir="$(realpath "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
    printf -v completions_file "%s/git-completion-v%s.%s" "$script_dir" "$_git_version" "$_shell"
    if [[ ! -e "$completions_file" ]]; then
        local src_dir url
        # shellcheck disable=SC2059  # we want to use _src_url from above
        printf -v src_dir "$_src_url" "$_git_version"
        printf -v url "%s/git-completion.%s" "$src_dir" "$_shell"
        command rm -f "${script_dir}/git-completion-v"*".${_shell}"
        command curl --silent "$url" -o "${completions_file}"
    fi
    source "$completions_file"
}

git() {                         # wrapper to avoid blunders
    # One can't override commands with aliases - https://stackoverflow.com/q/3538774/1124740
    case "$1" in
        (am)
            printf 'Do you really want to apply patches from a mailbox? Try git-am\n'
            ;;
        (*)
            command git "$@"
            ;;
    esac
}

git_environment
setup_completions


unset -f git_environment setup_completions
