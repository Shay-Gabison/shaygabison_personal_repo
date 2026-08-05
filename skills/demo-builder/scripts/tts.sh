#!/usr/bin/env bash
# tts.sh — synthesize narration. Default engine: Kokoro (natural, offline). Fallback: Piper.
# usage: tts.sh <txtfile> <out.wav> [voice] [engine]
#   Kokoro voices: am_michael (default, warm US male), am_adam, af_heart, bm_george (use lang 'b' for bm_*)
#   engine: kokoro (default) | piper
# Spell tricky terms phonetically in the script (E V two, k nine s, m d a).
set -e
WORK="${WORK:-$HOME/demo_build}"; TXT="$1"; OUT="$2"; V="${3:-am_michael}"; ENGINE="${4:-kokoro}"
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$ENGINE" = "kokoro" ]; then
  "$WORK/.ttsenv/bin/python" "$SCRIPTDIR/kokoro_synth.py" "$V" "$TXT" "$OUT"
else
  cat "$TXT" | "$WORK/.ttsenv/bin/piper" -m "$WORK/voices/$V.onnx" --sentence-silence 0.32 -f "$OUT"
fi
ffprobe -loglevel quiet -show_entries format=duration -of default=nw=1:nk=1 "$OUT"
