# WORKFLOW — demo-builder cheatsheet (macOS / Windows / Linux)

No driver script and no dispatcher — **you** run the four primitives directly and orchestrate the
rest. Use `python` on Windows, `python3` on macOS/Linux. Set the work dir + Node path once:

```bash
export WORK="$HOME/demo_build"                 # PowerShell: $env:WORK="$HOME\demo_build"
export NODE_PATH="$WORK/node_modules"          # PowerShell: $env:NODE_PATH="$env:WORK\node_modules"
```

The four primitives live in `scripts/`: `capture.js` (cards/panel/browser), `tts.py`, `stitch.py`,
`check_demo.py`. Everything else — data, deck text, narration, orchestration — is authored by you.

## Setup (one-time, documented — no setup script)

```bash
mkdir -p "$WORK" && cd "$WORK"
# 1) ffmpeg + ffprobe
#    macOS:  brew install ffmpeg     Windows: winget install Gyan.FFmpeg     Linux: sudo apt install ffmpeg
# 2) Playwright (Node) — capture.js will use installed Chrome/Edge, or the bundled chromium:
npm i playwright            # then optionally:  npx playwright install chromium
# 3) Neural voice — pick ONE, best first:
pip install edge-tts        # tiny wheels, NO PyTorch — works on locked-down Windows (Azure neural)
pip install kokoro soundfile numpy   # offline neural (needs PyTorch; skip on locked-down boxes)
#    Piper is the offline fallback; drop *.onnx voices in $WORK/voices/ if you use it.
```
`tts.py` auto-selects the best available engine: **edge → kokoro → piper → OS built-in** (last
resort). No engine install script is needed — just `pip install` whichever you want.

Quick env check (replaces the old `doctor`):
```bash
python3 -c "import shutil;print('ffmpeg',shutil.which('ffmpeg'));print('node',shutil.which('node'))"
node -e "require('playwright');console.log('playwright OK')"    # needs NODE_PATH set
```

## 1. Deck cards
```bash
node scripts/capture.js cards deck/deck.html out/ title:18,arch:28,step1:26,end:10
# -> out/card_title.webm, out/card_arch.webm, ...
```
Copy `deck/deck.template.html` → `deck/deck.html`, edit text per feature, keep the CSS. Render each
card at ≈ narration + 0.4s (stitch auto-trims the flat pre-paint head).

## 2. Panels (terminal / code / logs) — the cross-platform capture
```bash
node scripts/capture.js panel spec.json panel.webm
```
`spec.json`:
```json
{ "type": "terminal", "title": "cards + real footage", "lang": "go",
  "lines": ["$ kubectl get pods", "NAME   READY   STATUS", "dbset-0  1/1  Running"],
  "pace": 0.10, "tail": 1.5, "fontsize": 20 }
```
`type` = `terminal | code | logs`. Duration ≈ `len(lines)*pace + tail + 0.6`. **Make the panel ≥ its
narration** — in stitch the video governs length and `-shortest` trims to it, so a too-short panel
cuts narration. Pad with trailing lines or a larger `tail`/`pace`. Feed **real** lines pulled from an
MCP (kubectl/EV2/Geneva) — this replaces tmux+asciinema+agg entirely and looks identical on every OS.

## 3. Authenticated browser (ADO / EV2 / Geneva / IcM / any portal)
```bash
node scripts/capture.js browser \
  "https://dev.azure.com/msazure/MCAS/_build/results?buildId=123&view=logs" ado.webm 30 900 1.0
# args: <url> <out.webm> <seconds> [scrollPx] [zoom]
node scripts/capture.js browser "<url>" probe.png 6     # .png out = auth/login probe (title + looksLikeLogin)
```
Copies the real Chrome/Edge **cookies** (per-OS `User Data` path auto-resolved) into a throwaway
profile, drives the deep link, incremental-scrolls `scrollPx` over the duration, then **deletes the
copied profile**. Keep `zoom` at `1.0` for a full-page view. On managed boxes where SSO lives in
Edge, set `DBXP_PROFILE=edge` (or `DBXP_CHANNEL=msedge`); `DBXP_NOSANDBOX=1` on locked-down hosts.

## 4. Narration (offline / neural)
```bash
python3 scripts/tts.py narr.txt narr.wav am_michael            # engine auto: edge->kokoro->piper->OS
python3 scripts/tts.py narr.txt narr.wav en-US-AriaNeural edge # force edge-tts (Azure neural)
python3 scripts/tts.py narr.txt narr.wav bm_george kokoro      # British Kokoro voice -> lang 'b' auto
```
Spell tricky terms phonetically: `E V two`, `k nine s`, `M D A`, `A D O`. **Voice cast** for a
multi-speaker feel (edge-tts names): Andrew (`en-US-AndrewNeural`) for title/arch/checklist/end,
Brian for terminal, Aria/Guy/Emma for the real-footage sections. Kokoro aliases: am_michael/am_adam/
af_heart/bm_george.

## 5. Stitch
```bash
python3 scripts/stitch.py final.mp4 \
  out/card_title.webm=title.wav  ado.webm=ado.wav  panel.webm=panel.wav  out/card_end.webm
```
- `vid=wav` per section; omit `=wav` (or use `vid=`) for a silent section. Video governs length;
  audio is 48k stereo, apad'd, `-shortest` trims to video.
- **Auto flat-head trim**: first non-flat frame of each section detected via grayscale-stddev (same
  metric as `check_demo.py`), head skipped, tail clone-padded to keep length. Tunables:
  `TRIM_FLAT_HEAD=0` (off), `FLAT_STD` (default 7), `FLAT_MAXHEAD` (default 1.5s). For SPA pages that
  paint white ~10s, use `FLAT_NOPAD=1 FLAT_MAXHEAD=14` (trim the long blank head, no frozen tail).
  Needs Pillow.

