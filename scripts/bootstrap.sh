#!/usr/bin/env bash
# bootstrap.sh — install everything voice-dictation needs in one shot.
#   - sox (audio capture)
#   - whisper-cpp (transcription)
#   - ggml-base.en.bin (whisper model, ~141 MB)
#   - shell PATH entry for the voice-dictate CLI
#
# Idempotent: re-running skips anything that's already in place.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

step() { printf '\n→ %s\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }
die()  { printf '  ✗ %s\n' "$*" >&2; exit 1; }

OS="$(uname -s)"

# ---------------------------------------------------------------------------
# 1. system packages: sox + whisper.cpp
# ---------------------------------------------------------------------------
step "checking system packages"

NEED_SOX=0; NEED_WHISPER=0
command -v sox >/dev/null 2>&1 || NEED_SOX=1
command -v whisper-cli >/dev/null 2>&1 || \
  command -v whisper     >/dev/null 2>&1 || \
  command -v main        >/dev/null 2>&1 || \
  NEED_WHISPER=1

if (( NEED_SOX == 0 )); then ok "sox already installed"; fi
if (( NEED_WHISPER == 0 )); then ok "whisper.cpp already installed"; fi

if (( NEED_SOX || NEED_WHISPER )); then
  case "$OS" in
    Darwin)
      command -v brew >/dev/null 2>&1 \
        || die "Homebrew is required. Install it from https://brew.sh and re-run."
      pkgs=()
      (( NEED_SOX )) && pkgs+=("sox")
      (( NEED_WHISPER )) && pkgs+=("whisper-cpp")
      step "running: brew install ${pkgs[*]}"
      brew install "${pkgs[@]}"
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        if (( NEED_SOX )); then
          step "running: sudo apt-get install -y sox"
          sudo apt-get install -y sox || die "apt-get install sox failed"
        fi
        if (( NEED_WHISPER )); then
          warn "whisper.cpp has no apt package — build from source:"
          warn "  git clone https://github.com/ggerganov/whisper.cpp ~/whisper.cpp"
          warn "  cd ~/whisper.cpp && cmake -B build && cmake --build build -j"
          warn "  then add ~/whisper.cpp/build/bin to your PATH"
          die "install whisper.cpp manually and re-run bootstrap"
        fi
      else
        die "unsupported Linux distribution (no apt-get). Install sox and whisper.cpp manually."
      fi
      ;;
    *)
      die "unsupported OS: $OS"
      ;;
  esac
  ok "system packages installed"
fi

# ---------------------------------------------------------------------------
# 2. whisper model
# ---------------------------------------------------------------------------
step "checking whisper model"

MODEL_DIR="${VOICE_DICTATE_MODEL_DIR:-$HOME/.cache/whisper.cpp}"
MODEL_NAME="${VOICE_DICTATE_MODEL_NAME:-ggml-base.en.bin}"
MODEL_PATH="$MODEL_DIR/$MODEL_NAME"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_NAME"

if [[ -f "$MODEL_PATH" && -s "$MODEL_PATH" ]]; then
  ok "model present at $MODEL_PATH ($(du -h "$MODEL_PATH" | cut -f1))"
else
  step "downloading $MODEL_NAME (~141 MB)"
  mkdir -p "$MODEL_DIR"
  if curl -fL --progress-bar -o "$MODEL_PATH.partial" "$MODEL_URL"; then
    mv "$MODEL_PATH.partial" "$MODEL_PATH"
    ok "model saved to $MODEL_PATH"
  else
    rm -f "$MODEL_PATH.partial"
    die "model download failed from $MODEL_URL"
  fi
fi

# ---------------------------------------------------------------------------
# 3. shell PATH entry for voice-dictate
# ---------------------------------------------------------------------------
step "ensuring voice-dictate is on your shell PATH"
bash "$SCRIPT_DIR/install-alias.sh"

# ---------------------------------------------------------------------------
# 4. final verification
# ---------------------------------------------------------------------------
step "verifying"
if bash "$PLUGIN_ROOT/bin/voice-dictate" --check >/dev/null 2>&1; then
  ok "all dependencies present"
else
  die "verification failed — run: $PLUGIN_ROOT/bin/voice-dictate --check"
fi

cat <<EOF

✓ voice-dictation is fully set up.

Next:
  • Workflow A (clipboard handoff): open a new terminal and run  voice-dictate
  • Workflow B (slash command):     /voice-dictation:speak
EOF
