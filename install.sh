#!/bin/bash

# YakShave: replace with https://github.com/andsens/homeshick
# YakShave: replace the installation functions with a table driven array
# YakShave: given a table driven array, implement an uninstall to restore state

usage () {
        cat <<EOF
${0##*/} - create symbolic links to/copy configuration managed dot files

-d      - Debug creating links and copies in default /tmp/$PPID, not $HOME
-n      - Dry run: print what would be linked or copied
-s      - Skip sourcing ${CUSTOM}
-v      - Be verbose, repeated -v arguments add verbosity:
          1: terse 2: chatty 3: report intent 4: expand commands on execution
-? -h   - This help

If ${CUSTOM} exists it is sourced after the
remaining set up has completed.

The custom script can, e.g., create symbolic links to controlled access files
having sensitive contents not to be included here using any of the functions
defined here. As an example I use that to set up my ~/.ssh contents.

Note that a minority of files get copied to their destination rather than
symlinked. For some, on macOS the filesystem these live on is not always
available when I first log in. Others are directory hierarchies I want to
re-create.

EOF
        exit
}

# Configuration

OS=$(uname -s)
HOSTNAME=$(hostname -s)
HOSTNAME=${HOSTNAME%%[-]*}      # strip off any multi-interface name components

DOT_PATH="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"  # This directory
CONFIGS="${HOME}/.config"
CACHE_PATH="${HOME}/Downloads"
CM_DIR=${CM_DIR:-${DOT_PATH}}   # from environment or this directory
CM_ROOT=$(dirname "${CM_DIR}")
EMACS_PATH="${HOME}/CM/emacs"
MAVEN_PATH="${CACHE_PATH}/MavenRepository"
GRADLE_PATH="${CACHE_PATH}/Gradle"
EMACS_BACKUP="${CACHE_PATH}/EmacsBackups"
CUSTOM="${CUSTOM:-/path/to/custom_installation_script}"
INIT_DB=0                       # Skip database related unless > 0
INIT_JAVA=0                     # Skip Java related unless > 0
INIT_PYTHON=1                   # Skip python related unless > 0

declare -i VERBOSE=0 DRY_RUN=0 DEBUG=0 SKIP_SENSITIVE=0

trace() {
    # Help me debug some issues
    # Adapted from https://unix.stackexchange.com/a/529287/13887
    local -i _lineno="${1:-LINENO}"
    local -i _bash_lineno="${2:-BASH_LINENO}"

    local -a _output_array=()
    _output_array+=(
        '---'
        "  lines history: [${_lineno} ${_bash_lineno[*]}]"
        "  function trace: [${FUNCNAME[*]}]"
        '---'
    )
    printf '%s\n' "${_output_array[@]}" >&2
}

vprintf () {
    # At verbosity >= first arg level output remainder to stderr
    local level=$1 fmt="$2\n" && shift 2
    # shellcheck disable=SC2059 # the point is to pass in fmt
    [[ $VERBOSE -ge $level ]] && printf "$fmt" "$@" 1>&2
}

check_source () {
    # Check if source exists and return corresponding result path
    vprintf 3 "Checking args 1:%s 2:%s" "$1" "$2"
    [[ $DEBUG -gt 1 ]] && trace "$LINENO" "${BASH_LINENO[@]}"
    SOURCE=$1
    if [ ! -e "${SOURCE}" ]; then
        vprintf 1 "WARNING: %s does not exist, skipping" "${SOURCE}"
        SOURCE=
        return
    fi
    if [ -z "$2" ]; then
        RESULT_PATH="${HOME}/${SOURCE##*/}"
    elif [ -d "$2" ]; then
        RESULT_PATH="${2}"
    else
        RESULT_PATH="${2}"
    fi
    if [[ $DEBUG -gt 0 ]]; then
        RESULT_PATH="${TMP_DIR}${RESULT_PATH}"
        if [[ ! -d "${RESULT_PATH%/*}" ]]; then
            mkdir -p "${RESULT_PATH%/*}" # insure debug directory hierarchy
        fi
    fi
}

maybe () {
    local cmd
    declare -i level=3          # normally only print cmd at the most verbose
    if [[ $1 =~ ^[0-9]$ ]]; then
        # Treat leading digits as desired verbose level, not as part of command
        level=$1
        shift
    fi
    cmd=( "$@" )
    if [[ $DRY_RUN -eq 0 ]]; then
        vprintf $level "%s" "${cmd[*]}"
        eval "${cmd[*]}"
    else
        vprintf 0 "%s" "${cmd[*]}"
    fi
}

link_if_not_present () {
    # Create a symlink to source at target (default target is same file name in $HOME)
    # args: source [target_file]
    vprintf 2 "Linking %s" "$*"
    check_source "$@"
    if [ -z "${SOURCE}" ]; then
        return 1
    else
        if [[ ! -e "$(dirname "$RESULT_PATH")" ]]; then
            # Make the required hierarchy or return if permission denied
            # Should this be part of check_source's debug RESULT_PATH assurance?
            mkdir -p "$(dirname "$RESULT_PATH")" || return 1
        fi
        LINK_PATH=${RESULT_PATH}
    fi

    vprintf 3 "Linking to %s if %s not present" "${SOURCE}" "${LINK_PATH}"
    if [ ! -e "${LINK_PATH}" ] && [ ! -L "${LINK_PATH}" ]; then
        vprintf 1 "Creating %s symlink" "${LINK_PATH}"
        maybe 2 ln -s "${SOURCE}" "${LINK_PATH}"
    elif [ -L "${LINK_PATH}" ]; then
        if [ "$(readlink "${LINK_PATH}")" != "${SOURCE}" ]; then
            vprintf 1 "Replacing %s symlink" "${LINK_PATH}"
            maybe 2 rm "${LINK_PATH}"
            maybe 2 ln -s "${SOURCE}" "${LINK_PATH}"
        else
            vprintf 1 "Not replacing identical %s symlink" "${LINK_PATH}"
        fi
    else
        vprintf 0 "WARNING: %s exists as file/directory; skipping" "${SOURCE}"
        return 1
    fi
}

copy_source_to_dest() {
    # Create a copy of source(s) at target
    [[ $DEBUG -gt 1 ]] && trace "$LINENO" "${BASH_LINENO[@]}"
    local SOURCE="$1"
    local DEST="$2"
    vprintf 1 "Copying %s to %s" "${SOURCE}" "${DEST}"
    [[ "$DEBUG" -gt 1 ]] && trap "set +x" RETURN && set -x
    if [ -e "${SOURCE}/.git" ]; then
        vprintf 1 "Exporting %s git archive to %s" "${SOURCE}" "$DEST"
        (maybe 2 cd "$SOURCE" && maybe git archive --format=tar ) | \
            (maybe 2 cd "$DEST" && maybe tar xf -)
    else
        vprintf 1 "Recursively copying %s into %s" $"${SOURCE}" "${DEST}"
        maybe 2 cp -Ri "${SOURCE}" "${DEST}"
    fi
}

copy_if_not_present_to_dir () {
    # Check if source is present and, if not, create a copy in target directory
    # args: source [target directory]

    # This handles the few critical files where a symlink might not work due to
    # the symlink target filesystem being inaccessible.

    vprintf 2 "Copying %s" "$*"
    check_source "$@"
    if [ -z "${SOURCE}" ]; then
        return
    else
        DEST_PATH="${RESULT_PATH}"
    fi

    if [[ ! -d "${SOURCE}" ]]; then
        DEST_PATH="${DEST_PATH}/${SOURCE##*/}"
    fi

    vprintf 2 "Copying %s if not present in %s" "${SOURCE}" "${DEST_PATH}"
    if [ -d "${SOURCE}" ] && [ ! -e "${DEST_PATH}" ]; then
        copy_source_to_dest "$SOURCE" "$DEST_PATH"
    elif [ ! -e "${DEST_PATH}" ] && [ ! -L "${DEST_PATH}" ] || [ -d "${DEST_PATH}" ]; then
        if [ ! -d "$DEST_PATH" ] && cmp -s "$SOURCE" "$DEST_PATH" ; then
            vprintf 1 "Not copying %s to unchanged %s" "${SOURCE}" "${DEST_PATH}"
        else
            [[ -e "${DEST_PATH}" && ! -w "${DEST_PATH}" ]] && maybe chmod u+w "${DEST_PATH}"  # Undo protection below
            copy_source_to_dest "${SOURCE}" "${DEST_PATH}"
            maybe chmod u-w "${DEST_PATH}"  # Make it harder for me to edit single files copied
        fi
    elif [ -L "${DEST_PATH}" ]; then
        vprintf 1 "Replacing %s symlink with copy" "${DEST_PATH}"
        [ ! -w "${DEST_PATH}" ] && maybe chmod u+w "${DEST_PATH}"  # Undo protection below
        maybe 2 rm "${DEST_PATH}"
        maybe 2 cp "${SOURCE}" "${DEST_PATH}"
        maybe chmod u-w "${DEST_PATH}"  # Force me to be deliberate to edit single files copied
        return
    else
        echo "WARNING: ${DEST_PATH} exists as file/directory; skipping"
        return 1
    fi
}

shell_init_files () {
    vprintf 1 "Initializing shell configuration"

    case "${OS}" in
        (Darwin)
            link_if_not_present "${DOT_PATH}/.bashrc"
            # Copy this since symlinks depend on mounted sparseimage
            copy_if_not_present_to_dir "${DOT_PATH}/.bash_profile" "${HOME}"
            link_if_not_present "${DOT_PATH}/zsh/.zshenv" # sets ZDOTDIR, obviating others
            ;;
        (*)
            link_if_not_present "${DOT_PATH}/.bashrc"
            if [ $? ]; then
                # For systems that create .bashrc that references .bash_aliases
                link_if_not_present "${DOT_PATH}/.bashrc" "${HOME}/.bash_aliases"
            fi
            link_if_not_present "${DOT_PATH}/.bash_profile"
            ;;
    esac
    link_if_not_present "${DOT_PATH}/.bash_${HOSTNAME}"
    link_if_not_present "${DOT_PATH}/.bash_${OS}"
}

app_rcfiles () {
    vprintf 1 "Initializing rc files"
    mkdir -p "${CONFIGS}/bat"
    link_if_not_present "${DOT_PATH}/bat.config" "${CONFIGS}/bat/config"
    mkdir -p "${CONFIGS}/cheat"
    link_if_not_present "${DOT_PATH}/cheat.yml" "${CONFIGS}/cheat/conf.yml"
    mkdir -p "${CONFIGS}/direnv"
    link_if_not_present "${DOT_PATH}/direnvrc" "${CONFIGS}/direnv/direnvrc"
    link_if_not_present "${DOT_PATH}/direnv.toml" "${CONFIGS}/direnv/direnv.toml"
    link_if_not_present "${DOT_PATH}/starship.toml" "${CONFIGS}/starship.toml"
    # wezterm's nice but Terminal is sufficient again
    #mkdir -p "${CONFIGS}/wezterm"
    #link_if_not_present "${DOT_PATH}/wezterm.lua" "${CONFIGS}/wezterm/wezterm.lua"
    link_if_not_present "${EMACS_PATH}" "${HOME}/.emacs.d"
    mkdir -p "$EMACS_BACKUP"    # Insure it exists
    link_if_not_present "${DOT_PATH}/mg" "${HOME}/.mg"
    link_if_not_present  "$EMACS_BACKUP" "${HOME}/.mg.d"
    link_if_not_present "${DOT_PATH}/.digrc"
    link_if_not_present "${DOT_PATH}/.editorconfig"
    link_if_not_present "${DOT_PATH}/.gitconfig"
    link_if_not_present "${DOT_PATH}/.gitignore_global"
    link_if_not_present "${DOT_PATH}/.gituser"
    link_if_not_present "${DOT_PATH}/.lessfilter"
    link_if_not_present "${DOT_PATH}/.ripgreprc"
    link_if_not_present "${DOT_PATH}/.shellcheckrc"
    link_if_not_present "${DOT_PATH}/.tmux.conf"
    link_if_not_present "${DOT_PATH}/.tmux"
}

developer_apps () {
    vprintf 1 "Initializing developer files"
    if [ "$INIT_JAVA" -gt 0 ]; then
        copy_if_not_present_to_dir "${DOT_PATH}/.gradle" "${GRADLE_PATH}"
        link_if_not_present "${GRADLE_PATH}" "${HOME}/.gradle"
        copy_if_not_present_to_dir "${DOT_PATH}/.m2" "${MAVEN_PATH}"
        link_if_not_present "${MAVEN_PATH}" "${HOME}/.m2"
    fi
    [[ "$INIT_DB" -gt 0 ]] && link_if_not_present "${DOT_PATH}/.psqlrc"
    if [ "$INIT_PYTHON" -gt 0 ]; then
        link_if_not_present "${DOT_PATH}/.pylintrc"
    fi
}

os_specific () {
    vprintf 1 "Making %s specific links" "$OS"

    case "${OS}" in
        (Darwin)
            copy_if_not_present_to_dir "${DOT_PATH}/login_actions.sh" "${HOME}"
            link_if_not_present "${DOT_PATH}/.gitconfig-macos"
            #link_if_not_present "${DOT_PATH}/.logrc"
            # also link editorconfig at root of CM volume
            link_if_not_present "${DOT_PATH}/.editorconfig" "${CM_ROOT}/.editorconfig"
            ;;
        (Linux)
            link_if_not_present "${DOT_PATH}/.gitconfig-linux"
            ;;
    esac
}

install () {
    test $VERBOSE -gt 3 && set -x
    test $DEBUG -gt 0 && TMP_DIR=/tmp/$PPID # parent PID so repeats are possible

    shell_init_files            # First the login shell bits
    app_rcfiles                 # Followed by other rc files
    developer_apps              # Developer set up
    os_specific                 # Those that vary slightly by OS
    if [[ -e "$CUSTOM" ]]; then
        if [[ "$SKIP_SENSITIVE" -eq 0 ]]; then
            vprintf 1 "Sourcing %s" "$CUSTOM"
            ( . "$CUSTOM" )
        else
            vprintf 0 "Skipping %s" "$CUSTOM"
        fi
    fi
    [[ -e "$TMP_DIR" ]] && {
        vprintf 0 "Debug results created in %s" "$TMP_DIR"
    }
    return 0
}

while getopts "dhnsv?" optionName; do
    case "$optionName" in
        (d) DEBUG=$((DEBUG+1)) ;;     # create copies/links in temporary directory, provide extra info
        (n) DRY_RUN=$((DRY_RUN+1)) ;; # report - don't do
        (s) SKIP_SENSITIVE=$((SKIP_SENSITIVE+1)) ;; # as it says
        (v) VERBOSE=$((VERBOSE+1)) ;; # terse, chatty, report intent, expand commands as exceuted
        (h|\?|*) usage;;
    esac
done
install
