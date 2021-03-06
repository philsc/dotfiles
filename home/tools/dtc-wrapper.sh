#!/usr/bin/env bash

set -e
set -u
set -x

readonly SRC="$1"
readonly DST="$2"

TEMP_FILE="$(mktemp)"
readonly TEMP_FILE

if [[ ${SRC##*.} == dts ]]; then
    cpp \
        -H \
        -nostdinc \
        -I "${SRC%/*}" \
        -I "$TOP"/include \
        -undef \
        -x \
        assembler-with-cpp \
        "$SRC" > "$TEMP_FILE" 2>/dev/null
else
    cp "$SRC" "$TEMP_FILE"
fi

dtc \
    -O "${DST##*.}" \
    -o "$DST" \
    -I "${SRC##*.}" \
    -i "${SRC%/*}" \
    "$TEMP_FILE"

rm -f "$TEMP_FILE"
