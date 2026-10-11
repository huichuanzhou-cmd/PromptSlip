#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=${1:-"$ROOT/build"}
APP="$OUT/PromptSlip.app"
case ${PROMPTSLIP_ARCHS:-universal} in
  universal) ARCH_ARGS="-arch x86_64 -arch arm64" ;;
  x86_64|arm64) ARCH_ARGS="-arch $PROMPTSLIP_ARCHS" ;;
  *) echo "PROMPTSLIP_ARCHS must be universal, x86_64, or arm64." >&2; exit 2 ;;
esac
mkdir -p "$OUT"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>PromptSlip</string>
  <key>CFBundleIdentifier</key><string>local.promptslip.native</string>
  <key>CFBundleName</key><string>PromptSlip</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>0.2.0</string>
  <key>CFBundleShortVersionString</key><string>0.2.0</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
xcrun clang -fobjc-arc -Wall -Wextra -Werror=objc-method-access -mmacosx-version-min=11.0 $ARCH_ARGS -framework Cocoa "$ROOT/PromptSlip.m" -o "$APP/Contents/MacOS/PromptSlip"
CLI_LINK="$OUT/promptslip"
LINK_TARGET="PromptSlip.app/Contents/MacOS/PromptSlip"
if [ -L "$CLI_LINK" ]; then
  if [ "$(readlink "$CLI_LINK")" != "$LINK_TARGET" ]; then
    echo "Refusing to replace unrelated symlink: $CLI_LINK" >&2
    exit 1
  fi
elif [ -e "$CLI_LINK" ]; then
  echo "Refusing to replace existing path: $CLI_LINK" >&2
  exit 1
else
  ln -s "$LINK_TARGET" "$CLI_LINK"
fi
printf 'Built app: %s\nCLI: %s/promptslip\n' "$APP" "$OUT"
printf 'Launch GUI: open "%s"\n' "$APP"
printf 'CLI: "%s/promptslip" --stdin --output-dir "$HOME/Library/Application Support/PromptSlip/files"\n' "$OUT"
