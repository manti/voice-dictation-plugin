#!/usr/bin/env bash
# Transcribe a WAV file with whisper.cpp's whisper-cli.
# Usage: transcribe.sh <wav-path>
# Prints the transcript to stdout. Status messages go to stderr.

set -euo pipefail

WAV="${1:?usage: transcribe.sh <wav-path>}"

if [[ ! -s "$WAV" ]]; then
  echo "error: WAV file is empty or missing: $WAV" >&2
  exit 1
fi

# whisper.cpp ships its CLI as either `whisper-cli` (newer) or `main` (older).
WHISPER_BIN=""
for candidate in whisper-cli whisper main; do
  if command -v "$candidate" >/dev/null 2>&1; then
    WHISPER_BIN="$candidate"
    break
  fi
done

if [[ -z "$WHISPER_BIN" ]]; then
  cat >&2 <<'EOF'
error: whisper.cpp not found. Install one of:
  macOS:        brew install whisper-cpp
  from source:  https://github.com/ggerganov/whisper.cpp
EOF
  exit 1
fi

LANG="${VOICE_DICTATE_LANGUAGE:-en}"

# Resolve model path: explicit env var wins; otherwise probe common locations.
MODEL="${VOICE_DICTATE_MODEL:-}"
if [[ -z "$MODEL" ]]; then
  for candidate in \
    "$HOME/.cache/whisper.cpp/ggml-base.en.bin" \
    "$HOME/.cache/whisper.cpp/ggml-base.bin" \
    "/opt/homebrew/share/whisper-cpp/ggml-base.en.bin" \
    "/usr/local/share/whisper-cpp/ggml-base.en.bin"
  do
    if [[ -f "$candidate" ]]; then
      MODEL="$candidate"
      break
    fi
  done
fi

if [[ -z "$MODEL" || ! -f "$MODEL" ]]; then
  cat >&2 <<EOF
error: whisper.cpp model not found.
Set VOICE_DICTATE_MODEL to your .bin model path, or download one:
  mkdir -p ~/.cache/whisper.cpp
  curl -L -o ~/.cache/whisper.cpp/ggml-base.en.bin \\
    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
EOF
  exit 1
fi

BASE="${WAV%.wav}"
TXT="${BASE}.txt"

# -nt: no timestamps. -otxt: write plain text. -of: output file base (no extension).
"$WHISPER_BIN" \
  -m "$MODEL" \
  -l "$LANG" \
  -f "$WAV" \
  -nt \
  -otxt \
  -of "$BASE" \
  >/dev/null 2>&1 || {
    rc=$?
    echo "error: whisper-cli failed (exit $rc). Re-run with VOICE_DICTATE_DEBUG=1 to see logs." >&2
    if [[ "${VOICE_DICTATE_DEBUG:-0}" == "1" ]]; then
      "$WHISPER_BIN" -m "$MODEL" -l "$LANG" -f "$WAV" -nt -otxt -of "$BASE" >&2 || true
    fi
    exit "$rc"
  }

if [[ ! -s "$TXT" ]]; then
  echo "error: transcription produced no output." >&2
  exit 1
fi

# Trim leading/trailing whitespace, collapse internal newlines into spaces.
tr '\n' ' ' < "$TXT" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g'
echo
