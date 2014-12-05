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

# Adjust for some differences between the tmux versions. It appears that tmux
# before version 1.9 has trouble with the -c parameter for split-window.
if ((version <= 18)); then
    tmux bind-key '|' split-window -h
    tmux bind-key '-' split-window -v
else
    tmux bind-key '|' split-window -h -c "#{pane_current_path}"
    tmux bind-key '-' split-window -v -c "#{pane_current_path}"
fi
