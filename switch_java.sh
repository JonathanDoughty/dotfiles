#!/usr/bin/env bash
# switch_java
# Change current process environment so that specified Java run time is used

# With direnv the following in .envrc will work with this
#   . ~/CM/dotfiles/switch_java.sh
#   switch_java corretto-11

# For a more general solution try SDKMAN: http://sdkman.io/
# Pros: Works on Linux, Cygwin, MacOS; does not require sudo (installes into ~/.sdkman)
# Cons: Wants to install / control JDK and related tools like Maven, Groovy, ....
#       Does not (appear to) allow integration with existing tools from other package managers
#       like brew, brew casks, or self installed packages
#       Does not appear to have multiple choices of SDKs (Corretto, Zulu, ...)

[[ $_ != "$0" ]] || { printf "%s must be sourced to be useful." "$0"; exit 1; }

if ! type -t rpath &>/dev/null ; then
    # shellcheck disable=SC1090
    EXT_CMDS="$(script_source "path_add_remove")" && [ -e "$EXT_CMDS" ] && source "$EXT_CMDS"
fi

#export ANT_OPTS=-Dbuild.sysclasspath=ignore   # I do java little and ant less now

function switch_java {
    if [ "$1" == "-T" ]; then
        trap "set +x" RETURN && set -x # function debugging
        shift
    fi
    local BASE
    local LATEST M
    case ${OSTYPE} in
        (linux*)
            BASE=/opt/local/java  # my 'standard' for JVMs on Linux
            [ -d ${BASE} ] || BASE=/usr/local/java
            [ -d ${BASE} ] || BASE=/usr/java
            [ -d ${BASE} ] || BASE=/usr/lib/jvm
            [ -d ${BASE} ] || BASE=/etc/alternatives # reminder: /java_sdk*
            [ ! -d ${BASE} ] && echo "no local Java base" && return
            case $1 in
                (current)
                    LATEST="${BASE}/current"
                    ;;
                (14|java14)
                    LATEST="${BASE}/java-14"
                    ;;
                (11|java11)
                    LATEST="${BASE}/java-11"
                    ;;
                (8|java8)
                    LATEST="${BASE}/java8"
                    ;;
                (zulu8)
                    LATEST="${BASE}/zulu-8"
                    ;;
                (zulu11)
                    LATEST="${BASE}/zulu-11"
                    ;;
                (default) # CentOS standards
                    LATEST="/usr/java/default"
                    ;;
                (32)  # Any point in keeping this?
                    LATEST="/usr/lib/jvm/java-*.i386"
                    ;;
                (*)
                    echo "usage: ${FUNCNAME[0]} [current|java11|java14|java8|zulu8|zulu11|32]]"
                    case $(lsb_release -ds) in
                    (*CentOS*|*Fedora)
                        update-alternatives --list | grep java
                        ;;
                    (*Ubuntu*|*Debian*)
                        update-alternatives --list java
                        ;;
                    (*)
                        echo "Unknown variant $(lsb_release -ds)"
                        ;;
                    esac
            esac
            ;;
        (darwin*)
            local JAVAS JAVA
            # Yakshave: why the ridiculously tricky use of ${!prefix@} set up by this eval was necessary is now beyond me
            IFS=$'\r\n' GLOBIGNORE='*' \
               command eval "JAVAS=($(/usr/libexec/java_home -V 2>&1 | grep '^[	 ] *' | awk '{print $NF}'))"
            # Select the first installed java that matches first command line argument
            for i in ${!JAVAS[*]}; do
                JAVA="${JAVAS[$i]}"
                if [ "${JAVA/${1}/}" != "${JAVA}" ]; then
                    # Removing $1 from this java found a match; get the path
                    LATEST=${JAVA}
                    break
                fi
            done
            if [ -z "${LATEST}" ]; then
                printf "Select something unique from:\n"
                printf "\t%s\n" "${JAVAS[@]}"
            else
                : # printf "Selected %s\n" "${LATEST}"
            fi
            ;;
    esac
    if [ -n "${LATEST}" ]; then
        shopt -s nullglob
        M=("$LATEST")
        if [ -n "${M[0]}" ]; then
            LATEST="${M[(${#M[@]}-1)]}" #  last element of M
            [ -n "${JAVA_HOME}" ] && rpath "${JAVA_HOME}/bin"
            export JAVA_HOME=${LATEST}
            PATH=${JAVA_HOME}/bin:$PATH
        else
            echo "no match $LATEST"
        fi
        shopt -u nullglob
    fi
}

function switch_maven {
    # Change configuration so specified maven settings get used
    local BASE=~/.m2
    [ -d ${BASE} ] || return       # no maven settings here
    local LATEST M
    M=${BASE}/settings.xml
    case $1 in
        (artifactory|a*)
            LATEST="${BASE}/settings-artifactory.xml"
            ;;
        (proxy|p*)
            LATEST="${BASE}/settings-proxyonly.xml"
            ;;
        (minimal|m*)
            LATEST="${BASE}/settings-minimalxml"
            ;;
        (*)
            echo "usage: switch_maven [artifactory|proxy|minimal]"
    esac
    if [ -n "${LATEST}" ]; then
        if [ -L "$M" ] || [ ! -e "$M" ]; then
            \rm -f ${M}
            ln -s ${LATEST} ${M}
        else
            echo "${M} is not a symbolic link; NOT overriding"
        fi
    fi
    if [ -L "${M}" ]; then
        ls -l "${M}"
    else
        echo "no current settings"
    fi
}

# Bash completion
# shellcheck disable=SC1090
EXT_CMDS="$(script_source "external_java")" && [ -e "$EXT_CMDS" ] && source "$EXT_CMDS"
