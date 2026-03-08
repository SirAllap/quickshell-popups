#!/usr/bin/env bash
# Install quickshell-popups toggle scripts by symlinking them to ~/.local/bin/
# Run once after cloning: bash ~/.config/quickshell/bin/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.local/bin"

mkdir -p "$TARGET_DIR"

for script in "$SCRIPT_DIR"/toggle-*-popup; do
    name=$(basename "$script")
    chmod +x "$script"
    ln -sf "$script" "$TARGET_DIR/$name"
    echo "  linked $name"
done

echo ""
echo "Done. Make sure $TARGET_DIR is in your PATH."
echo "  (add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to ~/.bashrc or ~/.zshrc if needed)"
