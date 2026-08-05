---
name: demo-builder-xp
description: Cross-platform (macOS + Windows + Linux) demo-builder. Turn any feature into a 2–3 min narrated screen-recording demo — designed title/section cards, terminal/code/log panels, real ADO/portal/k8s/native-app footage, and an offline neural voice-over. Same result on Mac and Windows. Triggers — "create a demo", "make a demo video", "record a walkthrough", "screencast for <feature>", "narrated demo", "cross-platform demo".
---

# Demo Builder (cross-platform)

Turn any feature into a 2–3 min narrated demo that looks like a human recorded themselves with
real tools — designed title/section cards, mac-chrome style terminal & code panels, real
ADO / portal / kubectl / native-app footage, and a neural voice-over. **1440×900, 30fps, MP4.**

**This is the cross-platform edition.** It produces the same result on **macOS, Windows, and
Linux** using only three portable dependencies — **Python + Node/Playwright + ffmpeg**. There is
no Homebrew / tmux / asciinema / agg / avfoundation requirement. On Windows it runs from
PowerShell with no WSL or bash.

> There is also a macOS-tuned sibling skill (`demo-builder`). Use **this** one whenever the
> engineer may be on Windows, or when you want a single skill that works everywhere.

## STEP 0 — ALWAYS interview first (do not skip)

Use the **ask_user** tool to collect requirements BEFORE building anything. Present one form:

- **Feature / topic** (string) — what the demo is about.
- **One-line goal** (string) — the headline outcome to prove.
- **Audience** (enum): Eng team / Leadership / Customer / Mixed.
- **Length** (integer, seconds, default 165) — keep 150–180 for 2:30–3:00.
- **Tools to show** (open-ended, multi-select + free text) — ANY tool the engineer names.
  Common: ADO pipeline run, EV2 logs, kubectl/k9s + pod logs, Geneva metrics, IcM incident,
  ConfigGen, Service Tree, code, browser portal, terminal/CLI, a native desktop app, slides only.
  You are NOT limited to a fixed list — route each requested tool through the capture table below.
- **Architecture card?** (boolean, default true) — a "how it works" 3-node flow section.
- **Style** (enum, default reference-deck): reference-deck (cards + panels) / raw screen-capture / hybrid.
- **Voice** (enum, default am_michael — natural Kokoro neural): am_michael / am_adam / af_heart / bm_george / none.
- **Read-only?** (boolean, default true) — show levers, never execute deploy/scale/merge.
- **Output path** (string, default `~/Desktop/<slug>-demo.mp4`).
- **Real data sources** (string) — pipeline IDs, cluster context+namespace, repo, dashboard links.

After answers: write a tiny shot-list to `plan.md`, gather REAL data, build sections, narrate,
stitch, deliver. Confirm exact IDs/links before recording. Never invent numbers — pull them live.

## One entry point: `scripts/demo.py`

Everything routes through a single cross-platform CLI. **Use `python` on Windows and `python3`
on macOS/Linux** (they map to the same interpreter).

```
python demo.py doctor                                   # env check (OS, ffmpeg, node, chrome, tts)
python demo.py cards   deck.html out/ title:18,arch:28   # deck slides   -> card_<id>.webm
python demo.py panel   spec.json panel.webm              # terminal/code/logs animated panel
python demo.py browser <url> b.webm 30 <scrollPx> <zoom> # authed ADO/portal capture (real cookies)
python demo.py screen  s.mp4 8 --region 1200x800+40+80   # native window / desktop capture
python demo.py tts     narr.txt narr.wav am_michael      # offline neural narration
python demo.py stitch  final.mp4 a.webm=a.wav b.mp4=b.wav # mux + concat -> final MP4
python demo.py qa      final.mp4 --sections "..." --expect "..."   # self-QA score 0-100
```

## Capture routing — record ANY tool the engineer asks for

