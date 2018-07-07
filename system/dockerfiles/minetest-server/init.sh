#!/bin/bash

set -e
set -u
set -o pipefail
set -x

readonly MODFOLDER="$HOME/.minetest/mods"
readonly TMPFOLDER="/tmp/mods"

if ((EUID == 0)); then
    exec su - minetest -c "${BASH_SOURCE[0]}"
fi

# Unpack a default config if one isn't specified.
if [[ ! -r "$HOME"/config/minetest.conf ]]; then
    zcat /usr/share/doc/minetest/minetest.conf.example.gz \
        > "$HOME"/config/minetest.conf
fi

download_mod() {
    local -r name="$1"
    local -r url="$2"
    local tempdir

    if [[ -d "$MODFOLDER/$name" ]]; then
        echo "Mode $name already installed."
        return
    fi

    tempdir="$(mktemp -p "$TMPFOLDER" -d)"
    (
        cd "$tempdir"
        curl -L "$url" > mod.zip
        unzip mod.zip
    )

    local -a dirs=("$tempdir"/*/)

    if ((${#dirs[@]} != 1)); then
        echo "Found more than one folder in mod archive" >&2
        ls -l "$tempdir"
        exit 1
    fi

    mv -v "${dirs[0]}" "$MODFOLDER/$name"
}

enable_mod() {
    local -r name="$1"

    if [[ ! -r "$HOME"/worlds/world/world.mt ]]; then
        echo "Skipping enabling mod $name"
        return
    fi

    if ! grep -q "load_mod_$name = true" "$HOME"/worlds/world/world.mt; then
        echo "load_mod_$name = true" >> "$HOME"/worlds/world/world.mt
    fi
}

install_mod() {
    local -r name="$1"
    local -r url="$2"

    download_mod "$name" "$url"
    enable_mod "$name"
}

rm -rf "$TMPFOLDER"
mkdir -p "$TMPFOLDER"
install_mod ethereal https://notabug.org/TenPlus1/ethereal/archive/master.zip
install_mod mobs https://notabug.org/TenPlus1/mobs_redo/archive/master.zip
install_mod mobs_animal https://notabug.org/TenPlus1/mobs_animal/archive/master.zip
install_mod mobs_monster https://notabug.org/TenPlus1/mobs_monster/archive/master.zip
install_mod mobs_npc https://notabug.org/TenPlus1/mobs_npc/archive/master.zip
install_mod mob_horse https://notabug.org/TenPlus1/mob_horse/archive/master.zip
install_mod farming https://notabug.org/TenPlus1/Farming/archive/master.zip
install_mod ambience https://github.com/Neuromancer56/MinetestAmbience/archive/master.zip
install_mod craftguide https://github.com/minetest-mods/craftguide/archive/master.zip
install_mod item_drop https://github.com/minetest-mods/item_drop/archive/master.zip
install_mod minetest-3d_armor https://github.com/stujones11/minetest-3d_armor/archive/version-0.4.12.zip
install_mod snowdrift https://github.com/paramat/snowdrift/archive/master.zip
rm -rf "$TMPFOLDER"

/usr/games/minetestserver \
    --world "$HOME"/worlds/world \
    --config "$HOME"/config/minetest.conf
