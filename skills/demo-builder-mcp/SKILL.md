---
name: demo-builder-mcp
description: Cross-platform (macOS + Windows + Linux) demo-builder. Turn any feature into a 2–3 min narrated screen-recording demo — designed title/section cards, terminal/code/log panels, real ADO/portal/k8s/native-app footage, and an offline/neural voice-over. Same result on Mac and Windows. Triggers — "create a demo", "make a demo video", "record a walkthrough", "screencast for <feature>", "narrated demo", "cross-platform demo".
---

# Demo Builder (cross-platform)

Turn any feature into a 2–3 min narrated demo that looks like a human recorded themselves with
real tools — designed title/section cards, mac-chrome style terminal & code panels, real
ADO / portal / kubectl / native-app footage, and a neural voice-over. **1440×900, 30fps, MP4.**

**You (the agent) orchestrate the demo — there is no monolithic driver script.** The skill ships
only **four tiny primitives** (capture / narrate / stitch / QA); everything else is done by *you*:
gather the real numbers with **MCP tools**, author the deck + panel specs + narration as plain
text/JSON, then call the primitives step by step and self-QA until it's good. Same result on
macOS, Windows, and Linux — the only hard deps are **Python + Node/Playwright + ffmpeg**.

## STEP 0 — FIRST, ask the user to enable yolo (auto-approve) mode