| Engineer asks to show…                | Use                    | How it works (cross-platform)                          |
|---------------------------------------|------------------------|--------------------------------------------------------|
| ADO pipeline / EV2 / portal / any web | `demo.py browser`      | copies real Chrome cookies → Playwright deep-link + scroll |
| terminal / CLI session                | `demo.py panel` (type=terminal) | animated mac-chrome panel in headless Chrome    |
| source code                           | `demo.py panel` (type=code)     | syntax-highlighted panel                        |
| logs (kubectl/EV2/app logs)           | `demo.py panel` (type=logs)     | paced streaming log panel                       |
| Geneva metrics / IcM / dashboards     | `demo.py browser`      | authenticated portal capture                           |
| native desktop app (IDE, Excel, video)| `demo.py screen`       | ffmpeg grabber: avfoundation·mac / gdigrab·win / x11grab·linux |
| title / section / architecture / checklist | `demo.py cards`   | deck slides from `deck/deck.html`                      |

The **panel** capture is the key cross-platform win: terminal / code / log footage is rendered as
an animated HTML panel via Playwright, so it looks identical on Windows and Mac with **no** tmux,
asciinema, or agg. Data-gathering MCPs (Geneva, Ev2, IcM, ConfigGen) complement this — use an MCP
to fetch the real numbers, then show them in a panel or a live portal capture.

## Pipeline at a glance

1. **Deck cards** — `deck/deck.html` + `deck/deck.css`; render via `scripts/render_cards.js`.
2. **Panels** — `scripts/capture_panel.js` renders terminal/code/logs as animated webm (Playwright).
3. **Real portal/ADO** — `scripts/capture_browser.js` inherits your authenticated Chrome cookies.
4. **Native apps** — `scripts/capture_screen.py` grabs a window/region via the OS ffmpeg grabber.
5. **Narration** — `scripts/tts.py` → Kokoro (offline neural) by default; Piper fallback.
6. **Stitch** — `scripts/stitch.py` mux each section (video governs length, audio padded) + concat.

`scripts/setup.py` installs Playwright+Chrome and the Kokoro venv, and prints per-OS install hints
for ffmpeg/node. Work dir defaults to `~/demo_build` (NOT /tmp, which can be wiped mid-session).

## Hard rules
- **Read-only**: never deploy/scale/merge to make a demo. Show the lever; don't pull it.
- **Real numbers only**: query ADO/k8s/Geneva/IcM live; quote actuals (1/1, restarts=0, counts).
- **Offline voice**: Kokoro TTS (natural neural, ~82M params) by default; Piper fallback — no audio
  sent to 3rd parties. OS built-in TTS (`say`, SAPI) is rejected.
- **Video clarity**: browser capture uses full-page view at zoom 1.0 (whole page visible, not
  zoomed-in); panels use fontsize ≥ 20 with a dwell on the final frame.
- **No flat/blank frames (automatic)**: `stitch.py` auto-detects the first non-flat frame of EACH
  section (grayscale-stddev probe matching `check_demo.py`) and skips the flat head, then clone-pads
  the tail so length/narration stay in sync. Render cards at ≈narration+0.4s. Disable with
  `TRIM_FLAT_HEAD=0`.
- **Security**: `capture_browser.js` copies then DELETES the Chrome profile after recording (auth
  cookies never persist in the work dir).
- **Self-QA (iterate without the user)**: after stitching, run `python demo.py qa <mp4> --sections
  "name:start:end,..." --expect "kw,..."`. Re-record/re-stitch until score ≥ 90 and
  longest_silence < 4s before delivering.

## Cross-platform notes
- **Interpreter**: `python` (Windows) vs `python3` (macOS/Linux). `demo.py` re-invokes helpers with
  the same interpreter it was started with, so pass whichever your OS uses.
- **Node modules**: `demo.py` sets `NODE_PATH` to `<work>/node_modules` automatically.
- **Screen permission**: macOS needs Screen Recording permission for your terminal; Windows gdigrab
  captures the visible desktop (foreground the target window first); Linux uses `$DISPLAY` (XWayland
  for Wayland). `demo.py doctor` prints the right hint for the current OS.

See `scripts/` for each step and `WORKFLOW.md` for the full ffmpeg/Playwright/TTS cheatsheet.
