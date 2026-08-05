# demo-builder-xp — Windows quick start

A cross-platform skill that turns any feature into a **narrated screen-recording demo** (1440×900
MP4). Same pipeline on **Windows, macOS, and Linux**. This zip includes a **sample result**:
`sample-demo-builder-xp-demo.mp4` — watch it first to see what the tool produces.

---

## 0. Watch the sample (no install needed)
Open **`sample-demo-builder-xp-demo.mp4`** — a ~2:13 narrated demo that was built entirely with
this skill (title/architecture cards, terminal/code/log panels, a real authenticated Azure DevOps
capture, and an offline neural voice). That is the kind of output you'll get.

## 1. Install the 3 dependencies (Windows)
Open **PowerShell** and install the only three runtime deps — all cross-platform:

```powershell
winget install Gyan.FFmpeg          # ffmpeg + ffprobe
winget install OpenJS.NodeJS.LTS    # node + npm
winget install Python.Python.3.11   # python (adds the `python` command)
```
Close and reopen PowerShell so the new commands are on PATH.

## 2. One-time setup
From the unzipped folder:

```powershell
cd demo-builder-xp\scripts
python setup.py
python demo.py doctor
```
`setup.py` installs Playwright + Chrome and a local Kokoro (neural TTS) virtual-env into
`%USERPROFILE%\demo_build`. `doctor` prints a green/MISSING report for your machine.

> **Interpreter name:** on Windows use **`python`**; on macOS/Linux use **`python3`**. Everything
> else is identical.

## 3. Build your own demo
```powershell
# deck cards
python demo.py cards ..\deck\deck.template.html out\ title:15,arch:25,end:10

# a terminal / code / logs panel  (edit spec.json — see WORKFLOW.md)
python demo.py panel spec.json out\panel.webm

# a real authenticated portal / Azure DevOps page (uses your logged-in Chrome cookies)
python demo.py browser "https://dev.azure.com/<org>/<proj>/_build/results?buildId=123" out\ado.webm 20 800 1.0

# narrate, stitch, self-score
python demo.py tts  narr.txt out\narr.wav af_heart
python demo.py stitch out\final.mp4 out\card_title.webm=out\narr.wav out\ado.webm=
python demo.py qa   out\final.mp4 --sections "title:0:15" --expect "your,keywords"
```

## What each command does
| Command | Purpose |
|---|---|
| `python demo.py doctor`  | environment check for this machine |
| `python demo.py cards`   | designed title/section/architecture slides → webm |
| `python demo.py panel`   | terminal / code / logs as animated panels (no tmux/asciinema) |
| `python demo.py browser` | real authenticated Azure DevOps / portal capture |
| `python demo.py screen`  | native app / desktop capture (gdigrab on Windows) |
| `python demo.py tts`     | offline neural narration (Kokoro; voices: am_michael, af_heart, …) |
| `python demo.py stitch`  | mux + concat → final MP4 |
| `python demo.py qa`      | self-QA score 0–100 |

## Notes for Windows
- **Screen capture** uses `gdigrab` (whole visible desktop) — bring the target window to the
  foreground before recording. `--region WxH+X+Y` crops a rectangle.
- **Browser capture** copies your Chrome cookies from
  `%LOCALAPPDATA%\Google\Chrome\User Data`, records the page, then **deletes** the copy (no
  credentials left behind). Close Chrome first if the profile is locked.
- Full command reference and tuning tips are in **WORKFLOW.md**; the skill contract is in
  **SKILL.md**.

Read-only by design: it shows tools and levers, it never deploys/scales/merges anything.
