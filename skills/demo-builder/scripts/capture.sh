#!/usr/bin/env bash
# capture.sh — ONE entry point to record ANY tool an engineer uses, into a demo-ready 1440x900 clip.
# Point it at whatever the engineer provides or asks to record — logs, metrics, terminal, code, a web
# portal, or a native desktop app — and it routes to the right recorder. This is the universal
# "record my screen for tool X" front door for the demo pipeline.
#
# usage: capture.sh <kind> <out> [args...]
#
# KINDS (aliases in parentheses):
#   url (portal|metrics|dashboard|web|grafana|kusto|geneva|ev2|icm|ado|wiki)
#         <out.webm> <url> [seconds=30] [scrollPx=0] [zoom=1.0]
#         Any authenticated WEB tool: ADO pipelines/PRs, EV2 portal rollouts, Geneva/Jarvis
#         dashboards & metric charts, IcM incidents, Kusto/ADX web queries, Azure Portal, Service
#         Tree, Grafana, wikis. Drives your real Chrome (SSO), crisp full-page, live scroll.
#
#   cmd (terminal|cli|shell)
#         <out.mp4> <script.sh> [fontsize=18] [idle=2]
#         Any read-only CLI session: az, kubectl, helm, gh, git, configgen, or a custom tool.
#
#   code (file|editor)
#         <out.mp4> <file> [fontsize=16] [pace=0.10]
#         Any source file, syntax-highlighted, scrolled like a human reading it.
#
#   logs (livelogs|podlogs)
#         <out.mp4> <ctx> <ns> <pods-grep> <log-target> [fontsize=22] [dwell=24]
#         Real kubectl logs streamed through a pacer (live-run feel, not a screenshot).
#
#   k8s (k9s|pods)
#         <out.mp4> <ctx> <ns> <pod-filter> [fontsize=22]
#         Live k9s: pods list -> drill into a pod's logs.
#
#   screen (app|window|desktop|native|gui)
#         <out.mp4> <seconds> [crop=full|WxH+X+Y] [display=auto] [fps=30]
#         ANY native GUI/app on screen that is not a browser or terminal (desktop metrics viewers,
#         native portals, IDE app, Excel/Power BI, a video). Needs macOS Screen Recording permission.
#
# For anything not covered, the closest primitive is: web -> url, text/CLI -> cmd, GUI -> screen.
set -e
KIND="$1"; shift || true
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$KIND" ] || { grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

case "$KIND" in
  url|portal|metrics|dashboard|web|grafana|kusto|geneva|ev2|icm|ado|wiki)
    OUT="$1"; URL="$2"; SECS="${3:-30}"; SCROLL="${4:-0}"; ZOOM="${5:-1.0}"
    node "$HERE/record-browser.js" "$URL" "$OUT" "$SECS" "$SCROLL" "$ZOOM" ;;
  cmd|terminal|cli|shell)
    bash "$HERE/record-term.sh" "$@" ;;
  code|file|editor)
    bash "$HERE/record-code.sh" "$@" ;;
  logs|livelogs|podlogs)
    bash "$HERE/record-live-logs.sh" "$@" ;;
  k8s|k9s|pods)
    bash "$HERE/record-k9s.sh" "$@" ;;
  screen|app|window|desktop|native|gui)
    bash "$HERE/record-screen.sh" "$@" ;;
  *)
    echo "unknown kind: $KIND" >&2
    echo "kinds: url | cmd | code | logs | k8s | screen  (run with no args for full help)" >&2
    exit 2 ;;
esac
