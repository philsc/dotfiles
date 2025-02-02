#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Enable true color support for alacritty.
if [[ $TERM == alacritty ]]; then
    tmux set -g default-terminal "$TERM"
    tmux set -ag terminal-overrides ",$TERM:Tc"
else
    tmux set -g default-terminal "screen-256color"
fi

# Make the scrollback buffers 'uge.
set -g history-limit 100000
