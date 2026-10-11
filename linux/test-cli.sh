#!/bin/sh
set -eu

APP=${1:-"$(dirname "$0")/build/promptslip"}
case "$APP" in /*) ;; *) APP="$(pwd)/$APP";; esac
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
OUT="$TMP/output dir"
mkdir -p "$OUT"
fail() { echo "FAIL: $*" >&2; exit 1; }

# Exact UTF-8 bytes, including CRLF and content larger than 1 MiB.
printf '日本語🙂\r\n' > "$TMP/input"
awk 'BEGIN { for (i=0; i<180000; i++) printf "長文🙂\r\n" }' >> "$TMP/input"
path=$("$APP" --stdin --output-dir "$OUT" --name 'my/../draft.md' < "$TMP/input") || fail 'valid stdin rejected'
case "$path" in /*) ;; *) fail 'stdout path is not absolute';; esac
test -f "$path" || fail 'reported file does not exist'
case "$path" in "$OUT"/*) ;; *) fail 'unsafe name escaped output directory';; esac
case "$path" in *.md) ;; *) fail 'default extension is not md';; esac
cmp "$TMP/input" "$path" || fail 'stdin bytes were changed'
path2=$("$APP" --stdin --output-dir "$OUT" --name 'my/../draft.md' < "$TMP/input") || fail 'second identical save rejected'
test "$path" != "$path2" || fail 'snapshot was overwritten/reused'
cmp "$TMP/input" "$path" || fail 'older snapshot changed'
reserved=$(printf 'device name' | "$APP" --stdin --output-dir "$OUT" --name CON)
case "$(basename "$reserved")" in CON.md|con.md) fail 'Windows reserved device name was retained';; esac

printf 'plain text\r\n' | "$APP" --stdin --output-dir "$OUT" --txt > "$TMP/txt-path" || fail 'txt output rejected'
grep -q '\.txt$' "$TMP/txt-path" || fail 'explicit txt extension missing'

expect_failure() {
    label=$1; shift
    before=$(find "$OUT" -type f | wc -l)
    if "$@" > "$TMP/stdout" 2> "$TMP/stderr"; then fail "$label unexpectedly succeeded"; fi
    test ! -s "$TMP/stdout" || fail "$label wrote stdout"
    after=$(find "$OUT" -type f | wc -l)
    test "$before" = "$after" || fail "$label created an attachment"
}
expect_failure empty sh -c '"$1" --stdin --output-dir "$2"' sh "$APP" "$OUT" < /dev/null
printf '\377\376' > "$TMP/invalid"
expect_failure invalid-utf8 sh -c '"$1" --stdin --output-dir "$2"' sh "$APP" "$OUT" < "$TMP/invalid"
expect_failure unknown-flag "$APP" --stdin --output-dir "$OUT" --oops
expect_failure conflicting-inputs "$APP" --stdin --clipboard --output-dir "$OUT"
expect_failure missing-value "$APP" --stdin --output-dir

echo 'PASS: Linux CLI acceptance (UTF-8/CRLF, >1 MiB, snapshots, sanitization, TXT, errors)'
