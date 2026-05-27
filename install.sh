#!/usr/bin/env bash
# Install cca by symlinking the script into a directory on $PATH.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/cca"
DEST_DIR="${CCA_INSTALL_DIR:-$HOME/.local/bin}"
DEST="$DEST_DIR/cca"

[ -x "$SRC" ] || chmod +x "$SRC"

mkdir -p "$DEST_DIR"

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  rm "$DEST"
fi
ln -s "$SRC" "$DEST"

cat <<EOF
Installed: $DEST -> $SRC

Make sure $DEST_DIR is on your PATH. For zsh:
  echo 'export PATH="$DEST_DIR:\$PATH"' >> ~/.zshrc

Quick start:
  cca help
  cca ls
  cca add personal
  cca login personal
  eval "\$(cca switch personal)"
EOF
