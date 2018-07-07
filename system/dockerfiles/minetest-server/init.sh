#!/bin/bash

set -e
set -u
set -o pipefail

if ((EUID == 0)); then
    exec su - minetest -c "${BASH_SOURCE[0]}"
fi

# Unpack a default config if one isn't specified.
zcat /usr/share/doc/minetest/minetest.conf.example.gz \
    > "$HOME"/config/minetest.conf

/usr/games/minetestserver \
    --world "$HOME"/worlds/world \
    --config "$HOME"/config/minetest.conf
