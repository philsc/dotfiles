#!/usr/bin/env bash

function new() {
    echo -ne NEW "$@"
}

function warn() {
    echo -ne WARNING "$@"
}

function info() {
    echo -ne INFO "$@"
}

function setup_gnu_symlink() {
    local dir="$HOME/.bin"
    local link="$dir/$1"

    if [[ -L "$link" ]]; then
        info "Symlink $link already installed\n"
    elif [[ -e "$link" ]]; then
        warn "$link already exists, but is not a symlink\n"
    else
        new "Installing symlink $link\n"
        mkdir -p "$dir"
        ln -s "$(type -p g$1)" "$link"
    fi
}

if [[ "$(uname -s)" != Darwin ]]; then
    echo "No Darwin system detected"
    exit 1
fi

setup_gnu_symlink readlink
setup_gnu_symlink dircolors
setup_gnu_symlink rm
setup_gnu_symlink cp
setup_gnu_symlink ls
setup_gnu_symlink mktemp
setup_gnu_symlink chmod
setup_gnu_symlink chown
setup_gnu_symlink sed

# Disable the Dashboard
defaults write com.apple.dashboard mcx-disabled -boolean true
