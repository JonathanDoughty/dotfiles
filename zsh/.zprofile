#!/usr/bin/env zsh
# .zprofile - Executes commands at login before zshrc.

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

# Set the list of directories that cd searches.
# cdpath=(
#   $cdpath
# )

# Set the list of directories that Zsh searches for programs.
path=(
  /usr/local/{bin,sbin}
  /opt/homebrew/bin
  $path
)
