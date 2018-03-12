#!/bin/bash

# Inspired by the "Workflows that work" thread on /r/vim.
# https://www.reddit.com/r/vim/comments/7pmv3d/workflows_that_work/
#
# This script is intended to be triggered by your window manager. It creates a
# vim window. Type whatever you want in that window. When you close it, this
# script will paste whatever you typed into the window that was focused before
# vim was opened.

set -e
set -u
set -o pipefail

readonly terminal="$1"
readonly tempfile="$(mktemp)"

# Figure out who currently has focus.
window_id="$(xdotool getwindowfocus)"
readonly window_id

# Open vim in a new popup terminal.
"$terminal" -e vim -c "set noswapfile" "$tempfile"

# Strip the last byte which is the newline and make X paste everything into the
# window that was focused before vim popped up.
head -c -1 "$tempfile" \
  | xdotool type --window "$window_id" --clearmodifiers --delay 0 --file -

rm "$tempfile"
