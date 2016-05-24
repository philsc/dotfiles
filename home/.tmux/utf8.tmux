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

# Version 2.2 sets these automatically if they're available.
if ((version <= 22)); then
    tmux set -g utf8 on
    tmux set -g status-utf8 on
fi