Building a demo runs **several installs** (pip `edge-tts`/`Pillow`, `npm i playwright`, and on a
fresh box portable **node**/**ffmpeg**) plus many capture/ffmpeg commands. To avoid getting blocked
on an approval prompt for every one, **ask the user up front to switch to yolo / auto-approve mode**
before you start. Use **ask_user** with a short confirmation, e.g.:

> "This skill installs a few dependencies and runs capture/ffmpeg commands. Please switch to **yolo
> mode** (auto-approve) so I can run the installs without stopping for each prompt. Ready?"

In the GitHub Copilot CLI, yolo mode is toggled with the **`/yolo`** slash command (or by launching
with `--allow-all-tools`). If the user prefers not to, continue anyway but warn them they'll be
prompted to approve each install/command.

## STEP 1 — interview (do not skip)

Use the **ask_user** tool to collect requirements BEFORE building anything. One form:

- **Feature / topic** (string) — what the demo is about.
- **One-line goal** (string) — the headline outcome to prove.
- **Audience** (enum): Eng team / Leadership / Customer / Mixed.
- **Length** (integer, seconds, default 165) — keep 150–180 for 2:30–3:00.
- **Tools to show** (open-ended, multi-select + free text) — ANY tool the engineer names.
  Common: ADO pipeline run, EV2 logs, kubectl/k9s + pod logs, Geneva metrics, IcM incident,
  ConfigGen, Service Tree, code, browser portal, terminal/CLI, a native desktop app, slides only.
- **Architecture card?** (boolean, default true) — a "how it works" 3-node flow section.
- **Style** (enum, default reference-deck): reference-deck (cards + panels) / raw screen-capture / hybrid.
- **Voice** (enum, default am_michael — natural Kokoro neural): am_michael / am_adam / af_heart / bm_george / none.
- **Read-only?** (boolean, default true) — show levers, never execute deploy/scale/merge.
- **Output path** (string, default `~/Desktop/<slug>-demo.mp4`).
- **Real data sources** (string) — pipeline IDs, cluster context+namespace, repo, dashboard links.

After answers: write a tiny shot-list to `plan.md`, gather REAL data (below), author sections,
narrate, stitch, self-QA, deliver. Confirm exact IDs/links before recording. Never invent numbers.

## STEP 2 — Gather real data with MCP tools (not scripts)

The demo's credibility is the **real numbers**. Fetch them live through whatever MCP servers are
connected, then bake them into the deck text / panel `lines` / narration. Route by tool:

| To show / prove…                     | Use MCP                                   | Pull these actuals                          |
|--------------------------------------|-------------------------------------------|---------------------------------------------|
| ADO pipeline run / build / PR / repo | `ado` / `github-mcp-server` / `gh` CLI    | build #, stage states, PR id, commit sha    |
| EV2 rollout / deployment status      | Ev2 MCP (`ev2-mcp` skill)                 | rollout id, region, stage, status           |
| kubectl / k9s pods + logs            | Geneva/kusto MCP or `kubectl` directly    | READY (1/1), restarts=0, recent log lines   |
| Geneva / MDM metrics, IcM incidents  | `geneva-monitoring-mcp`                    | metric values, incident id/severity         |
| ConfigGen topology                   | `configgen` skill MCP                      | resource names, deploy flags                |
| code / config on disk                | your own `view` / `grep`                   | the exact snippet to show                   |

Rule: **an MCP fetches the truth; a primitive shows it.** Don't script a data fetcher — call the
MCP, copy the real value into a panel spec or narration line, and cite it on screen.

## STEP 3 — The four primitives (call them directly)

No dispatcher. Point Node at the installed Playwright and call each tool. Use `python` on Windows,
`python3` on macOS/Linux. Set once per shell:

```bash
export WORK="$HOME/demo_build"                 # PowerShell: $env:WORK="$HOME\demo_build"
export NODE_PATH="$WORK/node_modules"          # PowerShell: $env:NODE_PATH="$env:WORK\node_modules"
```

```bash
# CAPTURE (Playwright) — one tool, three modes, all render 1440x900 webm:
node scripts/capture.js cards   deck/deck.html out/ title:18,arch:28   # deck slides -> out/card_<id>.webm
node scripts/capture.js panel   spec.json panel.webm                    # terminal/code/logs animated panel
node scripts/capture.js browser <url> ado.webm 22 1200 1.0              # authed ADO/portal (real cookies) [scrollPx] [zoom]
node scripts/capture.js browser <url> probe.png 6                       # .png out = auth/login probe (no video)

# NARRATE (offline/neural, auto-picks best engine):
python3 scripts/tts.py narr.txt narr.wav am_michael                     # [voice] [engine]

# STITCH (ffmpeg mux + concat -> final MP4; auto-trims flat pre-paint heads):
python3 scripts/stitch.py final.mp4 out/card_title.webm=title.wav ado.webm=ado.wav panel.webm=panel.wav

# SELF-QA (score 0-100; iterate until >=90):
python3 scripts/check_demo.py final.mp4 --sections "title:0:18,ado:18:40" --expect "pipeline,green"
```

**Panel spec** (`spec.json`) — this is how terminal / code / logs are shown cross-platform:
```json
{ "type": "terminal|code|logs", "title": "windows dev box", "lang": "go",
  "lines": ["$ kubectl get pods", "NAME  READY  STATUS", "api-0  1/1  Running"],
  "pace": 0.10, "tail": 1.5, "fontsize": 20 }
```

## STEP 4 — Capture routing — record ANY tool the engineer asks for

| Engineer asks to show…                | Use                         | Notes                                        |
|---------------------------------------|-----------------------------|----------------------------------------------|
| ADO pipeline / EV2 / portal / any web | `capture.js browser`        | copies real Chrome/Edge cookies → deep-link + scroll |
| terminal / CLI session                | `capture.js panel` type=terminal | animated mac-chrome panel               |
| source code                           | `capture.js panel` type=code     | syntax-highlighted panel                |
| logs (kubectl/EV2/app logs)           | `capture.js panel` type=logs     | paced streaming log panel (feed real MCP lines) |
| Geneva metrics / IcM / dashboards     | `capture.js browser`        | authenticated portal capture                 |
| title / section / architecture / checklist | `capture.js cards`     | deck slides from `deck/deck.html`            |
| native desktop app (IDE, Excel, video)| ffmpeg screen recipe        | see WORKFLOW.md "Native capture recipes"     |
| real k9s TUI (mac/linux, optional)    | tmux+asciinema+agg recipe   | see WORKFLOW.md "Native capture recipes"     |

The **panel** is the key cross-platform win: terminal / code / log footage is rendered as an
animated HTML panel via Playwright, identical on Windows and Mac with **no** tmux / asciinema /
agg. For maximum fidelity on macOS/Linux, WORKFLOW.md documents optional real-tool recipes (native
ffmpeg desktop grab, real k9s) that you run directly — no bundled wrapper scripts.

## STEP 5 — Author, stitch, self-QA (the loop that replaces a driver)

1. Copy `deck/deck.template.html` → `deck/deck.html`; edit the per-feature text (hero, architecture
   3-node flow, checklist, end). Keep the CSS. Render at ≈ each section's narration + 0.4s.
2. Write each section's narration to its own `.txt`; synth with `tts.py`. Vary the voice per section
   for a multi-speaker feel (see WORKFLOW.md voice cast).
3. Capture each section (cards / panel / browser) per the routing table, feeding real MCP numbers.
4. `stitch.py final.mp4 vid=wav vid=wav …` in running order.
5. `check_demo.py` → if score < 90 or a silence gap ≥ 4s, fix (re-narrate/re-capture/re-stitch) and
   repeat. Deliver only when score ≥ 90.

## Hard rules
- **Read-only**: never deploy/scale/merge to make a demo. Show the lever; don't pull it.
- **Real numbers only**: fetch via MCP live; quote actuals (1/1, restarts=0, build #, counts).
- **Offline / neural voice**: `tts.py` prefers offline **Kokoro** (natural neural, ~82M params);
  on locked-down Windows where Kokoro's wheels are unavailable it uses **edge-tts** (Azure neural
  voices — Andrew/Brian/Aria/Guy/Emma) which installs from tiny wheels with no PyTorch; **Piper** is
  the final offline fallback. OS built-in TTS (`say`, SAPI) is a last resort. Kokoro & Piper send no
  audio off-box; edge-tts reaches the Azure speech endpoint for synthesis only.
- **Video clarity**: browser capture uses full-page view at zoom 1.0 (whole page visible, not
  zoomed-in); panels use fontsize ≥ 20 with a dwell on the final frame.
- **No flat/blank frames (automatic)**: `stitch.py` auto-detects the first non-flat frame of EACH
  section (grayscale-stddev probe matching `check_demo.py`) and skips the flat head. Disable with
  `TRIM_FLAT_HEAD=0`. For SPA pages that paint white ~10s, use `FLAT_NOPAD=1 FLAT_MAXHEAD=14`.
- **Security**: `capture.js browser` copies then DELETES the Chrome/Edge profile after recording, so
  auth cookies never persist in the work dir.
- **Self-QA (iterate without the user)**: after stitching, run `check_demo.py`. Re-record/re-stitch
  until score ≥ 90 and longest_silence < 4s before delivering.

## Setup & cross-platform notes
- **One-time setup** (documented, not scripted) — see WORKFLOW.md "Setup". In short:
  `pip install edge-tts` (neural voice, locked-down-friendly); `npm i playwright` +
  `npx playwright install chromium` (or rely on installed Chrome/Edge); ffmpeg via
  `brew install ffmpeg` / `winget install ffmpeg` / `apt install ffmpeg`.
- **Interpreter**: `python` (Windows) vs `python3` (macOS/Linux).
- **Node modules**: set `NODE_PATH=$WORK/node_modules` so `capture.js` resolves Playwright.
- **Work dir**: `~/demo_build` (NOT /tmp, which can be wiped mid-session).
- **Screen permission**: macOS needs Screen Recording permission for your terminal; Windows gdigrab
  captures the visible desktop (foreground the target window first); Linux uses `$DISPLAY`.

See `WORKFLOW.md` for setup, exact recipes (incl. native ffmpeg/k9s capture), the voice cast, and
the ffmpeg/Playwright/TTS cheatsheet. `scripts/` holds just the four primitives.
