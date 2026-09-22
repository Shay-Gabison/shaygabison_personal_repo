# demo-builder — cross-platform narrated demo builder

Turn any feature into a polished **2–3 minute narrated screen-recording demo** — designed
title/section cards, animated terminal / code / log panels, real ADO / portal / kubectl /
native-app footage, and an **offline/neural voice-over**. Output is **1440×900, 30fps, MP4**.

Same result on **macOS, Windows, and Linux** using only portable tooling. On Windows it runs
straight from PowerShell — no WSL, no bash.

## How it's built: MCP + AI, not a pile of scripts

The agent orchestrates each demo. The skill ships **four tiny primitives**; the agent does the rest
— pulls real numbers from **MCP tools**, authors the deck/panel/narration, then calls the primitives
and self-QAs. There is no monolithic driver and no dispatcher.

| Aspect            | Support                                                                    |
|-------------------|----------------------------------------------------------------------------|
| **OS**            | macOS · Windows · Linux (same pipeline, same output)                        |
| **Runtime deps**  | Python 3, Node + Playwright (Chrome/Edge), ffmpeg — that's all              |
| **No longer needs** | Homebrew, tmux, asciinema, agg (optional native recipes only)            |
| **Data**          | fetched live via MCP (ADO / EV2 / Geneva / IcM / ConfigGen) — real numbers  |
| **Web / portal**  | ADO pipelines, EV2 logs, Geneva metrics, IcM, any authed site (real cookies)|
| **Terminal/code/logs** | animated HTML panels via Playwright (identical on every OS)            |
| **Native apps**   | ffmpeg screen grab recipe (mac/win/linux) — see WORKFLOW.md                 |
| **Narration**     | edge-tts / Kokoro neural (offline-first); Piper fallback. No OS built-in TTS |

## The four primitives (`scripts/`)
- `capture.js` — Playwright capture, three modes: `cards` | `panel` | `browser`.
- `tts.py` — offline/neural narration (auto engine: edge → kokoro → piper → OS built-in).
- `stitch.py` — ffmpeg mux + concat + auto flat-head trim → final MP4.
- `check_demo.py` — self-QA scorer (0–100: motion, sharpness, blank frames, OCR, audio gaps).

## Quick start
```bash
export WORK="$HOME/demo_build"; export NODE_PATH="$WORK/node_modules"   # PowerShell: $env:...
# deps: ffmpeg (brew/winget/apt) + `npm i playwright` + `pip install edge-tts`  (see WORKFLOW.md "Setup")

node scripts/capture.js cards   deck/deck.html out/ title:18,arch:28,end:10
node scripts/capture.js panel   term.json term.webm
node scripts/capture.js browser "https://dev.azure.com/.../_build/results?buildId=123" ado.webm 30 900 1.0
python3 scripts/tts.py     narr.txt narr.wav am_michael
python3 scripts/stitch.py  final.mp4 out/card_title.webm=title.wav ado.webm=ado.wav
python3 scripts/check_demo.py final.mp4 --sections "title:0:18,ado:18:48" --expect "pipeline,green"
```
Use `python` on Windows, `python3` on macOS/Linux. Everything else is identical.

See `SKILL.md` for the full contract (interview → MCP data → author → capture → stitch → QA) and
`WORKFLOW.md` for setup, exact recipes (incl. native ffmpeg/k9s capture), the voice cast, and the
ffmpeg/Playwright/TTS cheatsheet.
