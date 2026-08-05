---
name: demo-builder
description: Create a polished, narrated screen-recording demo video for ANY feature, end-to-end. Interviews the user for topic, audience, tools to show, length, voice and style, then builds a reference-grade deck (animated title/section cards + mac-chrome terminal/code panels), captures REAL tools (Azure DevOps, EV2, Geneva Monitoring, IcM, Kusto/ADX, kubectl/k9s, code), adds natural neural voice-over (local Kokoro TTS, offline; Piper fallback), and stitches a 1440x900 MP4. Triggers — "create a demo", "make a demo video", "record a walkthrough", "screencast for <feature>", "narrated demo", "like the dbset/STG cutover demo". Read-only by default (shows live tools, never deploys/scales). Pairs with playwright + asciinema/agg + ffmpeg + Kokoro/Piper.
---

# Demo Builder

Turn any feature into a 2–3 min narrated demo that looks like a human recorded themselves
with real tools — designed title/section cards, mac-chrome terminal & code panels, real
ADO / EV2 / Geneva / IcM / Kusto/ADX / kubectl / k9s footage, and a neural voice-over. **1440×900, 30fps, MP4.**

## STEP -1 — macOS only (check the OS FIRST, before anything else)

This skill runs **only on macOS**. Its toolchain (mac-chrome deck panels, `brew`-installed
ffmpeg/asciinema/agg, the `~/demo_build` layout, Kokoro/Piper) is macOS-specific.

**Before STEP 0 and before any other action, detect the operating system** (e.g. `uname -s` →
`Darwin` = macOS; or check the environment). Then:

- **macOS (`Darwin`)** → continue to STEP 0.
- **Windows (or anything not `Darwin`)** → **STOP immediately**. Do NOT interview, gather data,
  install tools, or build anything. Show the user this message and end:

  > ⚠️ **Demo Builder works only on macOS.** This skill relies on a macOS-only toolchain
  > (Homebrew, mac-chrome capture, Kokoro/Piper TTS) and cannot run on Windows. Please run it
  > from a Mac.

## STEP 0 — ALWAYS interview first (do not skip)

Use the **ask_user** tool to collect requirements BEFORE building anything. Present one form:

- **Feature / topic** (string) — what the demo is about.
- **One-line goal** (string) — the headline outcome to prove.
- **Audience** (enum): Eng team / Leadership / Customer / Mixed.
- **Length** (integer, seconds, default 165) — keep 150–180 for 2:30–3:00.
- **Tools to show** (multi-select — but NOT limited to this list; you can record **ANY tool the engineer names or provides**): ADO pipeline run, EV2 logs/rollouts, Geneva Monitoring dashboards & metrics, IcM incidents, Kusto/ADX queries, kubectl/k9s + pod logs, Helm/ConfigGen, Service Tree, Code/editor, Browser portal, Terminal/CLI, native desktop app / any GUI, Slides only. If the engineer asks for a tool not listed, capture it anyway (see "Universal capture" below) — never say "that tool isn't supported".
- **Architecture card?** (boolean, default true) — include a "how it works" 3-node flow section (source → component → effects + invariant callout). Users frequently ask to "understand the architecture"; offer it up front.
- **Style** (enum, default reference-deck): reference-deck (cards + panels) / raw screen-capture / hybrid.
- **Voice** (enum, default am_michael — natural Kokoro neural): am_michael (warm US male) / am_adam (US male) / af_heart (US female) / bm_george (UK male) / none. Piper voices (en_US-ryan-high) remain as fallback.
- **Read-only?** (boolean, default true) — show levers, never execute deploy/scale/merge.
- **Output path** (string, default `~/Desktop/<slug>-demo.mp4`).
- **Real data sources** (string) — pipeline IDs, cluster context+namespace, repo, vault names, share links.

After answers: write a tiny shot-list to `plan.md`, gather REAL data, build sections, narrate, stitch, deliver. Confirm exact IDs/links before recording. Never invent numbers — pull them live.

## Universal capture — record ANY tool (logs, metrics, terminal, code, portal, native app…)

There is a single front door, `scripts/capture.sh <kind> <out> [args…]`, that records **whatever tool the
engineer provides or asks for** and normalizes it to a 1440×900 clip ready for `stitch.sh`. Whatever the
engineer names — a Geneva metric chart, a Kusto query, a native desktop viewer, a source file, a live log
stream — pick the matching kind. Do NOT tell the user a tool is unsupported; map it to the closest kind.

