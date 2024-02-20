#!/usr/bin/env bash

[[ $_ != "$0" ]] || { echo "This file must be sourced to be useful."; exit 1; }

if [ "$(type -t go)" ]; then
    GOROOT="$(go env GOROOT)" && export GOROOT
    GOPATH="$(go env GOPATH)" && export GOPATH
    [ -n "${GOROOT}" ] && add_to_my_path "${GOROOT}/bin" "${GOPATH}/bin"
fi
