#!/usr/bin/env bash

# Functions are copied from
# https://github.com/tmux-plugins/tpm/blob/master/scripts/check_tmux_version.sh

# this is used to get "clean" integer version number. Examples:
# `tmux 1.9` => `19`
# `1.9a` => `19`
get_digits_from_string() {
    local string="$1"
    local only_digits="$(echo "$string" | tr -dC '[:digit:]')"
    echo "$only_digits"
}

tmux_version_int() {
    local tmux_version_string="$(tmux -V)"
    echo "$(get_digits_from_string "$tmux_version_string")"
}

version="$(tmux_version_int)"

# From the README:
# Due to the changes in tmux, the latest version of this plugin doesn't support
# tmux 2.3 and earlier.
# Using a special branch.
if ((version <= 23)); then
    tmux run-shell ~/.tmux/tmux-copycat-tmux-23/copycat.tmux
else
    tmux run-shell ~/.tmux/tmux-copycat/copycat.tmux
fi
