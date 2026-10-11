#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP=${1:-"$HERE/build/promptslip"}
if ! command -v xvfb-run >/dev/null 2>&1 || ! command -v timeout >/dev/null 2>&1 ||
   ! command -v xdotool >/dev/null 2>&1 || ! pkg-config --exists gtk+-3.0 x11; then
    echo 'SKIP: GUI smoke requires Xvfb, xdotool, timeout, and GTK 3/X11 development files.'
    exit 77
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
cc -std=c11 -O2 -o "$TMP/receiver" "$HERE/smoke-receiver.c" $(pkg-config --cflags --libs gtk+-3.0 x11)
export XDG_DATA_HOME="$TMP/data"
mkdir -p "$XDG_DATA_HOME/pastedrop"
printf 'legacy Linux draft\n' > "$XDG_DATA_HOME/pastedrop/draft.txt"
export PROMPTSLIP_APP="$APP" PROMPTSLIP_RECEIVER="$TMP/receiver" PROMPTSLIP_RESULT="$TMP/received"
export PROMPTSLIP_LOG="$TMP/app.log" PROMPTSLIP_RECEIVER_LOG="$TMP/receiver.log"
set +e
timeout 45s xvfb-run -a sh -eu -c '
  "$PROMPTSLIP_RECEIVER" "$PROMPTSLIP_RESULT" >"$PROMPTSLIP_RECEIVER_LOG" 2>&1 & receiver=$!
  "$PROMPTSLIP_APP" >"$PROMPTSLIP_LOG" 2>&1 & app=$!
  trap "kill $app $receiver 2>/dev/null || true" EXIT HUP INT TERM
  appw=; recvw=
  for i in $(seq 1 80); do
    appw=$(xdotool search --name "PromptSlip.*Drag text" 2>/dev/null | head -n 1 || true)
    recvw=$(xdotool search --name "test receiver" 2>/dev/null | head -n 1 || true)
    [ -n "$appw" ] && [ -n "$recvw" ] && break
    sleep 0.1
  done
  [ -n "$appw" ] && [ -n "$recvw" ] || { cat "$PROMPTSLIP_LOG" >&2; exit 1; }
  for i in $(seq 1 50); do [ -f "$XDG_DATA_HOME/promptslip/draft.txt" ] && break; sleep 0.1; done
  cmp "$XDG_DATA_HOME/pastedrop/draft.txt" "$XDG_DATA_HOME/promptslip/draft.txt"
  test "$(cat "$XDG_DATA_HOME/pastedrop/draft.txt")" = "legacy Linux draft"
  xdotool windowmove "$appw" 0 0
  xdotool windowmove "$recvw" 800 200
  xdotool windowfocus --sync "$appw"
  xdotool mousemove --window "$appw" 300 220 click 1 key ctrl+a type --clearmodifiers latest-text-for-drag-check
  height=$(xdotool getwindowgeometry --shell "$appw" | sed -n "s/^HEIGHT=//p")
  dest_x=$(xdotool getwindowgeometry --shell "$recvw" | sed -n "s/^X=//p")
  dest_y=$(xdotool getwindowgeometry --shell "$recvw" | sed -n "s/^Y=//p")
  drag_y=$((height - 90))
  dest_x=$((dest_x + 160)); dest_y=$((dest_y + 90))
  xdotool mousemove --window "$appw" 300 "$drag_y" mousedown 1 sleep 0.2 mousemove --window "$appw" 320 "$drag_y" sleep 0.3 mousemove --sync "$dest_x" "$dest_y" sleep 0.6 mouseup 1
  for i in $(seq 1 50); do [ -s "$PROMPTSLIP_RESULT" ] && break; sleep 0.1; done
  [ -s "$PROMPTSLIP_RESULT" ] || { cat "$PROMPTSLIP_LOG" "$PROMPTSLIP_RECEIVER_LOG" >&2; exit 1; }
  printf %s latest-text-for-drag-check > "$PROMPTSLIP_RESULT.expected"
  cmp "$PROMPTSLIP_RESULT.expected" "$PROMPTSLIP_RESULT"
  xdotool windowfocus --sync "$appw"
  xdotool mousemove --window "$appw" 300 220 click 1 key End type --clearmodifiers --delay 0 CLOSE-PENDING
  printf %s latest-text-for-drag-checkCLOSE-PENDING > "$PROMPTSLIP_RESULT.draft-expected"
  "$PROMPTSLIP_RECEIVER" --close "$appw"
  for i in $(seq 1 50); do kill -0 "$app" 2>/dev/null || break; sleep 0.1; done
  kill -0 "$app" 2>/dev/null && { echo "GUI did not exit after window close" >&2; exit 1; }
  wait "$app"
  cmp "$PROMPTSLIP_RESULT.draft-expected" "$XDG_DATA_HOME/promptslip/draft.txt"
' >"$TMP/smoke.log" 2>&1
status=$?
set -e
if [ "$status" -ne 0 ]; then cat "$TMP/smoke.log" >&2; exit "$status"; fi
echo 'PASS: GTK drag transferred the latest editor text by file URI; closing the window saved the draft.'
