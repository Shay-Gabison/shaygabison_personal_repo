# Demo Builder — workflow & cheatsheet

End-to-end build order. WORK dir default `/tmp/demo_build`. Final = 1440×900 30fps MP4.

## 0. Interview (ask_user) → 1. setup.sh → 2. gather real data → 3. cards → 4. real footage → 5. narrate → 6. stitch → 7. deliver+cleanup

## Sections, typical
Title card → architecture/how-it-works card (optional, 3-node flow) → real ADO/EV2 → real k9s pods+logs
→ handover/checklist → end card. Aim sum(section secs) ≈ requested length. Narration governs feel;
video stretched/cut to ~match.

## Cards
- `node scripts/render-cards.js $PWD/deck/deck.html out title:21,arch:30,end:17`
- Slides settle in ~4.5s; allow d-classes to finish. Webm output; stitch handles scaling.
- Render each card at ≈narration+0.4s. The pre-paint flat head is removed automatically at stitch
  time (see "Flat-frame auto-trim"), so DON'T hand-trim card heads — just feed the raw webm to stitch.
- **Architecture card** (`#arch`): generic 3-node `source → component → effects` flow + an invariant
  callout (what is NOT changed / dry-run is safe). Edit the placeholder text in deck.template.html.
  `.node.hot` highlights the middle node; `.nodeTag .o/.grn` recolor tags; `.mono` code spans,
  `.chip` red badge, `.num` numbered writes. Use it whenever the user asks to "understand the architecture".

## Universal capture — capture.sh (record ANY tool)
- ONE entry point: `bash scripts/capture.sh <kind> <out> [args…]`. Routes any tool to the right recorder
  and outputs a 1440×900 clip for stitch. Run with no args for full per-kind help.
- kinds: `url` (any web tool/portal/metrics/dashboard) · `cmd` (terminal/CLI) · `code` (source file,
  syntax-highlighted) · `logs` (streamed pod logs) · `k8s` (k9s) · `screen` (any native GUI/app/window).
- Never tell the user a tool is unsupported. Map it: web→`url`, CLI/text→`cmd`, source→`code`, any other
  on-screen GUI→`screen`.
- Examples:
  - `bash scripts/capture.sh url geneva.webm "https://jarvis-west.dc.ad.msft.net/dashboard/..." 30 1400`
  - `bash scripts/capture.sh cmd az.mp4 seg_az.sh 18 2`
  - `bash scripts/capture.sh code operator.mp4 src/controller.go 16 0.08`
  - `bash scripts/capture.sh screen app.mp4 15 full auto 30`

## Native screen / app capture — record-screen.sh
- For GUI tools that are NOT a browser or terminal (desktop metrics viewers, native portals, an IDE app,
  Excel/Power BI, a video): `bash scripts/record-screen.sh <out.mp4> <seconds> [crop] [display=auto] [fps]`.
- macOS avfoundation grabs the display; auto-detects the "Capture screen N" device index. Crop a single
  window/region with `WxH+X+Y` in screen pixels (e.g. `1200x760+40+120`), else `full`.
- REQUIRES **Screen Recording** permission for your terminal (System Settings › Privacy & Security ›
  Screen Recording) — without it the frame is black. Bring the target app to the front before recording.

## Code capture — record-code.sh
- `bash scripts/record-code.sh <file> <out.mp4> [fontsize=16] [pace=0.10]` — syntax-highlights any source
  file (bat › pygmentize › numbered cat) and scrolls it like a human reading. Smaller `pace` = faster.

## Real ADO portal (and any authenticated web tool)
- org https://msazure.visualstudio.com / MCAS. Deep link a log step:
  `_build/results?buildId=<id>&view=logs&j=<jobGuid>&t=<taskGuid>` (get guids from timeline API).
- Timeline: `az rest --resource 499b84ac-1321-427f-aa17-267ca6975798 --url ".../build/builds/<id>/timeline?api-version=7.1"`.
- `node scripts/record-browser.js "<url>" seg.webm 30` (copies cookies → SSO; deletes profile after). Trim first ~6–8s (auth load).

## k9s + pod logs
- `bash scripts/record-k9s.sh <ctx> <ns> <pod-filter> k9.mp4`. Needs VPN. agg RENDERS the log sub-view.
- pods view shows READY/STATUS/RESTARTS; `l`=logs, `/reconcile` filter, `t`=timestamps. Trim trailing `[server exited]`.

## Real MDA / Microsoft tool capture targets (deep-link patterns for record-browser.js)
These are the actual tools MDA/Microsoft engineers use — capture them instead of generic "Key Vault".
- **EV2 / ExpressV2** (rollouts, service artifacts): `https://ev2portal.azure.net` — deep link a rollout to show stage progress / logs.
- **Geneva Monitoring** (MDM metrics + MDS logs, dashboards, monitors): `https://jarvis-west.dc.ad.msft.net/dashboard/...` — link a dashboard or metric chart.
- **IcM** (incidents, on-call): `https://portal.microsofticm.com/imp/v3/incidents/details/<id>` — show an incident summary (read-only).
- **Kusto / ADX** (queries against cluster data): `https://dataexplorer.azure.com` or Kusto web — run a read-only KQL and show the result grid.
- **Azure DevOps** (pipelines, PRs, work items): see "Real ADO portal" above.
- **Helm / ConfigGen** (topology → EV2 artifacts): show the generated manifests in Code, or the ConfigGen build output in terminal.
- **Service Tree** (service metadata/ownership): `https://servicetree.msftcloudes.com` — link a service node.
- For any of the above, `record-browser.js` reuses the authenticated Chrome profile for SSO; trim the first ~6–8s of auth load, and delete the copied profile after (Security rule).

