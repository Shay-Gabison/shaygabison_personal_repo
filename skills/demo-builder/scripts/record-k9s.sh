#!/usr/bin/env bash
# record-k9s.sh — record a real k9s session: pods list -> drill into pod logs -> reconcile stream.
# usage: record-k9s.sh <kube-context> <namespace> <pod-filter> <out.mp4> [fontsize=17]
# Requires VPN/cluster access. Read-only. agg DOES render the k9s log sub-view.
set -e
CTX="$1"; NS="$2"; FILTER="$3"; OUT="$4"; FS="${5:-22}"
SOCK=/tmp/demo_k9.sock; CAST=/tmp/demo_k9.cast
tmux -S $SOCK kill-server 2>/dev/null || true; rm -f "$CAST"
# Fewer cols/rows => each character is larger in the final 1440x900 frame.
tmux -S $SOCK new-session -d -x 150 -y 40 -s k9 "k9s --context $CTX -n $NS --command pods --readonly"
sleep 7
( asciinema rec --overwrite -q -c "tmux -S $SOCK attach -t k9" "$CAST" ) &
sleep 1.5
tmux -S $SOCK send-keys -t k9 "/$FILTER" Enter; sleep 5       # filter pods
tmux -S $SOCK send-keys -t k9 Enter; sleep 2                  # select first pod
tmux -S $SOCK send-keys -t k9 "l"; sleep 6                    # logs view
tmux -S $SOCK send-keys -t k9 "/reconcile" Enter; sleep 13    # filter to reconcile (dwell on live stream)
tmux -S $SOCK send-keys -t k9 Escape; sleep 3
tmux -S $SOCK send-keys -t k9 "t"; sleep 12                   # timestamps on, dwell
tmux -S $SOCK kill-server 2>/dev/null || true
# render (idle-time-limit 10 keeps real-time pacing); mp4, trimmed to drop "[server exited]" tail
agg --font-size $FS --fps-cap 15 --idle-time-limit 10 --last-frame-duration 1 "$CAST" /tmp/demo_k9.gif
ffmpeg -loglevel error -y -i /tmp/demo_k9.gif -vf "fps=30,scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0x0b0e14,format=yuv420p,setsar=1" -c:v libx264 -crf 20 -preset medium /tmp/demo_k9_full.mp4
D=$(ffprobe -loglevel quiet -show_entries format=duration -of default=nw=1:nk=1 /tmp/demo_k9_full.mp4)
ffmpeg -loglevel error -y -i /tmp/demo_k9_full.mp4 -t $(echo "$D-1.3"|bc) -c:v libx264 -crf 20 -preset medium "$OUT"
echo "k9s clip -> $OUT ($D s)"
