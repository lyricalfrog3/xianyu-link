#!/usr/bin/env bash
# install.sh — put xianyu-link on your PATH.
set -euo pipefail

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/xianyu-link"

[ -f "$SRC" ] || { echo "xianyu-link not found next to install.sh" >&2; exit 1; }
command -v adb >/dev/null || echo "!! adb not found — install Android platform-tools first" >&2

mkdir -p "$BIN_DIR"
cp "$SRC" "$BIN_DIR/xianyu-link"
chmod +x "$BIN_DIR/xianyu-link"

echo "installed: $BIN_DIR/xianyu-link"

case ":$PATH:" in
    *":$BIN_DIR:"*) echo "on PATH already — run: xianyu-link --doctor" ;;
    *)
        echo
        echo "Add this to your shell profile to use it as 'xianyu-link':"
        echo "    export PATH=\"$BIN_DIR:\$PATH\""
        ;;
esac
