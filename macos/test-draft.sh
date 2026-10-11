#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/promptslip-draft-tests.XXXXXX")
trap 'rm -rf -- "$TEST_DIR"' EXIT HUP INT TERM
BIN="$TEST_DIR/draft-tests"
xcrun clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=11.0 -framework Foundation "$ROOT/draft-tests.m" -o "$BIN"
"$BIN" load-save "$TEST_DIR"
"$BIN" restart "$TEST_DIR"
mkdir -p "$TEST_DIR/legacy-case"
"$BIN" legacy "$TEST_DIR/legacy-case"
