#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BIN_DIR=${XDG_BIN_HOME:-"$HOME/.local/bin"}
APP_DIR=${XDG_DATA_HOME:-"$HOME/.local/share"}/applications
mkdir -p "$BIN_DIR" "$APP_DIR"
sh "$HERE/build.sh" "$BIN_DIR/promptslip"
cat > "$APP_DIR/promptslip.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=PromptSlip
Comment=Drag text as a Markdown file attachment
Exec="$BIN_DIR/promptslip"
Terminal=false
Categories=Utility;TextEditor;
StartupNotify=true
EOF
chmod 755 "$BIN_DIR/promptslip"
printf 'Installed for this user: %s\n' "$BIN_DIR/promptslip"