## Narration (Kokoro default, offline; Piper fallback)
- `WORK=~/demo_build bash scripts/tts.sh seg.txt seg.wav am_michael`  (kokoro). Piper: `... seg.wav en_US-ryan-high piper`
- Spell terms: "E V 2", "k nine s", "C R D", "S L A". ryan≈US male, cori≈GB female. macOS `say` = rejected.

## Stitch
- `WORK=/tmp/demo_build bash scripts/stitch.sh ~/Desktop/x-demo.mp4 card_title.webm=1.wav seg1.webm= k9.mp4=4.wav ...`
- Pad with `=` for silent; video length wins, audio apad'd. Concat -c copy. ffprobe `-show_entries format=duration -of default=nw=1:nk=1`.
- **Flat-frame auto-trim (built in)**: each section's flat pre-paint head is detected and skipped, then
  the tail is clone-padded to preserve length (narration stays in sync). Tunables: `TRIM_FLAT_HEAD=0`
  to disable, `FLAT_STD` (grayscale-stddev threshold, def 7), `FLAT_MAXHEAD` (max secs to chop, def 1.5).
  This is what keeps check_demo.py's flat-frame check at 0 with no manual card trimming.

## Gotchas
- Playwright needs `channel:'chrome'` (no bundled chromium). Run with NODE_PATH if installed elsewhere.
- agg idle: cards/term idle=2; k9s idle=10 to keep real-time. fonts: term 18, k9s 17.
- ffprobe v8: use `-loglevel quiet`, not `-v0`.
- SECURITY: scripts delete copied Chrome profile; also rm any token files. Never commit.

## Self-QA (automated, no human needed)
Run after every stitch so you can iterate without asking the user:
- `.ttsenv/bin/python scripts/check_demo.py <demo.mp4> --sections "name:start:end,..." --expect "kw1,kw2,..." --out report.json`
- Scores 0-100 from: per-section motion (catches static screenshots), sharpness, near-blank frames,
  OCR bad-page detection (login/loading/404/error), expected-keyword presence, audio loudness +
  longest silence gap (catches trailing dead air). Exit 0 if score>=80 & no STATIC/bad-page/no-audio.
- fps defaults to 1 and frames are scaled to 1100px before OCR (fast: ~30-60s). Cards (title/end/
  dryrun/arch/intro/outro) are exempt from the STATIC check; only a brief (<=1s) flat fade at the very
  start/end is allowed — any other flat (white OR black) frame is flagged (stitch.sh auto-trims card
  pre-paint heads so this stays at 0). 404/403 only flag with "not found"/"forbidden".
- Iterate loop: if longest_silence>=4s, a section's video is longer than its narration → re-trim that
  section to ≈narration+0.8s and re-stitch (video length governs section length via -shortest+apad).
  If a section motion is ~0 (static) → re-record it as live (record-live-logs.sh / scroll the pane).

## Terminal logs — NO WRAP discipline (critical for "real" look)
Wrapped log lines are the #1 thing that makes a terminal look cramped/fake. Two rules:
1. Force the recording width: asciinema 3.x `rec --window-size COLSxROWS` sets the pty size so the
   pane can't shrink to 80 cols (the classic tmux-client-resize bug that wraps everything). Keep the
   longest formatted log line <= COLS-6 (measure it first). 124x34 @ agg --font-size 24 → ~12px/char,
   readable, fills 1440 wide.
2. Compact the log format (fmt_pace.py): drop the redundant app prefix on every line via
   `FMT_DROP_PREFIX` (e.g. `FMT_DROP_PREFIX=contosovalidation.` strips it → just the last segment),
   shorten levels (WARNING->WARN), and cap message length with `FMT_MAXMSG` (def 82) so nothing wraps.
- Most reliable recorder: `asciinema rec -q --window-size 124x34 -c "bash seg.sh" cast` where seg.sh
  echoes a realistic prompt + real `kubectl get pods` snapshot, then streams the REAL captured log
  through fmt_pace.py. Avoid the tmux+attach path (kill-server truncates the cast → "[server exited]").
- If the live cluster needs VPN and is unreachable, replay REAL captured logs (saved .txt) + a saved
  `get pods` snapshot through the same pacer — same on-topic content, reproducible, still looks live.

## Browser zoom — don't over-zoom
record-browser.js default zoom is now 1.0 (was 1.25). At 1.0 with viewport 1440x900 +
deviceScaleFactor:2 the FULL page is visible (file tree + code, full pipeline stage flow, full EV2
job list + log) and text stays crisp. Zoom >1.1 crops too much and reads as "zoomed in / can't see
context" — users dislike it. Only raise zoom for a single tiny target you want to spotlight.
