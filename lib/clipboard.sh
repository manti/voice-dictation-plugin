#!/usr/bin/env bash
# Copy stdin to the system clipboard. Returns nonzero if no clipboard tool is available.
# Status messages go to stderr.

set -euo pipefail

if command -v pbcopy >/dev/null 2>&1; then
  pbcopy
elif command -v wl-copy >/dev/null 2>&1; then
  wl-copy
elif command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
  xsel --clipboard --input
elif command -v clip.exe >/dev/null 2>&1; then
  clip.exe
else
  cat >&2 <<'EOF'
warning: no clipboard tool found. Install one:
  macOS:        pbcopy is built-in
  Wayland:      apt-get install wl-clipboard
  X11:          apt-get install xclip
  WSL:          clip.exe is built-in
EOF
  cat >/dev/null
  exit 1
fi
