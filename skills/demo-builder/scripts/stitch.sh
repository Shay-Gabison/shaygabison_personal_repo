#!/usr/bin/env bash
# stitch.sh — mux each section (video governs length, narration padded) + concat -> final MP4.
# usage: stitch.sh <out.mp4> <vid1>=<wav1> <vid2>=<wav2> ...   (wav optional: vid= for silent)
# Each input may be .webm/.mp4. Normalizes to 1440x900 30fps, stereo 48k.
#
# AUTO FLAT-HEAD TRIM (generic): deck cards (and some browser clips) start with a few flat
# pre-paint frames (white browser paint, or a dark data-url before content fades in). Those
# read as a "glitch" blank frame and the QA harness flags them. We auto-detect the first
# non-flat frame of EACH input and skip the flat head, then clone-pad the tail so the section
# keeps its exact length (narration stays in sync). Disable with TRIM_FLAT_HEAD=0.
set -e
OUT="$1"; shift
WORK="${WORK:-/tmp/demo_build}"; mkdir -p "$WORK/_sections"
LIST="$WORK/_sections/list.txt"; : > "$LIST"; i=0
TRIM_FLAT_HEAD="${TRIM_FLAT_HEAD:-1}"
FLAT_STD="${FLAT_STD:-7}"           # grayscale stddev below this = flat/near-blank (QA flags <6)
FLAT_SPREAD="${FLAT_SPREAD:-40}"    # fallback: luma (YMAX-YMIN) below this = flat frame
FLAT_MAXHEAD="${FLAT_MAXHEAD:-1.5}" # never chop more than this many seconds (safety)
PY="$(command -v python3 || true)"

first_nonflat() { # $1=file -> seconds of first frame whose content is non-flat (empty if none)
  # Preferred: sample frames at 10fps and use the SAME grayscale-stddev metric as check_demo.py,
  # so we trim exactly enough head that the QA flat-frame check (stddev<6) passes. The spread
  # detector alone fires on the first faint glyph while the frame is still mostly dark.
  if [ -n "$PY" ] && "$PY" -c "import PIL" >/dev/null 2>&1; then
    local td; td="$(mktemp -d)"
    ffmpeg -loglevel error -t "$FLAT_MAXHEAD" -i "$1" -vf "fps=10,scale=480:-1" -vsync 0 "$td/%03d.png" >/dev/null 2>&1 || true
    "$PY" - "$td" "$FLAT_STD" <<'PYEOF'
import sys,glob,os
from PIL import Image,ImageStat
td,thr=sys.argv[1],float(sys.argv[2])
for i,f in enumerate(sorted(glob.glob(os.path.join(td,'*.png')))):
    if ImageStat.Stat(Image.open(f).convert('L')).stddev[0] >= thr:
        print(round(i*0.1,3)); break
PYEOF
    rm -rf "$td"
    return
  fi
  # Fallback (no PIL): luma spread via signalstats + a small settle margin.
  local h; h="$(ffmpeg -loglevel error -t "$FLAT_MAXHEAD" -i "$1" \
    -vf "signalstats,metadata=print:file=-" -f null - 2>/dev/null | awk -v thr="$FLAT_SPREAD" '
      /pts_time:/{pt=$0; sub(/.*pts_time:/,"",pt); ymin=ymax=""}
      /YMIN=/{ymin=$0; sub(/.*YMIN=/,"",ymin)}
      /YMAX=/{ymax=$0; sub(/.*YMAX=/,"",ymax); if(ymin!=""&&ymax-ymin>=thr){print pt; exit}}')"
  [ -n "$h" ] && awk "BEGIN{printf \"%.3f\", $h+0.30}"
}

mux() { # $1 video $2 audio(maybe empty) $3 out
  local v="$1" a="$2" out="$3" head="" pad=""
  if [ "$TRIM_FLAT_HEAD" = "1" ]; then
    head="$(first_nonflat "$v")"
    if [ -n "$head" ] && awk "BEGIN{exit !($head>=0.12)}"; then
      pad=",tpad=stop_mode=clone:stop_duration=$head"
    else
      head=""
    fi
  fi
  local ss=(); [ -n "$head" ] && ss=(-ss "$head")
  if [ -n "$a" ]; then
    ffmpeg -loglevel error -y "${ss[@]}" -i "$v" -i "$a" \
      -filter_complex "[0:v]scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0x0b0e14,fps=30${pad},format=yuv420p,setsar=1[v];[1:a]aresample=48000,apad,pan=stereo|c0=c0|c1=c0[a]" \
      -map "[v]" -map "[a]" -c:v libx264 -crf 20 -preset medium -c:a aac -b:a 160k -ar 48000 -shortest "$out"
  else
    ffmpeg -loglevel error -y "${ss[@]}" -i "$v" -f lavfi -i anullsrc=cl=stereo:r=48000 \
      -vf "scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0x0b0e14,fps=30${pad},format=yuv420p,setsar=1" \
      -c:v libx264 -crf 20 -c:a aac -b:a 160k -ar 48000 -shortest "$out"
  fi
}
for pair in "$@"; do
  v="${pair%%=*}"; a="${pair#*=}"; [ "$a" = "$pair" ] && a=""
  s="$WORK/_sections/s$i.mp4"; mux "$v" "$a" "$s"; echo "file '$s'" >> "$LIST"; i=$((i+1))
done
ffmpeg -loglevel error -y -f concat -safe 0 -i "$LIST" -c copy "$OUT"
ffprobe -loglevel quiet -show_entries format=duration -of default=nw=1:nk=1 "$OUT"
echo "final -> $OUT"
