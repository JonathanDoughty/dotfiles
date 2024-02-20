#!/bin/bash

# YakShave: replace with https://github.com/andsens/homeshick

usage () {
        cat <<EOF
${0##*/} - create symbolic links to/copy configuration managed dot files

-? -h     - This help
-d        - Debug by creating missing links and copies in /tmp/$PPID, not $HOME
-n        - Do a dry run: print what would be linked or copied
-s        - skip sourcing ${CONTROLLED}
-v        - Be verbose, repeated -v arguments add verbosity:
            1: terse, 2: chatty, 3: report intent, 4: expand commands on execution

If ${CONTROLLED} exists it is sourced to create symbolic links to controlled access files that
might have sensitive contents. Borrowers don't have a need to know the details of that.

Note that a minority of files get copied to their destination rather than symlinked. That's
because, for me, the filesystem these live on is not always available when I first log in.

EOF
        exit
}

# Configuration

OS=$(uname -s)
HOSTNAME=$(hostname -s)
HOSTNAME=${HOSTNAME%%[-]*}      # strip off any multi-interface name components

DOT_PATH="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"  # This directory
CACHE_PATH="${HOME}/Downloads"
CM_ROOT=/Volumes/CM             # Currently used only for .editorconfig
EMACS_PATH="${HOME}/CM/emacs"
MAVEN_PATH="${CACHE_PATH}/MavenRepository"
GRADLE_PATH="${CACHE_PATH}/Gradle"
CONTROLLED="install-controlled.sh"
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

check_source () {
    # Check if source exists and return corresponding result path
    [[ $VERBOSE -gt 1 ]] && printf "\nChecking args 1:%s 2:%s\n" "$1" "$2"
    [[ $DEBUG -gt 1 ]] && trace "$LINENO" "${BASH_LINENO[@]}"
    SOURCE=$1
    if [ ! -e "${SOURCE}" ]; then
        printf "\nWARNING: %s does not exist, skipping\n" "${SOURCE}"
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
            mkdir -p "${RESULT_PATH%/*}" # insure fake directory hierarchy
        fi
    fi
}

maybe () {
    local cmd=( "$@" )
    [[ $VERBOSE -gt 1 || $DRY_RUN -gt 0 ]] && printf "%s\n" "${cmd[*]}"
    if [[ $DRY_RUN -eq 0 ]]; then
        eval "${cmd[*]}"
    fi
}

link_if_not_present () {
    # Create a symlink to source at target (default is $HOME)
    # args: source [target_file]
    test $VERBOSE -gt 2 && printf "Linking %s\n" "$*"
    check_source "$@"
    if [ -z "${SOURCE}" ]; then
        return 1
    else
        # yakshave: make the required hierarchy here and clean up the extraneous mkdir
        #[[ -e "$(dirname "$RESULT_PATH")" ]] || mkdir -p "$(dirname "$RESULT_PATH")"
        LINK_PATH=${RESULT_PATH}
    fi

    test $VERBOSE -gt 2 && printf "... linking to %s if %s not present\n" "${SOURCE}" "${LINK_PATH}"
    if [ ! -e "${LINK_PATH}" ] && [ ! -L "${LINK_PATH}" ]; then
        test $VERBOSE -gt 0 && echo "... creating ${LINK_PATH} symlink"
        maybe ln -s "${SOURCE}" "${LINK_PATH}"
    elif [ -L "${LINK_PATH}" ]; then
        if [ "$(readlink "${LINK_PATH}")" != "${SOURCE}" ]; then
            test $VERBOSE -gt 0 && echo "... replacing ${LINK_PATH} symlink"
            maybe rm "${LINK_PATH}"
            maybe ln -s "${SOURCE}" "${LINK_PATH}"
        else
            test $VERBOSE -gt 1 && echo "... not replacing identical ${LINK_PATH} symlink"
        fi
    else
        printf "\nWARNING: %s exists as file/directory; skipping\n" "${SOURCE}"
        return 1
    fi
}

copy_source_to_dest() {
    # Create a copy of source(s) at target
    [[ $DEBUG -gt 1 ]] && trace "$LINENO" "${BASH_LINENO[@]}"
    local SOURCE="$1"
    local DEST="$2"
    test $VERBOSE -gt 0 && echo "Copying ${SOURCE} to ${DEST}"
    [[ "$DEBUG" -gt 1 ]] && trap "set +x" RETURN && set -x
    if [ -e "${SOURCE}/.git" ]; then
        test $VERBOSE -gt 0 && echo "exporting ${SOURCE} git archive to $DEST"
        (maybe cd "$SOURCE" && maybe git archive --format=tar ) | (maybe cd "$DEST" && maybe tar xf -)
    else
        test $VERBOSE -gt 0 && echo "recursively copying ${SOURCE} into ${DEST}"
        maybe cp -Ri "${SOURCE}" "${DEST}"
    fi
}

copy_if_not_present_to_dir () {
    # Check if source is present and, if not, create a copy in target directory
    # args: source [target directory]

    # This handles the few critical files where a symlink might not work due to
    # the symlink target filesystem being inaccessible.

    test $VERBOSE -gt 2 && printf "Copying %s\n" "$*"
    check_source "$@"
    if [ -z "${SOURCE}" ]; then
        return
    else
        DEST_PATH="${RESULT_PATH}"
    fi

    if [[ ! -d "${SOURCE}" ]]; then
        DEST_PATH="${DEST_PATH}/${SOURCE##*/}"
    fi

    [[ $VERBOSE -gt 2 || $DEBUG -gt 1 ]] && printf "  copying %s if not present in %s\n" "${SOURCE}" "${DEST_PATH}"
    if [ -d "${SOURCE}" ] && [ ! -e "${DEST_PATH}" ]; then
        copy_source_to_dest "$SOURCE" "$DEST_PATH"
    elif [ ! -e "${DEST_PATH}" ] && [ ! -L "${DEST_PATH}" ] || [ -d "${DEST_PATH}" ]; then
        if [ ! -d "$DEST_PATH" ] && cmp -s "$SOURCE" "$DEST_PATH" ; then
            test $VERBOSE -gt 1 && echo "... not copying ${SOURCE} to unchanged ${DEST_PATH}"
        else
            [[ -e "${DEST_PATH}" && ! -w "${DEST_PATH}" ]] && maybe chmod u+w "${DEST_PATH}"  # Undo protection below
            copy_source_to_dest "${SOURCE}" "${DEST_PATH}"
            maybe chmod u-w "${DEST_PATH}"  # Make it harder for me to edit single files copied
        fi
    elif [ -L "${DEST_PATH}" ]; then
        test $VERBOSE -gt 0 && echo "...  replacing ${DEST_PATH} symlink with copy"
        [ ! -w "${DEST_PATH}" ] && maybe chmod u+w "${DEST_PATH}"  # Undo protection below
        maybe rm "${DEST_PATH}"
        maybe cp "${SOURCE}" "${DEST_PATH}"
        maybe chmod u-w "${DEST_PATH}"  # Force me to be deliberate to edit single files copied
        return
    else
        echo "WARNING: ${DEST_PATH} exists as file/directory; skipping"
        return 1
    fi
}

shell_init_files () {
    test $VERBOSE -gt 1 && printf "Initializing shell configuration\n\n"

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
    test $VERBOSE -gt 1 && printf "\nInitializing rc files\n\n"
    mkdir -p "${HOME}/.config/bat"
    link_if_not_present "${DOT_PATH}/bat.config" "${HOME}/.config/bat/config"
    mkdir -p "${HOME}/.config/cheat"
    link_if_not_present "${DOT_PATH}/cheat.yml" "${HOME}/.config/cheat/conf.yml"
    mkdir -p "${HOME}/.config/direnv"
    link_if_not_present "${DOT_PATH}/direnvrc" "${HOME}/.config/direnv/direnvrc"
    # wezterm's nice but Terminal is sufficient again
    #mkdir -p "${HOME}/.config/wezterm"
    #link_if_not_present "${DOT_PATH}/wezterm.lua" "${HOME}/.config/wezterm/wezterm.lua"
    link_if_not_present "${EMACS_PATH}" "${HOME}/.emacs.d"
    link_if_not_present "${DOT_PATH}/.digrc"
    link_if_not_present "${DOT_PATH}/.editorconfig"
    link_if_not_present "${DOT_PATH}/.gitconfig"
    link_if_not_present "${DOT_PATH}/.gitignore_global"
    link_if_not_present "${DOT_PATH}/.gituser"
    link_if_not_present "${DOT_PATH}/.lessfilter"
    link_if_not_present "${DOT_PATH}/.ripgreprc"
    link_if_not_present "${DOT_PATH}/.tmux.conf"
    link_if_not_present "${DOT_PATH}/.tmux"
}

developer_apps () {
    test $VERBOSE -gt 1 && printf "\nInitializing developer files\n\n"
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
    test $VERBOSE -gt 1 && printf "\nMaking %s specific links\n\n" "$OS"

    case "${OS}" in
        (Darwin)
            copy_if_not_present_to_dir "${DOT_PATH}/Justfile" "${HOME}"
            copy_if_not_present_to_dir "${DOT_PATH}/login_actions.sh" "${HOME}"
            link_if_not_present "${DOT_PATH}/.gitconfig-macos"
            link_if_not_present "${DOT_PATH}/.logrc"
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
    if [[ -e "$CONTROLLED" ]]; then
        if [[ "$SKIP_SENSITIVE" -eq 0 ]]; then
            printf "Sourcing %s\n" "$CONTROLLED"
            # shellcheck disable=SC1090
            ( . "$CONTROLLED" )
        else
            printf "Skipping %s\n" "$CONTROLLED"
        fi
    fi
    [[ -e "$TMP_DIR" ]] && {
        printf "Fake results created in %s\n" "$TMP_DIR"
    }
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
