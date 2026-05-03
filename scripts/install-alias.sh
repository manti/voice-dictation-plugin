#!/usr/bin/env bash
# Add the plugin's `voice-dictate` CLI to your shell's PATH so you can run it
# from any terminal (Workflow A: clipboard handoff). Idempotent — safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PLUGIN_ROOT/bin"
MARKER="# voice-dictation-plugin"
LINE="export PATH=\"$BIN_DIR:\$PATH\"  $MARKER"

if [[ ! -x "$BIN_DIR/voice-dictate" ]]; then
  echo "error: $BIN_DIR/voice-dictate not found or not executable." >&2
  exit 1
fi

# Pick the right rc file for the user's shell.
case "${SHELL##*/}" in
  zsh)  RC="$HOME/.zshrc" ;;
  bash) RC="$HOME/.bashrc" ;;
  fish)
    RC="$HOME/.config/fish/config.fish"
    LINE="set -gx PATH $BIN_DIR \$PATH  $MARKER"
    ;;
  *)
    echo "error: unsupported shell: $SHELL. Add this line to your shell rc manually:" >&2
    echo "  $LINE" >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$RC")"
touch "$RC"

if grep -qF "$MARKER" "$RC"; then
  echo "voice-dictation-plugin: PATH entry already present in $RC"
else
  printf '\n%s\n' "$LINE" >> "$RC"
  echo "voice-dictation-plugin: added PATH entry to $RC"
fi

echo
echo "Open a new terminal (or run: source \"$RC\") and try:"
echo "  voice-dictate --check"