## 6. Self-QA (iterate without the user)
```bash
python3 scripts/check_demo.py final.mp4 \
  --sections "title:0:18,ado:18:48,panel:48:74,end:74:84" \
  --expect "pipeline,green,1/1" --out report.json
```
Scores 0–100 on per-section motion (catches static screenshots), sharpness, near-blank frames, OCR
keyword/bad-page checks, and audio loudness + trailing-silence gaps. **Target ≥ 90 and
longest_silence < 4s.** Static-exempt sections: `title,end,intro,outro,arch,architecture,cover,
section`. Re-record/re-stitch until it passes, then deliver.

## Native capture recipes (optional, macOS/Linux — you run these directly)

These are the higher-fidelity captures that used to be wrapper scripts. Run them as-is; the output
webm/mp4 drops straight into `stitch.py`. On **Windows**, use `capture.js panel`/`browser` instead.

**a) Native desktop / window grab** (metrics viewer, IDE, Excel, a video) — one ffmpeg command:
```bash
# macOS (avfoundation; find the screen index via: ffmpeg -f avfoundation -list_devices true -i "")
ffmpeg -y -f avfoundation -capture_cursor 1 -framerate 30 -i "1" -t 8 \
  -vf "scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0x0b0e14,fps=30,format=yuv420p,setsar=1" \
  -c:v libx264 -crf 20 screen.mp4
# Windows (gdigrab, region optional): -f gdigrab -framerate 30 [-offset_x X -offset_y Y -video_size WxH] -i desktop
# Linux (x11grab): -f x11grab -framerate 30 -i $DISPLAY
```
macOS needs Screen Recording permission for your terminal (System Settings → Privacy & Security).

**b) Real k9s TUI** (pods → drill into logs → live reconcile stream) — needs `tmux asciinema agg`:
```bash
CTX=<kube-context> NS=<ns> FILTER=<pod-substr>; SOCK=/tmp/demo_k9.sock; CAST=/tmp/demo_k9.cast
tmux -S $SOCK new-session -d -x 150 -y 40 -s k9 "k9s --context $CTX -n $NS --command pods --readonly"; sleep 7
( asciinema rec --overwrite -q -c "tmux -S $SOCK attach -t k9" "$CAST" ) & sleep 1.5
tmux -S $SOCK send-keys -t k9 "/$FILTER" Enter; sleep 5
tmux -S $SOCK send-keys -t k9 Enter; sleep 2          # select pod
tmux -S $SOCK send-keys -t k9 "l"; sleep 6            # logs
tmux -S $SOCK send-keys -t k9 "/reconcile" Enter; sleep 13   # dwell on live stream
tmux -S $SOCK kill-server
agg --font-size 22 --fps-cap 15 --idle-time-limit 10 "$CAST" /tmp/k9.gif
ffmpeg -y -i /tmp/k9.gif -vf "fps=30,scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2:color=0x0b0e14,format=yuv420p,setsar=1" -c:v libx264 -crf 20 k9s.mp4
```
Jumping to the target pod with `G` (bottom) is more reliable than k9s v0.32 fuzzy filter. Read-only.

**c) Live kubectl log stream** — prefer the **MCP-first** path: fetch the real lines via Geneva/kusto
or `kubectl logs …`, drop them into a `panel` spec (`type=logs`), and let the panel pace them. That
gives the same "live" scroll cross-platform with no tmux. Only fall back to a raw terminal recording
(recipe b's tmux+asciinema+agg, running `kubectl logs <target> --all-containers | your-pacer`) when
you specifically need real terminal chrome on macOS/Linux.

## Smoke test (replaces the old test script)
```bash
mkdir -p /tmp/db_smoke
printf '{"type":"terminal","title":"smoke","lines":["$ echo hi","hi"],"pace":0.1,"tail":1}' > /tmp/db_smoke/s.json
node scripts/capture.js panel /tmp/db_smoke/s.json /tmp/db_smoke/p.webm    # -> "panel terminal ... Ns"
printf 'This is a demo builder smoke test.' > /tmp/db_smoke/n.txt
python3 scripts/tts.py /tmp/db_smoke/n.txt /tmp/db_smoke/n.wav am_michael
python3 scripts/stitch.py /tmp/db_smoke/out.mp4 /tmp/db_smoke/p.webm=/tmp/db_smoke/n.wav
python3 scripts/check_demo.py /tmp/db_smoke/out.mp4 --sections "p:0:3"
```

## Design system
Dark navy `#0b0e14`; hero = mono eyebrow, big mono title, subtitle with bold phrase, green pill
badges; body = mac-chrome panels, JetBrains Mono, green values, warn/validation callouts. Section
cards between phases. `deck/deck.template.html` ships hero/architecture/terminal/checklist/end slides.

## Gotchas
- **Interpreter name**: `python` (Windows) vs `python3` (mac/Linux).
- **NODE_PATH**: export it to `$WORK/node_modules` so `capture.js` resolves Playwright.
- **Panel shorter than narration** → narration truncated by `-shortest`. Lengthen the panel.
- **British Kokoro voice** (`bm_*`/`bf_*`) auto-selects lang code `b`; US voices use `a`.
- **ffmpeg without drawtext**: overlay text via PNG images, never `drawtext` (some builds lack freetype).
- **Managed Windows + ADO SSO**: set `DBXP_PROFILE=edge`; probe first with a `.png` browser capture.
