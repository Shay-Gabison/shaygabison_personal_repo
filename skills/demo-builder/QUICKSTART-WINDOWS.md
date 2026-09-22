# demo-builder — Windows quick start

A cross-platform skill that turns any feature into a **narrated screen-recording demo** (1440×900
MP4). Same pipeline on **Windows, macOS, and Linux**. There is no driver script — you call four
small primitives directly and the agent orchestrates the rest (real data via MCP → author →
capture → stitch → self-QA).

---

## 1. Install the 3 dependencies (Windows)
Open **PowerShell** and install the only three runtime deps — all cross-platform:

```powershell
winget install Gyan.FFmpeg          # ffmpeg + ffprobe
winget install OpenJS.NodeJS.LTS    # node + npm
winget install Python.Python.3.11   # python (adds the `python` command)
```
Close and reopen PowerShell so the new commands are on PATH.

## 2. One-time setup (documented — no setup script)
```powershell
$env:WORK   = "$HOME\demo_build"
$env:NODE_PATH = "$env:WORK\node_modules"
mkdir $env:WORK -Force; cd $env:WORK
npm i playwright                    # capture.js uses installed Chrome/Edge, or bundled chromium
pip install edge-tts               # neural voice — tiny wheels, works on locked-down Windows
# quick check:
node -e "require('playwright');console.log('playwright OK')"
python -c "import shutil;print('ffmpeg',shutil.which('ffmpeg'))"
```

> **Interpreter name:** on Windows use **`python`**; on macOS/Linux use **`python3`**. Everything
> else is identical.

## 3. Build a demo (from the skill folder, with `$env:NODE_PATH` set)
```powershell
# deck cards
node scripts\capture.js cards deck\deck.template.html out\ title:15,arch:25,end:10

# a terminal / code / logs panel  (edit spec.json — see WORKFLOW.md)
node scripts\capture.js panel spec.json out\panel.webm

# a real authenticated portal / Azure DevOps page (uses your logged-in Edge/Chrome cookies)
$env:DBXP_PROFILE = "edge"   # managed boxes: ADO SSO usually lives in Edge
node scripts\capture.js browser "https://dev.azure.com/<org>/<proj>/_build/results?buildId=123" out\ado.webm 20 800 1.0

# narrate, stitch, self-score
python scripts\tts.py  narr.txt out\narr.wav am_michael
python scripts\stitch.py out\final.mp4 out\card_title.webm=out\narr.wav out\ado.webm=
python scripts\check_demo.py out\final.mp4 --sections "title:0:15" --expect "your,keywords"
```

## What each primitive does
| Command | Purpose |
|---|---|
| `node capture.js cards`   | designed title/section/architecture slides → webm |
| `node capture.js panel`   | terminal / code / logs as animated panels (no tmux/asciinema) |
| `node capture.js browser` | real authenticated Azure DevOps / portal capture (cookies) |
| `python tts.py`     | offline/neural narration (edge-tts / Kokoro; voices: am_michael, af_heart, …) |
| `python stitch.py`  | mux + concat → final MP4 (auto flat-head trim) |
| `python check_demo.py` | self-QA score 0–100 |

## Notes for Windows
- **Browser capture** copies your Edge/Chrome cookies (`%LOCALAPPDATA%\Microsoft\Edge\User Data`
  or `...\Google\Chrome\User Data`), records the page, then **deletes** the copy (no credentials
  left behind). Set `$env:DBXP_PROFILE="edge"` for ADO SSO; `$env:DBXP_NOSANDBOX="1"` on locked-down
  hosts. Probe auth first with a `.png` output before recording video.
- **Native desktop grab** (a non-browser app) uses an ffmpeg `gdigrab` one-liner — see WORKFLOW.md
  "Native capture recipes". Bring the target window to the foreground first.
- Full command reference and tuning tips are in **WORKFLOW.md**; the skill contract is in **SKILL.md**.

Read-only by design: it shows tools and levers, it never deploys/scales/merges anything.
