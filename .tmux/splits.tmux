#!/usr/bin/env bash

# Figure out which socket we're connecting to.
readonly TMUX_SOCKET="$(echo "$TMUX" | cut -d, -f1)"

# Adjust for some differences between the tmux versions. It appears that tmux 
# before version 1.9 has trouble with the -c parameter for split-window.
if [[ "$(tmux -V)" =~ ^tmux\ 1\.8 ]]; then
    tmux -S "$TMUX_SOCKET" bind-key '|' split-window -h
    tmux -S "$TMUX_SOCKET" bind-key '-' split-window -v
else
    tmux -S "$TMUX_SOCKET" bind-key '|' split-window -h \
        -c "#{pane_current_path}"
    tmux -S "$TMUX_SOCKET" bind-key '-' split-window -v \
        -c "#{pane_current_path}"
fi
