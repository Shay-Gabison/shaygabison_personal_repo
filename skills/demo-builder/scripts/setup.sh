#!/usr/bin/env bash
# demo-builder setup: install/verify all tooling. Idempotent.
# NOTE: default WORK is under $HOME (NOT /tmp) because /tmp can be wiped mid-session by macOS cleanup.
set -e
# macOS only — the toolchain (brew, mac-chrome capture, Kokoro/Piper) does not run on Windows/Linux.
if [ "$(uname -s)" != "Darwin" ]; then
  echo "⚠️  Demo Builder works only on macOS. This skill relies on a macOS-only toolchain" >&2
  echo "    (Homebrew, mac-chrome capture, Kokoro/Piper TTS) and cannot run here. Use a Mac." >&2
  exit 1
fi
WORK="${1:-$HOME/demo_build}"
mkdir -p "$WORK"; cd "$WORK"
echo "== brew tools =="
for t in ffmpeg asciinema agg k9s tmux jq espeak-ng bat; do
  command -v "$t" >/dev/null 2>&1 && echo "  ok: $t" || { echo "  installing $t"; brew install "$t" >/dev/null 2>&1 || echo "  MISSING: $t -> brew install $t"; }
done
echo "== node playwright + chrome =="
[ -f package.json ] || npm init -y >/dev/null 2>&1
[ -d node_modules/playwright ] || npm i playwright >/dev/null 2>&1
node -e "require('playwright')" 2>/dev/null && echo "  ok: playwright (uses channel:'chrome')" || echo "  install: npm i playwright"
echo "== Kokoro TTS (natural, local, offline) — preferred =="
[ -d .ttsenv ] || python3 -m venv .ttsenv
.ttsenv/bin/pip install -q --upgrade pip >/dev/null 2>&1
.ttsenv/bin/python -c "import kokoro" 2>/dev/null || .ttsenv/bin/pip install -q kokoro soundfile >/dev/null 2>&1
.ttsenv/bin/python -c "from kokoro import KPipeline" 2>/dev/null && echo "  ok: kokoro (voices: am_michael, am_adam, af_heart, bm_george)" || echo "  kokoro install failed"
echo "== Piper TTS (fallback) =="
.ttsenv/bin/python -c "import piper" 2>/dev/null || .ttsenv/bin/pip install -q piper-tts >/dev/null 2>&1 || true
mkdir -p voices
echo "WORK=$WORK ready"
