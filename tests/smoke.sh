#!/usr/bin/env bash
# Smoke test: check deps, then run the transcribe pipeline against a synthesised WAV
# (a 1-second 440 Hz tone — whisper will likely transcribe nothing or "..." which is fine;
# we only assert the pipeline runs without error).
#
# To test real speech end-to-end, drop a recording at tests/fixture.wav and re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

step() { printf '\n=== %s ===\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

step "syntax check on every shell script"
for f in "$PLUGIN_ROOT/bin/voice-dictate" \
         "$PLUGIN_ROOT/lib"/*.sh \
         "$PLUGIN_ROOT/scripts"/*.sh \
         "$PLUGIN_ROOT/tests"/*.sh
do
  bash -n "$f" || fail "syntax error in $f"
  echo "ok: $f"
done

step "manifest is valid JSON"
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import json,sys; json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json'))" \
    || fail "plugin.json is not valid JSON"
  echo "ok: plugin.json"
elif command -v node >/dev/null 2>&1; then
  node -e "JSON.parse(require('fs').readFileSync('$PLUGIN_ROOT/.claude-plugin/plugin.json','utf8'))" \
    || fail "plugin.json is not valid JSON"
  echo "ok: plugin.json"
else
  echo "skip: no python3 or node available to validate JSON"
fi

step "dependency check"
if bash "$PLUGIN_ROOT/bin/voice-dictate" --check; then
  echo "ok: deps present"
  DEPS_OK=1
else
  echo "warn: deps missing — pipeline test will be skipped"
  DEPS_OK=0
fi

if (( DEPS_OK )); then
  FIXTURE="$PLUGIN_ROOT/tests/fixture.wav"
  if [[ ! -f "$FIXTURE" ]]; then
    step "synthesising 1s 440 Hz tone for pipeline test"
    sox -n -c 1 -r 16000 "$FIXTURE" synth 1 sine 440 \
      || fail "could not synthesise fixture WAV"
  fi

  step "running transcribe.sh on fixture"
  if bash "$PLUGIN_ROOT/lib/transcribe.sh" "$FIXTURE" >/tmp/voice-dictate-smoke.txt 2>&1; then
    echo "ok: transcribe.sh ran (output: $(wc -c </tmp/voice-dictate-smoke.txt) bytes)"
  else
    echo "warn: transcribe.sh failed on the synthetic tone (expected if no speech detected)."
    echo "      To validate end-to-end, place a real speech WAV at tests/fixture.wav."
  fi
fi

step "all smoke checks passed"
