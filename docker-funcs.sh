#!/usr/bin/env bash
# bash-docker.sh - docker related shell functions      -*- shell-script -*-

case ${OSTYPE} in
    (darwin*)
        APP_DIR="/Applications/Docker.app/Contents/Resources"
        add_to_my_path "${APP_DIR}/bin"
        ;;
    (*)
        APP_DIR=""
        ;;
esac

type docker &>/dev/null || return 1 # skip remainder if no docker

if [[ -n "$BASH_VERSION" ]]; then
    for cf in "${APP_DIR}"/etc/*bash*-completion; do
        . "$cf"
    done
elif [[ -n "$ZSH_VERSION" ]]; then
    for cf in "${APP_DIR}"/etc/*zsh*-completion; do
        . "$cf"
    done
fi

#trap "set +x" RETURN && set -x
#d () { command docker "$@"; }
di () { docker inspect "$@"; }
dr () { docker run "$@"; }
drit () { docker run -it --rm "$@"; }
drm () { docker rm "$@"; }
#dps () { docker ps; }

# Last run container ID
dl () { docker ps -l -q; }

function docker-run-latest () {
    latest=$(docker images -q | head -1)
    case $# in
        (0) args=/bin/bash
            ;;
        (*) args="$*"
            ;;
    esac
    echo docker run -it --rm "$latest" "$args"
    docker run -it --rm "$latest" "$args"
}

function docker-viz () {
    if [[ $# -eq 0 ]]; then
        VIS_ARGS="images --tree"
    else
        VIS_ARGS="$*"
    fi
    docker run --name dockviz -it --rm -v /var/run/docker.sock:/var/run/docker.sock \
           nate/dockviz "${VIS_ARGS}"
}

function docker-sen () {
    docker run --name sen --privileged -v /var/run/docker.sock:/run/docker.sock -it --rm -e TERM \
           tomastomecek/sen
}

function docker-jupyter () {
    echo docker run -p 8888:8888 -v "${PWD}":/home/jovyan/work jupyter/minimal-notebook
    docker run -p 8888:8888 -v "${PWD}":/home/jovyan/work jupyter/minimal-notebook
    # Can poke under the hood with
    # docker run -it --rm -v "${PWD}":/home/jovyan/work jupyter/minimal-notebook bash
}

function docker-volume-info () {
    for i in $(docker ps -a -q); do
        echo "container: $i"
        docker inspect --format '{{ range .Mounts }}{{ .Source }} => {{ .Destination }}{{ end }}' "$i"
    done
    for state in 'true' 'false'; do
        echo "dangling = $state"
        for i in $(docker volume ls -q --filter=dangling=${state}) ; do
            echo "container: $i"
            docker inspect "$i"
        done
    done
}

function docker-clean-images () {
    # Sigh, MacOS xargs
    local image_ids
    image_ids=$(docker images -a --filter=dangling=true -q)
    if [[ -n "$image_ids" ]]; then
        echo "$image_ids" | xargs docker rmi
    fi
}

function docker-clean-containers () {
    local container_ids
    container_ids=$(docker ps --filter=status=exited --filter=status=created -q)
    if [[ -n "$container_ids" ]]; then
        echo "$container_ids" | xargs docker rm
    fi
}

function docker-clean () {
    case $(docker version -f '{{.Server.Version}}') in
        (1.1[3-9]*)
            docker system prune
            ;;
        (*)
            docker-clean-containers
            docker-clean-images
            ;;
    esac
}

function docker-formatted-info () {
    FORMAT="\nID\t{{.ID}}\nIMAGE\t{{.Image}}\nCOMMAND\t{{.Command}}\nCREATED\t{{.RunningFor}}\nSTATUS\t{{.Status}}\nPORTS\t{{.Ports}}\nNAMES\t{{.Names}}\n"
    case "${1}" in
        (-c*)
            printf "container ls\n"
            docker container ls --format="${FORMAT}"
            ;;
        (-\?|-h*|help)
            printf "%s [p|c]\n" "$0"
            ;;
        (*)
            printf "ps\n"
            docker ps --format="${FORMAT}"
            ;;
    esac
}

dfi ()  { docker-formatted-info "$@" ; }

unset APP_DIR cf
