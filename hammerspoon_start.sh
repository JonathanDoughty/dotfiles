#!/usr/bin/env bash

# Be sure initialization file is accessible
if [ -e ~/.hammerspoon/init.lua ]; then
    # Start hammerspoon using its CLI
    hash hs
    if [ -n "$(hash -t hs)" ]; then
        hs -A -s /dev/null
    fi
fi
