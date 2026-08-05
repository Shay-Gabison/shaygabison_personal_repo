# demo-builder-xp — cross-platform narrated demo builder

Turn any feature into a polished **2–3 minute narrated screen-recording demo** — designed
title/section cards, animated terminal / code / log panels, real ADO / portal / kubectl /
native-app footage, and an **offline neural voice-over**. Output is **1440×900, 30fps, MP4**.

This is the **cross-platform edition** of the `demo-builder` skill: it produces the same result on
**macOS, Windows, and Linux** using only portable tooling. On Windows it runs straight from
PowerShell — no WSL, no bash.

## Platform & tool support

| Aspect            | Support                                                                    |
|-------------------|----------------------------------------------------------------------------|
| **OS**            | macOS · Windows · Linux (same pipeline, same output)                        |
| **Runtime deps**  | Python 3, Node + Playwright (Chrome), ffmpeg — that's all                   |
| **No longer needs** | Homebrew, tmux, asciinema, agg, avfoundation-specific tooling            |
| **Web / portal**  | ADO pipelines, EV2 logs, Geneva metrics, IcM, Service Tree, any authed site |
| **Terminal/code/logs** | animated HTML panels via Playwright (identical on every OS)            |
| **Native apps**   | screen/window/region grab — avfoundation (mac) · gdigrab (win) · x11grab (linux) |
| **Narration**     | Kokoro neural TTS (offline); Piper fallback. No cloud, no OS built-in TTS   |

You are **not** limited to a fixed tool list — the engineer can ask to record *any* tool (logs,
metrics, terminal, code, portal, a desktop app) and it is routed through the capture table in
`SKILL.md`.

## Quick start

```bash
# 1. install (idempotent; prints per-OS hints for anything missing)
python demo.py doctor        # or python3 on macOS/Linux
python setup.py

# 2. build sections
python demo.py cards   deck/deck.html out/ title:18,arch:28,end:10
python demo.py panel   term.json term.webm
python demo.py browser "https://dev.azure.com/.../_build/results?buildId=123" ado.webm 30 900 1.0
python demo.py screen  app.mp4 8 --region 1200x800+40+80

# 3. narrate, stitch, self-QA
python demo.py tts     narr.txt narr.wav am_michael
python demo.py stitch  final.mp4 card_title.webm=title.wav ado.webm=ado.wav
python demo.py qa      final.mp4 --sections "title:0:18,ado:18:48" --expect "pipeline,green"
```

> **Interpreter:** use `python` on Windows, `python3` on macOS/Linux. `demo.py` re-invokes its
> Python helpers with the same interpreter you launched it with.

## How it differs from `demo-builder` (macOS)

| | `demo-builder` (mac) | `demo-builder-xp` (this) |
|---|---|---|
| Terminal/log capture | tmux + asciinema + agg | Playwright HTML panel (`capture_panel.js`) |
| Screen grab | avfoundation only | avfoundation / gdigrab / x11grab (auto) |
| Orchestration/stitch/setup | bash scripts | Python (`demo.py`, `stitch.py`, `setup.py`) |
| Runs on Windows | no | **yes** |

Everything else — the design system, read-only guarantees, offline Kokoro voice, and the
`check_demo.py` self-QA harness — is shared.

## Files
- `scripts/demo.py` — single cross-platform CLI (doctor/cards/panel/browser/screen/tts/stitch/qa).
- `scripts/platform_utils.py` — all OS-specific logic (paths, ffmpeg grabber, exe resolution).
- `scripts/capture_panel.js` — terminal/code/logs → animated panel (Playwright).
- `scripts/capture_browser.js` — authenticated portal/ADO capture (copies real Chrome cookies).
- `scripts/capture_screen.py` — native window/desktop capture per-OS.
- `scripts/render_cards.js` — deck slides → webm.
- `scripts/tts.py` + `scripts/kokoro_synth.py` — offline neural narration.
- `scripts/stitch.py` — mux + concat + auto flat-head trim → final MP4.
- `scripts/check_demo.py` — self-QA scorer (0–100).
- `scripts/setup.py` — cross-platform installer.
- `deck/` — `deck.css`, `deck.template.html`, `deck.example.html`.

See `SKILL.md` for the full workflow and `WORKFLOW.md` for the ffmpeg/Playwright/TTS cheatsheet.
