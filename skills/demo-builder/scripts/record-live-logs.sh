#!/usr/bin/env bash
# record-live-logs.sh — record a REAL terminal: `kubectl get pods` then live-stream a pod/job's
# logs through a readable pacer (fmt_pace.py) so lines scroll in continuously (live-run feel, not a
# static screenshot). Read-only. usage:
#   record-live-logs.sh <ctx> <ns> <pods-grep> <log-target> <out.mp4> [fontsize=22] [dwell=24]
#   <log-target> e.g. "job/contosovalidation-XXationation" or a pod name. --all-containers is added.
set -e
CTX="$1"; NS="$2"; GREP="$3"; TARGET="$4"; OUT="$5"; FS="${6:-22}"; DWELL="${7:-24}"; COLS="${8:-124}"; ROWS="${9:-34}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOCK=/tmp/demo_live.sock; CAST=/tmp/demo_live.cast
tmux -S $SOCK kill-server 2>/dev/null || true; rm -f "$CAST"
tmux -S $SOCK new-session -d -x "$COLS" -y "$ROWS" -s lv "bash --noprofile --norc"
# pin the window size so an attaching (recording) client can't shrink it and wrap log lines
tmux -S $SOCK set-option -g window-size manual 2>/dev/null || true
tmux -S $SOCK resize-window -t lv -x "$COLS" -y "$ROWS" 2>/dev/null || true
sleep 1
tmux -S $SOCK send-keys -t lv "export PS1='\$ '; clear" Enter; sleep 0.5
( asciinema rec --overwrite -q --window-size "${COLS}x${ROWS}" -c "tmux -S $SOCK attach -t lv" "$CAST" ) &
sleep 1.5
tmux -S $SOCK send-keys -t lv "kubectl --context $CTX -n $NS get pods | grep -E '$GREP' | head" Enter
sleep 4
tmux -S $SOCK send-keys -t lv "kubectl --context $CTX -n $NS logs $TARGET --all-containers=true | python3 $HERE/fmt_pace.py" Enter
sleep "$DWELL"
tmux -S $SOCK send-keys -t lv "C-c"; sleep 1
tmux -S $SOCK kill-server 2>/dev/null || true
agg --font-size $FS --fps-cap 30 --idle-time-limit 2 --last-frame-duration 1 "$CAST" /tmp/demo_live.gif
ffmpeg -loglevel error -y -i /tmp/demo_live.gif -vf "fps=30,scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0x0b0e14,format=yuv420p,setsar=1" -c:v libx264 -crf 20 -preset medium "$OUT"
echo "live-logs -> $OUT ($(ffprobe -loglevel quiet -show_entries format=duration -of default=nw=1:nk=1 "$OUT") s)"
