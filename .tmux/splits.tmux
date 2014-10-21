#!/usr/bin/env bash

# Adjust for some differences between the tmux versions. It appears that tmux 
# before version 1.9 has trouble with the -c parameter for split-window.
if [[ "$(tmux -V)" =~ ^tmux\ 1\.8 ]]; then
    tmux bind-key '|' split-window -h
    tmux bind-key '-' split-window -v
else
    tmux bind-key '|' split-window -h -c "#{pane_current_path}"
    tmux bind-key '-' split-window -v -c "#{pane_current_path}"
fi
