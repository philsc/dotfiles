#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

read _ TMUX_VERSION < <(tmux -V)
TMUX_VERSION="${TMUX_VERSION//\./}"
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
