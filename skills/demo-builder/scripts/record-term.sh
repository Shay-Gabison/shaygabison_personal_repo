#!/usr/bin/env bash
# record-term.sh — record a real terminal script (read-only commands) and render to mp4.
# usage: record-term.sh <segment.sh> <out.mp4> [fontsize=18] [idle=2]
set -e
SEG="$1"; OUT="$2"; FS="${3:-18}"; IDLE="${4:-2}"; CAST=/tmp/demo_term.cast
asciinema rec --overwrite --window-size 200x50 -q -c "bash $SEG" "$CAST"
agg --font-size $FS --fps-cap 12 --idle-time-limit $IDLE "$CAST" /tmp/demo_term.gif
ffmpeg -loglevel error -y -i /tmp/demo_term.gif -vf "fps=30,scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0x0b0e14,format=yuv420p,setsar=1" -c:v libx264 -crf 20 -preset medium "$OUT"
echo "term clip -> $OUT"