| Engineer wants to show… | `kind` | backing recorder |
|---|---|---|
| A web tool / portal / **metrics** / dashboard (ADO, EV2 portal, Geneva/Jarvis, IcM, Kusto web, Azure Portal, Service Tree, Grafana, wiki) | `url` | `record-browser.js` (authenticated Chrome, SSO, live scroll) |
| A **terminal / CLI** session (az, kubectl, helm, gh, git, configgen, custom) | `cmd` | `record-term.sh` |
| **Code** — any source file, syntax-highlighted, scrolled | `code` | `record-code.sh` (bat) |
| **Live logs** streamed with a real "tail" feel | `logs` | `record-live-logs.sh` |
| **k9s** pods → drill into pod logs | `k8s` | `record-k9s.sh` |
| **Any native GUI / desktop app / window / region** (desktop metrics viewer, native portal, IDE app, Excel/Power BI, a video) | `screen` | `record-screen.sh` (macOS avfoundation) |

Rule of thumb for an unlisted tool: **web → `url`, text/CLI → `cmd`, source file → `code`, anything else visible on screen → `screen`.** Run `scripts/capture.sh` with no args for full per-kind usage. `screen` needs macOS **Screen Recording** permission for the terminal (System Settings › Privacy & Security).

## Pipeline at a glance

1. **Deck cards** — `deck/deck.html` + `deck/deck.css`; render via `scripts/render-cards.js` (Playwright→webm).
2. **Real footage of ANY tool** — `scripts/capture.sh <kind>` (see "Universal capture") routes to the browser / terminal / code / logs / k9s / native-screen recorder.
3. **k9s + logs** — `scripts/record-k9s.sh` (tmux + asciinema + agg). agg DOES render k9s log views.
4. **Narration** — `scripts/tts.sh` (local Kokoro by default, offline, no 3rd party; Piper fallback via engine arg).
5. **Stitch** — `scripts/stitch.sh` mux each section (video governs length, audio padded) + concat → MP4.

`scripts/setup.sh` installs Playwright+Chrome, asciinema, agg, ffmpeg, espeak-ng, and Kokoro (+Piper fallback). Work dir defaults to ~/demo_build (NOT /tmp, which can be wiped mid-session).

## Design system (matches the dbset/STG reference)
Dark navy `#0b0e14`; hero = mono eyebrow "MDA · DATA SERVICES", big mono title, subtitle with
bold phrase, green CRD-style pill badges; body = mac-chrome panels, JetBrains Mono, green values,
warn/validation callouts. Section cards between phases. The deck template (`deck/deck.template.html`)
ships generic slides: **hero/title**, **architecture** (3-node `source → component → effects` flow
with an invariant callout — for the "how it works" section), **terminal panel**, **checklist**, **end**.
Copy it to `deck.html`, edit the text per feature, keep the CSS.

## Hard rules
- **Read-only**: never deploy/scale/merge to make a demo. Show the lever; don't pull it.
- **Real numbers only**: query ADO/k8s/KV live; quote actuals (1/1, restarts=0, counts).
- **Offline voice**: Kokoro TTS (natural neural, ~82M params) by default; Piper as fallback — no audio sent to 3rd parties. macOS `say` is rejected.
- **Video clarity**: record-browser.js uses deviceScaleFactor:2 + full-page view at zoom 1.0 (deviceScaleFactor:2 keeps text crisp) so the whole page is visible, not zoomed-in; record-k9s.sh uses --font-size 22 with long dwell on live logs. For k9s, jumping to the target pod with `G` (bottom) is more reliable than k9s v0.32 fuzzy filter.
- **No flat/blank frames (automatic)**: deck cards start with a few flat pre-paint frames (white browser paint, or the dark data-url before content fades in) which read as a glitch. `stitch.sh` auto-detects the first non-flat frame of EACH section (grayscale-stddev probe matching check_demo.py, signalstats fallback) and skips the flat head, then clone-pads the tail so length/narration sync is preserved. No manual per-card trimming needed — just render cards at ≈narration+0.4s. Disable with `TRIM_FLAT_HEAD=0`.
- **Live logs (not screenshots)**: for a real "live run" feel use scripts/record-live-logs.sh — runs real `kubectl get pods` then streams a pod/job log through fmt_pace.py (parses kubectl JSON, paces lines) so logs scroll in continuously. For ADO log panes, record-browser.js hovers the log pane (mouse.move) then incremental wheel scrolls so the real log visibly streams. Completed jobs replayed through the pacer look live; this is the technique users asked for over static page screenshots.
- **Security**: delete the copied Chrome profile + any token files after recording (auth cookies).
- **Self-QA (iterate without the user)**: after stitching, run `scripts/check_demo.py <mp4> --sections
  "name:start:end,..." --expect "kw,..."`. It scores 0-100 on per-section motion (catches static
  screenshots), sharpness, near-blank frames, OCR bad-page/keyword checks, and audio loudness +
  trailing-silence gaps. Re-trim/re-record and re-stitch until score>=90 and longest_silence<4s before
  delivering. See WORKFLOW.md "Self-QA".

See `scripts/` for each step and `WORKFLOW.md` for the full ffmpeg/agg/auth cheatsheet.
