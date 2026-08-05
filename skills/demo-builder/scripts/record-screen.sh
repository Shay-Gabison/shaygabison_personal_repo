#!/usr/bin/env bash
# record-screen.sh — record ANY native app / window / region on screen. Use this for tools that are
# NOT a browser or a terminal: desktop metrics viewers, native portals, an IDE app (VS Code desktop),
# Geneva desktop, Excel, Power BI desktop, a paused video, a design tool — anything visible on screen.
# macOS avfoundation screen capture.
#
# REQUIRES: System Settings > Privacy & Security > Screen Recording enabled for your terminal app
#           (Terminal / iTerm / the process running this). Without it the capture is a black frame.
#
# usage: record-screen.sh <out.mp4> <seconds> [crop] [display=auto] [fps=30]
#   crop   = "full" (default) or "WxH+X+Y" in SCREEN pixels to record just a window/region.
#   display= "auto" picks the first "Capture screen N" avfoundation device, or pass the index.
set -e
OUT="$1"; SECS="${2:-15}"; CROP="${3:-full}"; DISP="${4:-auto}"; FPS="${5:-30}"
[ -n "$OUT" ] || { echo "usage: record-screen.sh <out.mp4> <seconds> [crop] [display] [fps]" >&2; exit 1; }

if [ "$DISP" = "auto" ]; then
  DISP=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | awk -F'[][]' '/Capture screen/{print $4; exit}')
fi
[ -n "$DISP" ] || { echo "no 'Capture screen' avfoundation device found (grant Screen Recording permission)" >&2; exit 1; }

RAW=/tmp/demo_screen_raw.mkv
# capture (video only, no audio); ultrafast keeps the live grab cheap, we re-encode below.
ffmpeg -loglevel error -y -f avfoundation -capture_cursor 1 -framerate "$FPS" -i "$DISP" \
  -t "$SECS" -c:v libx264 -preset ultrafast -crf 18 "$RAW" \
  || { echo "screen capture failed — is Screen Recording permission granted for this terminal?" >&2; exit 1; }

if [ "$CROP" = "full" ]; then
  VF="scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0x0b0e14"
else
  W=${CROP%%x*}; rest=${CROP#*x}; H=${rest%%+*}; rest=${rest#*+}; X=${rest%%+*}; Y=${rest##*+}
  VF="crop=${W}:${H}:${X}:${Y},scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0x0b0e14"
fi
ffmpeg -loglevel error -y -i "$RAW" -vf "$VF,fps=30,format=yuv420p,setsar=1" -c:v libx264 -crf 20 -preset medium "$OUT"
rm -f "$RAW"
echo "screen clip -> $OUT (${SECS}s, device $DISP, crop $CROP)"
