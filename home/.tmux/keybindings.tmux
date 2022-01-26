#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Parse the tmux version number. Strip all non-digits.
# Tmux 3.1c gets turned into "31" here.
# Tmux 2.8a gets turned into "28" here.
read _ TMUX_VERSION < <(tmux -V)
TMUX_VERSION="${TMUX_VERSION//[!0-9]/}"
readonly TMUX_VERSION

# Account for the bind key incompatiblity:
# https://github.com/tmux/tmux/blob/470cba356d8c81b4c669ef5d37a9798edf45d36f/CHANGES#L676
if ((TMUX_VERSION > 23)); then
  tmux bind -Tcopy-mode-vi 'v' send -X begin-selection
  tmux bind -Tcopy-mode-vi 'y' send -X copy-selection
else
  tmux bind -t vi-copy 'v' begin-selection
  tmux bind -t vi-copy 'y' copy-selection
fi
