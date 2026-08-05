# WORKFLOW — demo-builder-xp cheatsheet (macOS / Windows / Linux)

All commands go through `scripts/demo.py`. Use `python` on Windows, `python3` on macOS/Linux.
Set a custom work dir with the `WORK` env var (default `~/demo_build`).

## 0. Environment
```
python demo.py doctor          # prints OS, ffmpeg/ffprobe, node/npm, chrome profile, tts venv, hints
python setup.py [work_dir]     # idempotent install: playwright+chrome, kokoro venv; ffmpeg/node hints
```
`setup.py` never assumes a package manager — it prints the right hint per OS
(`brew` / `winget` / `apt`) for anything missing, and installs the portable pieces
(Playwright, Chrome channel, Kokoro venv) itself.

## 1. Deck cards
```
python demo.py cards deck/deck.html out/ title:18,arch:28,step1:26,end:10
# -> out/card_title.webm, out/card_arch.webm, ...
```
Copy `deck/deck.template.html` → `deck/deck.html`, edit text per feature, keep the CSS.
Render each card at ≈ narration + 0.4s (stitch auto-trims the flat pre-paint head).

## 2. Panels (terminal / code / logs) — the cross-platform capture
```
python demo.py panel spec.json panel.webm
```
`spec.json`:
```json
{
  "type": "terminal",            // terminal | code | logs
  "title": "cards + real footage",
  "lang":  "go",                 // for type=code (naive highlighter)
  "lines": ["$ kubectl get pods", "NAME   READY   STATUS", "dbset-0  1/1  Running"],
  "pace":  0.10,                 // seconds between lines (typing/scroll feel)
  "tail":  1.5,                  // dwell seconds on final frame
  "fontsize": 20
}
```
Panel duration ≈ `len(lines)*pace + tail + 0.6`. **Make the panel ≥ its narration** — in `stitch`
the video governs section length and `-shortest` trims to it, so a too-short panel cuts narration.
Pad by adding trailing lines or raising `tail`/`pace`.

Replaces tmux+asciinema+agg entirely: the panel is rendered in headless Chrome and recorded to
webm, so it looks the same on every OS.

## 3. Authenticated browser (ADO / EV2 / Geneva / IcM / any portal)
```
python demo.py browser "<deep-link-url>" out.webm <seconds> <scrollPx> <zoom>
# e.g. ADO build:
python demo.py browser \
  "https://dev.azure.com/msazure/MCAS/_build/results?buildId=123&view=logs" \
  ado.webm 30 900 1.0
```
Copies the real Chrome **cookies** (per-OS `User Data` path resolved automatically) into a throwaway
profile, drives the deep link, incremental-scrolls `scrollPx` over the duration, then **deletes the
copied profile** (auth never persists in the work dir). Keep `zoom` at `1.0` for a full-page view.

## 4. Native app / desktop (metrics viewer, IDE, Excel, a video)
```
python demo.py screen out.mp4 <seconds> [--region WxH+X+Y] [--display N] [--fps 30]
```
Grabber per-OS: **avfoundation** (mac) / **gdigrab** (win) / **x11grab** (linux), normalized to
1440×900. Foreground the target window first.
- **macOS**: grant Screen Recording permission to your terminal (System Settings → Privacy &
  Security → Screen Recording). Device index is auto-detected from `ffmpeg -f avfoundation
  -list_devices`.
- **Windows**: gdigrab captures the visible desktop; `--region` offsets/sizes the crop.
- **Linux**: uses `$DISPLAY`; Wayland needs XWayland.

## 5. Narration (offline neural)
```
python demo.py tts narr.txt narr.wav am_michael           # engine defaults to kokoro
python demo.py tts narr.txt narr.wav bm_george kokoro     # British voice -> lang 'b' auto
python demo.py tts narr.txt narr.wav en_US-ryan-high piper # fallback engine
```
Spell tricky terms phonetically in the script: `E V two`, `k nine s`, `M D A`, `A D O`. Kokoro venv
lives at `<work>/.ttsenv` (created by `setup.py`); `tts.py` finds `Scripts/python.exe` on Windows or
`bin/python` on Unix automatically.

## 6. Stitch
```
python demo.py stitch final.mp4 \
  card_title.webm=title.wav  ado.webm=ado.wav  panel.webm=panel.wav  card_end.webm
```
- `vid=wav` per section; omit `=wav` (or use `vid=`) for a silent section.
- Video governs length; audio is 48k stereo, apad'd, `-shortest` trims to video.
- **Auto flat-head trim**: first non-flat frame of each section detected via grayscale-stddev
  (same metric as `check_demo.py`), head skipped, tail clone-padded to preserve length. Tunables:
  `TRIM_FLAT_HEAD=0` (off), `FLAT_STD` (default 7), `FLAT_MAXHEAD` (default 1.5s). Needs Pillow.

## 7. Self-QA (iterate without the user)
```
python demo.py qa final.mp4 \
  --sections "title:0:18,ado:18:48,panel:48:74,end:74:84" \
  --expect "pipeline,green,1/1" \
  --out report.json
```
Scores 0–100 on per-section motion (catches static screenshots), sharpness, near-blank frames,
OCR keyword/bad-page checks, and audio loudness + trailing-silence gaps. **Target: score ≥ 90 and
longest_silence < 4s.** Static-exempt section names: `title,end,dryrun,intro,outro,arch,
architecture,cover,section`. Re-record/re-stitch until it passes, then deliver.

## Design system (shared with demo-builder)
Dark navy `#0b0e14`; hero = mono eyebrow, big mono title, subtitle with bold phrase, green pill
badges; body = mac-chrome panels, JetBrains Mono, green values, warn/validation callouts. Section
cards between phases. `deck/deck.template.html` ships hero/architecture/terminal/checklist/end slides.

## Gotchas
- **Interpreter name**: `python` (Windows) vs `python3` (mac/Linux). `demo.py` propagates its own.
- **NODE_PATH**: `demo.py` sets it to `<work>/node_modules`; if you call a `.js` directly, export it.
- **Panel shorter than narration** → narration truncated by `-shortest`. Lengthen the panel.
- **British Kokoro voice** (`bm_*`/`bf_*`) auto-selects lang code `b`; US voices use `a`.
- **ffmpeg without drawtext**: text-on-video uses PNG overlays (as in the meta-demo), never
  `drawtext`, since some ffmpeg builds lack freetype.
