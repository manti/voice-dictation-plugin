#!/usr/bin/env bash
# Record from the default microphone with VAD auto-stop.
# Prints the path to the resulting 16 kHz mono WAV on stdout.
# Status messages go to stderr so callers can capture stdout cleanly.

set -euo pipefail

if ! command -v sox >/dev/null 2>&1; then
  echo "error: 'sox' not found. Install with: brew install sox  (macOS)  |  apt-get install sox  (Debian/Ubuntu)" >&2
  exit 1
fi

MAX_SECONDS="${VOICE_DICTATE_MAX_SECONDS:-120}"
OUT="$(mktemp -t voice-dictate-XXXXXX).wav"

echo "🎤 Recording... speak now, pause to stop (max ${MAX_SECONDS}s)" >&2

# sox VAD: start recording on first sound, stop after 1.5s of silence.
#   silence 1 0.1 1%  -> require 0.1s of audio above 1% to begin
#           1 1.5 1%  -> stop after 1.5s of audio below 1%
#   trim 0 N          -> hard cap total length at N seconds
sox -q -d -c 1 -r 16000 -b 16 "$OUT" \
    silence 1 0.1 1% 1 1.5 1% \
    trim 0 "$MAX_SECONDS" \
  >/dev/null 2>&1 || {
    rc=$?
    echo "error: sox recording failed (exit $rc). Check mic permissions and that an input device is set." >&2
    exit "$rc"
  }

if [[ ! -s "$OUT" ]]; then
  echo "error: no audio captured." >&2
  exit 1
fi

echo "$OUT"
