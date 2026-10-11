#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=${1:-"$HERE/build/promptslip"}
mkdir -p "$(dirname -- "$OUT")"
CC=${CC:-cc}
if ! command -v pkg-config >/dev/null 2>&1; then
    echo 'build.sh: pkg-config is required' >&2; exit 1
fi
if ! pkg-config --exists gtk+-3.0; then
    echo 'build.sh: GTK 3 development files are required (pkg-config gtk+-3.0)' >&2; exit 1
fi
"$CC" -std=c11 -O2 -Wall -Wextra -Wformat=2 -Werror=implicit-function-declaration \
    -o "$OUT" "$HERE/promptslip.c" $(pkg-config --cflags --libs gtk+-3.0)
printf 'Built %s\n' "$OUT"
