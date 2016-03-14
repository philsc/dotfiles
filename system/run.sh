#!/usr/bin/env bash

readonly DOTFILES_SALT="$(readlink -f "${BASH_SOURCE[0]%/*}")"
readonly ORIG_USER="${SUDO_USER:-}"
readonly TEMP_DIR="$(mktemp -d)"

cat > "$TEMP_DIR"/minion <<EOT
file_roots:
  base:
    - $DOTFILES_SALT/config
EOT

printf '%s' "$(hostname)" > "$TEMP_DIR"/minion_id

salt-call \
  --local \
  --config-dir="$TEMP_DIR" \
  state.highstate \
  "$@"

rm -rf "$TEMP_DIR"
