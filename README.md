# voice-dictation (Claude Code plugin)

Local-only voice dictation for Claude Code users authenticated with an **Anthropic API key, Amazon Bedrock, Google Vertex AI, or Microsoft Foundry** — the auth modes that the [native `/voice` feature](https://code.claude.com/docs/en/voice-dictation) refuses to enable.

Records from your microphone with `sox`, transcribes locally with `whisper.cpp`, and never sends audio off-device.

## What this plugin does and does not do

| | |
|---|---|
| ✅ Works for API-key / Bedrock / Vertex / Foundry users | ❌ Does **not** unlock Anthropic's STT (gated server-side) |
| ✅ Fully offline transcription via whisper.cpp | ❌ Does **not** restore the native "hold Space, see live waveform" UX |
| ✅ Auto-stops on silence | ❌ Does **not** insert text into the prompt input live (plugin APIs can't reach the TUI) |

The closest a plugin can get to "insert without submit" is the **clipboard handoff** workflow below.

## Quickstart (3 commands)

Inside Claude Code:

```
/plugin marketplace add manti/voice-dictation-plugin
/plugin install voice-dictation@voice-dictation-plugin
/voice-dictation:install
```

`/voice-dictation:install` is a one-shot bootstrap that installs `sox`, `whisper-cpp`, downloads `ggml-base.en.bin` (~141 MB), and adds `voice-dictate` to your shell PATH. Idempotent — safe to re-run.

Then dictate:

```
/voice-dictation:speak                 # auto-submit transcript as your prompt
voice-dictate                          # in another terminal: transcript → clipboard
```

> macOS users: grant your terminal microphone access at System Settings → Privacy & Security → Microphone the first time you record.

## What the bootstrap does on each platform

| | sox | whisper.cpp | model | shell PATH |
|---|---|---|---|---|
| **macOS** (Homebrew required) | `brew install sox` | `brew install whisper-cpp` | `curl` to `~/.cache/whisper.cpp/` | appends to `~/.zshrc` / `~/.bashrc` |
| **Debian/Ubuntu** | `sudo apt-get install -y sox` | prints build-from-source instructions | `curl` to `~/.cache/whisper.cpp/` | appends to shell rc |
| **Other Linux / Windows** | manual install required | manual install required | `curl` works | manual |

If you'd rather install manually:

```bash
brew install sox whisper-cpp
mkdir -p ~/.cache/whisper.cpp
curl -L -o ~/.cache/whisper.cpp/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
```

## Alternative install paths

### Via `--plugin-dir` (for local development)

```bash
git clone https://github.com/manti/voice-dictation-plugin ~/voice-dictation-plugin
claude --plugin-dir ~/voice-dictation-plugin
bash ~/voice-dictation-plugin/scripts/bootstrap.sh
```

## Workflow A — clipboard handoff (insert without submit)

Run `voice-dictate` in any terminal, dictate, then paste into Claude Code and edit before sending:

```
$ voice-dictate
🎤 Recording... speak now, pause to stop (max 120s)
🧠 Transcribing locally...
refactor the auth middleware to use the token helper
✓ Copied to clipboard.

# switch to Claude Code, Cmd+V, edit if needed, hit Enter
```

This is the only plugin-side path that lets you review and edit the transcript before submission.

## Workflow B — slash command (auto-submits)

Inside Claude Code, run `/voice-dictation:speak`. The transcript becomes your next prompt and Claude processes it immediately:

```
> /voice-dictation:speak
🎤 Recording... speak now, pause to stop (max 120s)
🧠 Transcribing locally...
> refactor the auth middleware to use the token helper
[Claude responds]
```

## Configuration

All three are environment variables — no settings file needed.

| Variable | Default | Purpose |
|---|---|---|
| `VOICE_DICTATE_MODEL` | first match in `~/.cache/whisper.cpp/ggml-base.en.bin`, then Homebrew share dirs | Path to a `ggml-*.bin` whisper model |
| `VOICE_DICTATE_LANGUAGE` | `en` | Whisper language code (`en`, `ja`, `de`, etc.) |
| `VOICE_DICTATE_MAX_SECONDS` | `120` | Hard cap on a single recording |
| `VOICE_DICTATE_DEBUG` | `0` | Set to `1` to surface whisper-cli stderr on failure |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `error: 'sox' not found` | `brew install sox` (macOS) or `apt-get install sox` |
| `error: whisper.cpp not found` | `brew install whisper-cpp` or build from source |
| `error: whisper.cpp model not found` | Download a `.bin` model (see Prerequisites) or set `VOICE_DICTATE_MODEL` |
| `error: no audio captured` | Grant terminal mic permission and confirm the correct input device |
| Transcript is in the wrong language | Set `VOICE_DICTATE_LANGUAGE=ja` (etc.) and use a multilingual model like `ggml-base.bin` |
| Recording never stops | The VAD threshold is 1% — if your room is loud, run `voice-dictate` in a quieter spot or shorten `VOICE_DICTATE_MAX_SECONDS` |
| `voice-dictate: command not found` after install-alias | Open a new terminal, or `source ~/.zshrc` |

## Layout

```
voice-dictation-plugin/
├── .claude-plugin/
│   ├── plugin.json              plugin manifest
│   └── marketplace.json         marketplace catalog (this repo is its own marketplace)
├── bin/voice-dictate            CLI used by both workflows
├── commands/
│   ├── install.md               /voice-dictation:install — one-shot bootstrap
│   └── speak.md                 /voice-dictation:speak — record + submit transcript
├── lib/
│   ├── record.sh                sox VAD recorder
│   ├── transcribe.sh            whisper.cpp wrapper
│   └── clipboard.sh             cross-platform copy
├── scripts/
│   ├── bootstrap.sh             installs deps + model + PATH (idempotent)
│   └── install-alias.sh         adds bin/ to user shell PATH
└── tests/smoke.sh               syntax + manifest + pipeline checks
```

## Maintainer: how to release

The repo is its own plugin marketplace. To ship the first version:

```bash
cd /Users/apple/Desktop/personal-project/voice-dictation-plugin
git init -b main
git add .
git commit -m "voice-dictation-plugin v0.1.0"
gh repo create voice-dictation-plugin --public --source . --push
# or: git remote add origin git@github.com:<you>/voice-dictation-plugin.git && git push -u origin main
```

To validate the marketplace before pushing:

```bash
claude plugin validate /Users/apple/Desktop/personal-project/voice-dictation-plugin
```

Subsequent releases: just commit and push. Because `plugin.json` doesn't pin a `version`, every commit SHA is a new version and users on `/plugin marketplace update` will pick it up. If you'd rather pin (so users only get updates on tagged releases), bump `version` in `.claude-plugin/plugin.json` per release.

## License

MIT
