#!/bin/bash
# Example installation of controlled access / sensitive content

# PERSONAL_INSTALL from environment or locally defined should point to this script
[[ -e ${PERSONAL_INSTALL} ]] || CUSTOM_DIR="/path/to/custom/repo/directory"
CUSTOM_DIR=${CUSTOM_DIR:-$(dirname "$PERSONAL_INSTALL")}

# Installation
custom_installation () {
    if [ -d "${CUSTOM_DIR}" ]; then
        # Examples of common files with more or less sensitive contents
        vprintf 1 "Installing links to/copies of controlled access files"

        link_if_not_present "${CUSTOM}/ssh" "${HOME}/.ssh"
        link_if_not_present "${RESTRICTED}/.netrc"
        copy_if_not_present_to_dir "${RESTRICTED}/some/file" "${HOME}"
        case "${OS}" in
            (Darwin)
                # I don't want these installed on other platforms
                link_if_not_present "${CUSTOM}/cloud_credentials" "${HOME}/.mumble"
                ;;
            (Linux)
                # Only on certain hosts
                check_source "${RESTRICTED}/*${HOSTNAME}*"
                if [ -n "${SOURCE}" ]; then
                    : # Similarly with some Linux specific contents
                fi
                ;;
        esac
    else
        vprintf 0 "No custom contents %s, skipping" "$CUSTOM"
    fi
}

custom_installation
