#!/usr/bin/env bash

set -e
set -u
set -x

readonly TOP="$(readlink -f "$(pwd)")"
readonly SRC="$1"
readonly DST="$2"

TEMP_FILE="$(mktemp)"
readonly TEMP_FILE

cpp \
    -nostdinc \
    -I "${SRC%/*}" \
    -I "$TOP"/include \
    -undef \
    -x \
    assembler-with-cpp \
    "$SRC" > "$TEMP_FILE" 2>/dev/null

"$TOP"/scripts/dtc/dtc \
    -O "${DST##*.}" \
    -o "$DST" \
    -i "${SRC%/*}" \
    "$TEMP_FILE"

rm -f "$TEMP_FILE"
